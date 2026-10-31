import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'draft_bridge.g.dart';

/// Development integration boundary. It is deliberately not CollectionRepository.
/// Caller retains the original write/ID after an unknown mutation outcome.
/// Open establishes transport only. Before new edits the caller must page pending
/// metadata, resolve receipts and explicitly retry/abandon uncommitted bodies.
final class DraftStorageFailure implements Exception {
  final String code;
  final bool outcomeUnknown;
  const DraftStorageFailure(this.code, {this.outcomeUnknown = false});
  @override
  String toString() =>
      'DraftStorageFailure($code, outcomeUnknown: $outcomeUnknown)';
}

enum _Operation {
  open,
  close,
  freeze,
  commit,
  read,
  resolve,
  abandon,
  pending,
  body,
}

final class _Request {
  final int id;
  final _Operation operation;
  final DraftWriteMessage? write;
  final String? commandId;
  final String? payloadHash;
  final String? cursor;
  const _Request(
    this.id,
    this.operation, {
    this.write,
    this.commandId,
    this.payloadHash,
    this.cursor,
  });
  bool get mutating => const [
    _Operation.freeze,
    _Operation.commit,
    _Operation.abandon,
  ].contains(operation);
}

final class _Reply {
  final int id;
  final Object? value;
  final DraftStorageFailure? failure;
  const _Reply(this.id, this.value, this.failure);
}

/// One long-lived service isolate serializes all HostApi requests. Root-side
/// ports fail outstanding work if that isolate dies; no promise is left hanging.
final class DraftRepositoryService {
  final ReceivePort _responses = ReceivePort();
  final ReceivePort _errors = ReceivePort();
  final ReceivePort _exits = ReceivePort();
  final Map<int, (Completer<Object?>, bool)> _waiting = {};
  final Completer<SendPort> _ready = Completer();
  Isolate? _isolate;
  late SendPort _commands;
  late DraftSessionMessage session;
  int _sequence = 0;
  bool _closed = false;
  final Duration _responseTimeout;
  DraftRepositoryService._([
    this._responseTimeout = const Duration(seconds: 30),
  ]);

  @visibleForTesting
  factory DraftRepositoryService.forTransportTest(
    SendPort commands, {
    required Duration responseTimeout,
  }) {
    final service = DraftRepositoryService._(responseTimeout);
    service._commands = commands;
    service._ready.complete(commands);
    return service;
  }

  static Future<DraftRepositoryService> open() async {
    if (kReleaseMode) {
      throw StateError('Draft integration cannot run in release mode.');
    }
    final token = RootIsolateToken.instance;
    if (token == null) {
      throw StateError('Start the service from the root isolate.');
    }
    final service = DraftRepositoryService._();
    // Spawn can fail before the handshake await is installed.
    service._ready.future.ignore();
    service._responses.listen((message) {
      if (message is SendPort) {
        if (!service._ready.isCompleted) service._ready.complete(message);
      } else if (message is _Reply) {
        final waiting = service._waiting.remove(message.id);
        if (waiting == null) return;
        if (message.failure case final failure?) {
          waiting.$1.completeError(failure);
        } else {
          waiting.$1.complete(message.value);
        }
      }
    });
    service._errors.listen((_) => service._stop());
    service._exits.listen((_) => service._stop());
    try {
      service._isolate = await Isolate.spawn(
        _serve,
        (token, service._responses.sendPort),
        onError: service._errors.sendPort,
        onExit: service._exits.sendPort,
        errorsAreFatal: true,
        debugName: 'verdi-draft-repository',
      );
      service._commands = await service._ready.future.timeout(
        const Duration(seconds: 15),
      );
      service.session = await service._call<DraftSessionMessage>(
        _Operation.open,
      );
      return service;
    } catch (_) {
      service._stop();
      rethrow;
    }
  }

  Future<T> _call<T>(
    _Operation operation, {
    DraftWriteMessage? write,
    String? commandId,
    String? hash,
    String? cursor,
  }) async {
    if (_closed) throw const DraftStorageFailure('STORAGE_UNAVAILABLE');
    final request = _Request(
      ++_sequence,
      operation,
      write: write,
      commandId: commandId,
      payloadHash: hash,
      cursor: cursor,
    );
    final completion = Completer<Object?>();
    _waiting[request.id] = (completion, request.mutating);
    _commands.send(request);
    // A live isolate cannot detect a dropped platform reply. Terminate this
    // transport on deadline; reopening queues behind native work and resolves
    // its original receipt. Never report a timed-out mutation as noncommitted.
    final timer = Timer(_responseTimeout, _stop);
    try {
      return (await completion.future) as T;
    } finally {
      timer.cancel();
    }
  }

  Future<void> freeze(DraftWriteMessage write) =>
      _call<void>(_Operation.freeze, write: write);
  Future<DraftReceiptMessage> commit(String commandId, String hash) =>
      _call<DraftReceiptMessage>(
        _Operation.commit,
        commandId: commandId,
        hash: hash,
      );
  Future<DraftRecordMessage?> read() =>
      _call<DraftRecordMessage?>(_Operation.read);
  Future<DraftReceiptMessage?> resolve(String commandId, String hash) =>
      _call<DraftReceiptMessage?>(
        _Operation.resolve,
        commandId: commandId,
        hash: hash,
      );
  Future<DraftReceiptMessage?> abandon(String commandId, String hash) =>
      _call<DraftReceiptMessage?>(
        _Operation.abandon,
        commandId: commandId,
        hash: hash,
      );
  Future<DraftPageMessage> pending({String? after}) =>
      _call<DraftPageMessage>(_Operation.pending, cursor: after);
  Future<DraftWriteMessage> body(String commandId, String hash) =>
      _call<DraftWriteMessage>(
        _Operation.body,
        commandId: commandId,
        hash: hash,
      );
  Future<void> close() async {
    if (_closed) {
      _stop();
      return;
    }
    try {
      await _call<void>(_Operation.close);
    } finally {
      _stop();
    }
  }

  void _failed() {
    _closed = true;
    if (!_ready.isCompleted) {
      _ready.completeError(const DraftStorageFailure('STORAGE_UNAVAILABLE'));
    }
    for (final value in _waiting.values) {
      value.$1.completeError(
        DraftStorageFailure('STORAGE_UNAVAILABLE', outcomeUnknown: value.$2),
      );
    }
    _waiting.clear();
  }

  void _stop() {
    _failed();
    _isolate?.kill(priority: Isolate.immediate);
    _responses.close();
    _errors.close();
    _exits.close();
  }
}

Future<void> _serve((RootIsolateToken, SendPort) start) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(start.$1);
  final api = DraftRepositoryHostApi();
  final commands = ReceivePort();
  start.$2.send(commands.sendPort);
  DraftSessionMessage? session;
  String? unresolved;
  // await-for deliberately completes one operation before receiving the next.
  await for (final message in commands) {
    final request = message as _Request;
    try {
      if (request.mutating &&
          unresolved != null &&
          (request.write?.commandId ?? request.commandId) != unresolved) {
        throw const DraftStorageFailure(
          'RECOVERY_REQUIRED',
          outcomeUnknown: true,
        );
      }
      final id = session?.sessionId ?? '';
      final Object? value;
      switch (request.operation) {
        case _Operation.open:
          session = await api.openDraftRepository(1);
          value = session;
        case _Operation.close:
          await api.closeDraftRepository(id);
          value = null;
        case _Operation.freeze:
          await api.freezeDraft(id, request.write!);
          value = null;
        case _Operation.commit:
          value = await api.commitDraft(
            id,
            request.commandId!,
            request.payloadHash!,
          );
          unresolved = null;
        case _Operation.read:
          value = await api.readDraft(id);
        case _Operation.resolve:
          value = await api.resolveDraft(
            id,
            request.commandId!,
            request.payloadHash!,
          );
          if (value != null && unresolved == request.commandId) {
            unresolved = null;
          }
        case _Operation.abandon:
          value = await api.abandonDraft(
            id,
            request.commandId!,
            request.payloadHash!,
          );
          if (unresolved == request.commandId) unresolved = null;
        case _Operation.pending:
          value = await api.pendingDrafts(id, request.cursor);
        case _Operation.body:
          value = await api.getPendingDraft(
            id,
            request.commandId!,
            request.payloadHash!,
          );
      }
      start.$2.send(_Reply(request.id, value, null));
    } on DraftStorageFailure catch (error) {
      start.$2.send(_Reply(request.id, null, error));
    } on PlatformException catch (error) {
      final unknown =
          request.mutating &&
          (error.code == 'UNKNOWN_OUTCOME' || error.code == 'channel-error');
      if (unknown) unresolved = request.write?.commandId ?? request.commandId;
      start.$2.send(
        _Reply(
          request.id,
          null,
          DraftStorageFailure(error.code, outcomeUnknown: unknown),
        ),
      );
    } catch (_) {
      if (request.mutating) {
        unresolved = request.write?.commandId ?? request.commandId;
      }
      start.$2.send(
        _Reply(
          request.id,
          null,
          DraftStorageFailure(
            'STORAGE_UNAVAILABLE',
            outcomeUnknown: request.mutating,
          ),
        ),
      );
    }
  }
}
