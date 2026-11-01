import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/native/draft_bridge.g.dart';
import '../repositories/collection_repository.dart';

String _uuid() {
  final random = Random.secure(), b = List<int>.generate(16, (_) => 0);
  for (var i = 0; i < 16; i++) {
    b[i] = random.nextInt(256);
  }
  b[6] = (b[6] & 15) | 64;
  b[8] = (b[8] & 63) | 128;
  final h = b.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

Map<String, Object?> _map(Object? v) => (v as Map).cast<String, Object?>();

/// Service-boundary faults exercise real native saves without adding a native
/// channel that can choose a database, corrupt rows or grant entitlement.
enum CoreVerificationFault {
  beforeFreeze,
  afterFreezeReply,
  beforeCommit,
  afterCommitReply,
  receiptRead,
  slowReadback,
}

final class PendingCoreAction {
  final FrozenCommand intent;
  final String label;
  const PendingCoreAction(this.intent, this.label);
}

final class _Request {
  final int id;
  final String operation;
  final Object? value;
  final String? commandId;
  const _Request(this.id, this.operation, this.value, this.commandId);
  bool get mutating => [
    'prepare',
    'confirm',
    'submit',
    'retrySubmit',
    'abandon',
  ].contains(operation);
}

final class _Reply {
  final int id;
  final Object? value;
  final Object? error;
  final LocalDate? today;
  const _Reply(this.id, this.value, this.error, this.today);
}

/// Root owns transport/UI DTOs only. Domain reads/plans and all platform requests
/// are serialized on one service isolate. SQLite remains native-owned.
final class NativeCollectionRepository implements CollectionRepository {
  ReceivePort? _responses, _errors, _exits;
  Isolate? _isolate;
  SendPort? _commands;
  Completer<SendPort>? _ready;
  final Map<int, (_Request, Completer<Object?>)> _waiting = {};
  int _sequence = 0;
  final Map<String, String> _retryIds = {};
  final Map<String, String> _preparationIds = {};
  final Set<String> _retiredOptimizationIds = {};
  Future<void>? _connecting;
  @override
  late String datasetId;
  @override
  late LocalDate today;
  bool fileProtectionVerified = false;
  bool _closed = false;
  Map<String, Object?> settings = {};
  List<PendingCoreAction> pendingActions = [];
  NativeCollectionRepository._();
  static Future<NativeCollectionRepository> open() async {
    if (kReleaseMode) {
      throw StateError('The development core is not a release entry.');
    }
    final repository = NativeCollectionRepository._();
    await repository._connect();
    return repository;
  }

  @visibleForTesting
  Future<void> injectFaultForTest(CoreVerificationFault fault) {
    if (!kDebugMode) {
      throw StateError('Verification faults require debug mode.');
    }
    return _call('verificationFault', fault);
  }

  Future<Map<String, Object?>?> optimization(
    String operation,
    Map<String, Object?> args,
  ) async {
    final result = await _call<Map<String, Object?>?>('optimization', (
      operation,
      args,
    ));
    if (result != null && result['results'] is List) {
      for (final raw in result['results'] as List) {
        final row = _map(raw);
        if (row['state'] == 'pending') continue;
        for (final key in ['draftCommandId', 'replaceCommandId']) {
          final id = row[key] as String;
          _retiredOptimizationIds.add(id);
          _preparationIds.removeWhere((_, value) => value == id);
          _retryIds.removeWhere((_, value) => value == id);
        }
      }
    }
    return result;
  }

  Future<CommandSuccess> submitOptimizationDraft(
    SaveMediaDraft command,
    String commandId,
  ) => _call('submit', command, commandId);

  @override
  Future<CollectionSnapshot> mediaSnapshot() => _call('mediaSnapshot');
  @override
  Future<Map<String, Object?>> preparePhoto({
    required String draftId,
    required int draftRevision,
    required String preparationId,
    required String selectionId,
    required LocalDate observedDate,
  }) => _call('preparePhoto', <String, Object?>{
    'datasetId': datasetId,
    'draftId': draftId,
    'draftRevision': draftRevision,
    'preparationId': preparationId,
    'selectionId': selectionId,
    'observedDate': observedDate.toString(),
  });
  @override
  Future<Map<String, Object?>> photoPreparation(String preparationId) =>
      _call('photoPreparation', preparationId);
  @override
  Future<List<Map<String, Object?>>> draftPreparations(String draftId) =>
      _call('draftPreparations', draftId);
  @override
  Future<CatalogState> catalog({bool retry = false}) => _call('catalog', retry);

  @override
  String newId() => _uuid();
  Future<void> _connect() =>
      _connecting ??= _start().whenComplete(() => _connecting = null);
  Future<void> _start() async {
    final token = RootIsolateToken.instance;
    if (token == null) throw const RecoveryUnavailable();
    _responses = ReceivePort();
    _errors = ReceivePort();
    _exits = ReceivePort();
    final ready = _ready = Completer<SendPort>();
    ready.future.ignore();
    _responses!.listen((Object? message) {
      if (message is SendPort) {
        if (!ready.isCompleted) ready.complete(message);
      }
      if (message is _Reply) {
        if (message.today != null) today = message.today!;
        final waiting = _waiting.remove(message.id);
        if (waiting == null) return;
        if (message.error != null) {
          waiting.$2.completeError(message.error!);
          if (message.error is UnknownCommandOutcome ||
              message.error is RecoveryUnavailable) {
            // A native unknown COMMIT may poison its handle. The next resolver
            // must open a new native session, not reuse this transport.
            _stop();
          }
        } else {
          waiting.$2.complete(message.value);
        }
      }
    });
    _errors!.listen((_) => _stop());
    _exits!.listen((_) => _stop());
    try {
      _isolate = await Isolate.spawn(
        _serve,
        (token, _responses!.sendPort),
        onError: _errors!.sendPort,
        onExit: _exits!.sendPort,
        errorsAreFatal: true,
        debugName: 'verdi-core-repository',
      );
      _commands = await ready.future.timeout(const Duration(seconds: 15));
      final opened = await _send<Map<String, Object?>>('open');
      datasetId = opened['datasetId'] as String;
      today = opened['today'] as LocalDate;
      fileProtectionVerified = opened['fileProtectionVerified'] as bool;
      settings = _map(opened['settings']);
      pendingActions = opened['pending'] as List<PendingCoreAction>;
    } catch (_) {
      _stop();
      rethrow;
    }
  }

  void _stop() {
    _commands = null;
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(const RecoveryUnavailable());
    }
    for (final item in _waiting.values) {
      item.$2.completeError(
        item.$1.mutating && item.$1.commandId != null
            ? UnknownCommandOutcome(item.$1.commandId!)
            : const RecoveryUnavailable(),
      );
    }
    _waiting.clear();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _responses?.close();
    _errors?.close();
    _exits?.close();
  }

  Future<T> _send<T>(
    String operation, [
    Object? value,
    String? commandId,
  ]) async {
    final port = _commands;
    if (port == null) throw const RecoveryUnavailable();
    final request = _Request(++_sequence, operation, value, commandId),
        completion = Completer<Object?>();
    _waiting[request.id] = (request, completion);
    port.send(request);
    final timer = Timer(const Duration(seconds: 30), _stop);
    try {
      return await completion.future as T;
    } finally {
      timer.cancel();
    }
  }

  Future<T> _call<T>(
    String operation, [
    Object? value,
    String? commandId,
  ]) async {
    if (_closed) throw const RecoveryUnavailable();
    if (_commands == null) await _connect();
    return _send<T>(operation, value, commandId);
  }

  Future<void> close() async {
    _closed = true;
    try {
      if (_commands != null) await _send<void>('close');
    } finally {
      _stop();
    }
  }

  Future<List<PendingCoreAction>> pending() async =>
      pendingActions = await _call<List<PendingCoreAction>>('pending');
  Future<CommandSuccess> retryPending(PendingCoreAction action) =>
      _call('retrySubmit', action.intent.command, action.intent.commandId);
  @override
  Future<WorkspaceRead> read({required bool archived, required String query}) =>
      _call('read', (archived, query));
  @override
  Future<PlantsPage> morePlants({
    required bool archived,
    required String query,
    required ReadCursor cursor,
  }) => _call('morePlants', (archived, query, cursor));
  @override
  Future<TodayPage> moreToday(TodaySection section, ReadCursor cursor) =>
      _call('moreToday', (section, cursor));
  @override
  Future<PlantEditor> editor(String? plantId) => _call('editor', plantId);
  @override
  Future<PlantDetail> detail(String plantId) => _call('detail', plantId);
  @override
  Future<ReadPage<TimelineEntry>> timeline(
    String plantId, {
    bool includeVoided = false,
    ReadCursor? cursor,
  }) => _call('timeline', (plantId, includeVoided, cursor));
  @override
  Future<PreparedCommand> prepare(
    CoreCommand command, {
    String? commandId,
  }) async {
    final hash = command.payloadHash,
        prior = commandId ?? _preparationIds[command.payloadHash];
    final id = prior ?? newId();
    try {
      final prepared = await _call<PreparedCommand>('prepare', (
        command,
        prior != null,
      ), id);
      _preparationIds.remove(hash);
      return prepared;
    } on UnknownCommandOutcome catch (error) {
      if (!_retiredOptimizationIds.contains(error.commandId)) {
        _preparationIds[hash] = error.commandId;
      }
      rethrow;
    } on CommandRejected {
      _preparationIds.remove(hash);
      rethrow;
    }
  }

  @override
  Future<CommandSuccess> confirm(PreparedCommand preview) =>
      _call('confirm', preview, preview.intent.commandId);
  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    final hash = command.payloadHash;
    final id = _retryIds.putIfAbsent(hash, newId);
    try {
      final result = await _call<CommandSuccess>('submit', command, id);
      _retryIds.remove(hash);
      return result;
    } on UnknownCommandOutcome catch (error) {
      _retryIds[hash] = error.commandId;
      rethrow;
    } on CommandRejected {
      _retryIds.remove(hash);
      rethrow;
    }
  }

  @override
  Future<CommandResolution> resolve(String commandId) =>
      _call('resolve', null, commandId);
  @override
  Future<CommandResolution> abandon(String commandId) async {
    final result = await _call<CommandResolution>('abandon', null, commandId);
    _preparationIds.removeWhere((_, id) => id == commandId);
    _retryIds.removeWhere((_, id) => id == commandId);
    return result;
  }

  @override
  void invalidateUndo() {
    if (_commands != null) {
      _send<void>('invalidateUndo').catchError((Object _) {});
    }
  }
}

final class _Worker {
  final api = CoreRepositoryHostApi();
  CoreVerificationFault? nextFault;
  late String session;
  late CoreStorageProjection projection;
  final Map<String, CoreStoragePlan> plans = {};
  final Map<String, String> tokens = {};
  final Map<String, FrozenCommand> pending = {};
  String? unresolved;
  Future<Object?> native(
    String operation, [
    Map<String, Object?> args = const {},
  ]) async {
    try {
      if ((nextFault == CoreVerificationFault.beforeFreeze &&
              operation == 'freeze') ||
          (nextFault == CoreVerificationFault.receiptRead &&
              operation == 'resolve')) {
        nextFault = null;
        throw const RecoveryUnavailable();
      }
      if (nextFault == CoreVerificationFault.beforeCommit &&
          operation == 'commit') {
        nextFault = null;
        throw CommandRejected('BUSY');
      }
      final reply = await api.callCore(
        operation,
        canonicalCommandJson({
          if (operation != 'open') 'sessionId': session,
          ...args,
        }),
      );
      if (nextFault == CoreVerificationFault.afterFreezeReply &&
          operation == 'freeze') {
        nextFault = null;
        throw const RecoveryUnavailable();
      }
      if (nextFault == CoreVerificationFault.afterCommitReply &&
          operation == 'commit') {
        nextFault = null;
        throw const RecoveryUnavailable();
      }
      return jsonDecode(reply);
    } on PlatformException catch (e) {
      if (['UNKNOWN_OUTCOME', 'channel-error'].contains(e.code)) {
        throw const RecoveryUnavailable();
      }
      throw CommandRejected(e.code);
    }
  }

  CareClock clock(Object? value) {
    final c = _map(value);
    return CareClock(
      LocalDate.parse(c['today'] as String),
      DateTime.parse(c['instant'] as String),
      c['zone'] as String,
    );
  }

  Future<CatalogState> loadCatalog({bool retry = false}) async {
    if (retry) await native('retryCatalog');
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final meta = _map(await native('catalogMeta'));
        final version = meta['version'] as String?;
        if (version == null) {
          return projection.reader.catalog = CatalogState(
            limitation: 'CATALOG_UNAVAILABLE',
          );
        }
        final manifest = _map(meta['manifest']);
        final entries = <CatalogEntry>[];
        String? after;
        do {
          final page = _map(
            await native('catalogRows', {'version': version, 'after': after}),
          );
          entries.addAll(
            (page['entries'] as List).map(
              (e) => CatalogEntry(version, _map(e)),
            ),
          );
          after = page['nextCursor'] as String?;
        } while (after != null);
        final finalMeta = _map(await native('catalogMeta'));
        if (finalMeta['version'] != version) continue;
        return projection.reader.catalog = CatalogState(
          version: version,
          entries: entries,
          popularIds: (manifest['popularIds'] as List).cast<String>(),
          manifest: manifest,
          limitation: finalMeta['limitation'] as String?,
        );
      } on CommandRejected catch (error) {
        if (['CATALOG_UNAVAILABLE', 'CATALOG_INVALID'].contains(error.code)) {
          return projection.reader.catalog = CatalogState(
            limitation: 'CATALOG_UNAVAILABLE',
          );
        }
        if (error.code != 'CATALOG_CHANGED') rethrow;
      }
    }
    throw CommandRejected('CATALOG_CHANGED');
  }

  Future<void> hydrate() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final meta = _map(await native('metadata'));
        final rows = <String, List<List<Object?>>>{};
        for (final table in CoreStorageProjection.tables) {
          rows[table] = [];
          String? after;
          do {
            final page = _map(
              await native('readRows', {
                'table': table,
                'storageRevision': meta['storageRevision'],
                'after': after,
              }),
            );
            rows[table]!.addAll(
              (page['rows'] as List).map((r) => (r as List).cast<Object?>()),
            );
            after = page['nextCursor'] as String?;
          } while (after != null);
        }
        final finalMeta = _map(await native('metadata'));
        if (finalMeta['storageRevision'] != meta['storageRevision']) continue;
        projection.hydrate(
          rows,
          meta['collectionRevision'] as int,
          meta['storageRevision'] as int,
        );
        projection.clock = clock(await native('clock'));
        return;
      } on CommandRejected catch (e) {
        if (e.code != 'READ_STALE') rethrow;
      }
    }
    throw const RecoveryUnavailable();
  }

  Future<List<PendingCoreAction>> loadPending() async {
    pending.clear();
    String? after;
    do {
      final page = _map(await native('pending', {'after': after}));
      for (final item in page['items'] as List) {
        final meta = _map(item),
            body = _map(
              await native('pendingBody', {'commandId': meta['commandId']}),
            );
        final frozen = projection.restoreFrozen(body);
        pending[frozen.commandId] = frozen;
      }
      after = page['nextCursor'] as String?;
    } while (after != null);
    return pending.values.map((intent) {
      final command = intent.command;
      final plantId = switch (command) {
        RoutineCommand c => c.target.plantId,
        PlantLifecycleCommand c => c.plantId,
        SaveDraft c => c.plantId,
        _ => null,
      };
      final draft = switch (command) {
        SavePlant c => projection.snapshot.drafts[c.draftId],
        DiscardDraft c => projection.snapshot.drafts[c.draftId],
        _ => null,
      };
      final name = command is SaveDraft
          ? command.fields.name
          : draft?.fields.name ??
                projection.snapshot.plants[plantId]?.name ??
                '';
      return PendingCoreAction(intent, name);
    }).toList();
  }

  Future<void> gate(String? id) async {
    if (unresolved != null && unresolved != id) {
      final result = await native('resolve', {'commandId': unresolved});
      if (result == null) throw UnknownCommandOutcome(unresolved!);
      pending.remove(unresolved);
      unresolved = null;
      await hydrate();
    }
    if (id == null && pending.isNotEmpty) {
      throw CommandRejected('RECOVERY_REQUIRED');
    }
  }

  Future<CoreStoragePlan> prepare(
    CoreCommand command,
    String id,
    bool existing,
  ) async {
    await gate(existing ? id : null);
    await hydrate();
    if (command is SavePlant) await loadCatalog();
    FrozenCommand intent;
    if (existing) {
      try {
        intent = projection.restoreFrozen(
          _map(await native('pendingBody', {'commandId': id})),
        );
        if (intent.payloadHash != command.payloadHash) {
          throw CommandRejected('COMMAND_ID_REUSED');
        }
      } on CommandRejected catch (error) {
        if (error.code != 'NOT_FOUND') rethrow;
        final receipt = await native('resolve', {
          'commandId': id,
          'payloadHash': command.payloadHash,
        });
        if (receipt != null) throw CommandRejected('NOT_ELIGIBLE');
        // A failed freeze may have recorded nothing. Reuse its original ID.
        intent = projection.freeze(command, newCommandId: id);
        existing = false;
      }
    } else {
      intent = projection.freeze(command, newCommandId: id);
    }
    final access = _map(await native('capabilities'));
    projection.hydrateAccess(
      pro: access['access'] == 'pro',
      revision: access['capabilityRevision'] as int,
    );
    final plan = projection.plan(intent, session);
    // Validate locally before freezing. A failed validation keeps no unreachable
    // new native intent. Once frozen, unknown outcomes retain the original ID.
    unresolved = id;
    var frozen = existing;
    try {
      await native('freeze', {'intent': projection.frozenJson(intent)});
      frozen = true;
      pending[id] = intent;
      if (plan.needsPreview && plan.effects.gate == PreviewGate.allowed) {
        final preview = _map(await native('preview', {'plan': plan.body()}));
        tokens[id] = preview['previewToken'] as String;
      } else if (plan.needsPreview) {
        // UI-only gated preview. Native never issued this as a commit token.
        tokens[id] = id;
      }
      plans[id] = plan;
      unresolved = null;
      return plan;
    } on CommandRejected {
      if (!existing && frozen) {
        await native('abandon', {'commandId': id});
        pending.remove(id);
        projection.forget(id);
      }
      unresolved = null;
      rethrow;
    } on RecoveryUnavailable {
      throw UnknownCommandOutcome(id);
    }
  }

  Future<CommandSuccess> commit(CoreStoragePlan plan, {String? token}) async {
    final id = plan.intent.commandId;
    await gate(id);
    unresolved = id;
    Object? reply;
    try {
      reply = await native('commit', {'plan': plan.body(previewToken: token)});
    } on RecoveryUnavailable {
      throw UnknownCommandOutcome(id);
    } on CommandRejected catch (error) {
      if (['BUSY', 'DISK_FULL', 'STORAGE_UNAVAILABLE'].contains(error.code)) {
        // Keep the frozen operation and editor payload together for recovery.
        throw UnknownCommandOutcome(id);
      }
      if (plan.intent.command is SaveDraft ||
          plan.intent.command is DiscardDraft) {
        await native('abandon', {'commandId': id});
        pending.remove(id);
        projection.forget(id);
      }
      unresolved = null;
      rethrow;
    }
    final message = _map(reply), result = _map(message['result']);
    pending.remove(id);
    plans.remove(id);
    tokens.remove(id);
    projection.forget(id);
    unresolved = null;
    int? remaining;
    final acknowledgementElapsed = Stopwatch()..start();
    if (message['acknowledgementId'] != null) {
      final timer = Stopwatch()..start();
      try {
        final ack = await native('acknowledge', {
          'commandId': id,
          'acknowledgementId': message['acknowledgementId'],
        });
        if (ack != null) {
          final value =
              (_map(ack)['expiresInMilliseconds'] as int) -
              timer.elapsedMilliseconds;
          if (value > 0) remaining = value;
        }
      } catch (_) {
        /* Committed receipt remains authoritative; no Undo on lost ack. */
      }
    }
    try {
      if (nextFault == CoreVerificationFault.slowReadback) {
        nextFault = null;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      await hydrate();
    } catch (_) {
      throw UnknownCommandOutcome(id);
    }
    if (remaining != null) {
      remaining -= acknowledgementElapsed.elapsedMilliseconds;
      if (remaining <= 0) {
        remaining = null;
      } else {
        projection.acknowledge(plan, remaining);
      }
    }
    return projection.success(result, undoMilliseconds: remaining);
  }

  Future<Object?> dispatch(_Request request) async {
    final value = request.value;
    if (request.operation == 'verificationFault') {
      if (!kDebugMode) throw CommandRejected('NOT_ELIGIBLE');
      nextFault = value as CoreVerificationFault;
      return null;
    }
    if (request.operation == 'open') {
      final opened = _map(
        await native('open', {
          'protocolVersion': 1,
          'profile': 'custom_core_v1',
        }),
      );
      session = opened['sessionId'] as String;
      projection = CoreStorageProjection(
        datasetId: opened['datasetId'] as String,
        nextId: _uuid,
        clock: clock(opened['clock']),
      );
      await hydrate();
      final actions = await loadPending();
      return {
        'datasetId': projection.datasetId,
        'today': projection.clock.today,
        'fileProtectionVerified': opened['fileProtectionVerified'],
        'settings': _map(await native('getSettings')),
        'pending': actions,
      };
    }
    final reader = projection.reader, dataset = projection.datasetId;
    switch (request.operation) {
      case 'optimization':
        final (operation, args) = value as (String, Map<String, Object?>);
        const allowed = {
          'previewOptimization',
          'startOptimization',
          'getOptimizationJob',
          'latestOptimizationJob',
          'prepareOptimizationPhoto',
          'finishOptimizationTarget',
          'stopOptimization',
        };
        if (!allowed.contains(operation)) {
          throw CommandRejected('FIELD_INVALID');
        }
        final reply = await native(operation, args);
        final result = reply == null ? null : _map(reply);
        if (operation == 'finishOptimizationTarget' ||
            operation == 'stopOptimization') {
          for (final raw in result?['results'] as List? ?? const []) {
            final child = _map(raw);
            if (child['state'] == 'pending') continue;
            for (final key in ['draftCommandId', 'replaceCommandId']) {
              final id = child[key] as String;
              pending.remove(id);
              plans.remove(id);
              tokens.remove(id);
              projection.forget(id);
              if (unresolved == id) unresolved = null;
            }
          }
          await hydrate();
          await loadPending();
        }
        return result;
      case 'preparePhoto':
        return _map(
          await native('preparePhoto', value as Map<String, Object?>),
        );
      case 'photoPreparation':
        return _map(await native('photoPreparation', {'preparationId': value}));
      case 'draftPreparations':
        return (await native('draftPreparations', {'draftId': value}) as List)
            .map(_map)
            .toList();
      case 'catalog':
        return loadCatalog(retry: value == true);
      case 'close':
        return native('close');
      case 'pending':
        await hydrate();
        return loadPending();
      case 'invalidateUndo':
        projection.invalidateUndo();
        return native('invalidateUndo');
      case 'prepare':
        final (command, existing) = value as (CoreCommand, bool);
        final plan = await prepare(command, request.commandId!, existing);
        return projection.prepared(
          plan,
          tokens[plan.intent.commandId]!,
          projection.clock.instant
              .add(const Duration(minutes: 10))
              .toIso8601String(),
        );
      case 'confirm':
        final preview = value as PreparedCommand;
        final receipt = await native('resolve', {
          'commandId': preview.intent.commandId,
          'payloadHash': preview.intent.payloadHash,
        });
        if (receipt != null) {
          pending.remove(preview.intent.commandId);
          unresolved = null;
          await hydrate();
          return projection.success(_map(receipt));
        }
        final plan = plans[preview.intent.commandId];
        if (plan == null ||
            tokens[preview.intent.commandId] != preview.previewToken) {
          throw CommandRejected('PREVIEW_STALE');
        }
        return commit(plan, token: preview.previewToken);
      case 'retrySubmit':
        return commit(
          await prepare(value as CoreCommand, request.commandId!, true),
        );
      case 'submit':
        final command = value as CoreCommand;
        // Resolve the original ID before stale draft/domain validation. A prior
        // lost reply may already have consumed the draft or advanced its revision.
        try {
          final receipt = await native('resolve', {
            'commandId': request.commandId,
            'payloadHash': command.payloadHash,
          });
          if (receipt != null) {
            pending.remove(request.commandId);
            unresolved = null;
            await hydrate();
            return projection.success(_map(receipt));
          }
        } on CommandRejected catch (error) {
          if (error.code != 'NOT_FOUND') rethrow;
          // Authoritative absence permits freezing this SAME original ID.
        }
        final old = pending[request.commandId];
        if (old != null && old.payloadHash != command.payloadHash) {
          throw CommandRejected('COMMAND_ID_REUSED');
        }
        final plan = await prepare(
          command,
          old?.payloadHash == command.payloadHash
              ? old!.commandId
              : request.commandId!,
          old?.payloadHash == command.payloadHash,
        );
        if (plan.needsPreview) throw CommandRejected('PREVIEW_STALE');
        return commit(plan);
      case 'resolve':
      case 'abandon':
        final id = request.commandId!;
        Object? result;
        try {
          result = await native(request.operation, {'commandId': id});
        } on CommandRejected catch (error) {
          if (request.operation != 'abandon' || error.code != 'NOT_FOUND') {
            rethrow;
          }
          // An interrupted freeze may have recorded no intent. Native absence,
          // followed by a successful receipt read on this owner, permits cancel.
          // Unavailable reads still throw and preserve the unresolved command.
          result = await native('resolve', {'commandId': id});
        }
        if (result != null || request.operation == 'abandon') {
          pending.remove(id);
          projection.forget(id);
          plans.remove(id);
          tokens.remove(id);
          if (unresolved == id) unresolved = null;
          await hydrate();
        }
        return projection.resolution(result == null ? null : _map(result));
      default:
        await hydrate();
    }
    switch (request.operation) {
      case 'mediaSnapshot':
        return projection.snapshot;
      case 'read':
        final (archived, query) = value as (bool, String);
        return WorkspaceRead(
          reader.listPlants(
            datasetId: dataset,
            archived: archived,
            query: query,
          ),
          {
            for (final s in TodaySection.values)
              s: reader.getToday(datasetId: dataset, section: s),
          },
        );
      case 'morePlants':
        final (archived, query, cursor) = value as (bool, String, ReadCursor);
        return reader.listPlants(
          datasetId: dataset,
          archived: archived,
          query: query,
          cursor: cursor,
        );
      case 'moreToday':
        final (section, cursor) = value as (TodaySection, ReadCursor);
        return reader.getToday(
          datasetId: dataset,
          section: section,
          cursor: cursor,
        );
      case 'editor':
        return reader.getPlantEditor(
          datasetId: dataset,
          plantId: value as String?,
        );
      case 'detail':
        return reader.getPlantDetail(
          datasetId: dataset,
          plantId: value as String,
        );
      case 'timeline':
        final (plant, voided, cursor) = value as (String, bool, ReadCursor?);
        return reader.listTimeline(
          datasetId: dataset,
          plantId: plant,
          includeVoided: voided,
          cursor: cursor,
        );
      default:
        throw CommandRejected('PROTOCOL_INCOMPATIBLE');
    }
  }
}

Future<void> _serve((RootIsolateToken, SendPort) start) async {
  BackgroundIsolateBinaryMessenger.ensureInitialized(start.$1);
  final worker = _Worker(), commands = ReceivePort();
  start.$2.send(commands.sendPort);
  await for (final message in commands) {
    final request = message as _Request;
    try {
      final value = await worker.dispatch(request);
      start.$2.send(
        _Reply(
          request.id,
          value,
          null,
          request.operation == 'close' ? null : worker.projection.clock.today,
        ),
      );
    } catch (error) {
      final failure =
          error is CommandRejected ||
              error is UnknownCommandOutcome ||
              error is RecoveryUnavailable
          ? error
          : request.mutating && request.commandId != null
          ? UnknownCommandOutcome(request.commandId!)
          : const RecoveryUnavailable();
      start.$2.send(_Reply(request.id, null, failure, null));
    }
  }
}
