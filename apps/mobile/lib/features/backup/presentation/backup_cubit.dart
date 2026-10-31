import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../data/backup_service.dart';
part 'backup_cubit.freezed.dart';

Map<String, Object?> backupMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : {};

@freezed
abstract class BackupState with _$BackupState {
  const BackupState._();
  const factory BackupState({
    Map<String, Object?>? operation,
    @Default(false) bool busy,
    @Default(false) bool replacing,
    String? error,
    String? shareResult,
  }) = _BackupState;
  Map<String, Object?> get job => backupMap(operation?['operation']);
  Map<String, Object?> get result => backupMap(job['state']);
  String? get phase => result['kind'] as String?;
  String? get id => operation?['operationId'] as String?;
  bool get working => const {
    'preparing',
    'writing',
    'validating',
    'selected',
    'staging',
    'prepared',
    'switching',
    'verifying',
  }.contains(phase);
  bool get committedBoundary =>
      const {'prepared', 'switching', 'verifying'}.contains(phase);
  bool get fileCreated =>
      phase == 'file_created' || result['fileCreated'] == true;
}

class BackupCubit extends Cubit<BackupState> {
  final BackupService service;
  final String datasetId;
  final String Function() newId;
  Timer? _poll;
  bool _polling = false;
  BackupCubit(this.service, {required this.datasetId, required this.newId})
    : super(const BackupState());

  Future<void> load() => _action(
    () async => _accept(await service.call('latestBackupOperation', {})),
  );
  void _accept(Map<String, Object?>? operation) {
    if (isClosed) return;
    final next = state.copyWith(operation: operation, error: null);
    emit(
      next.copyWith(
        replacing:
            next.replacing &&
            !const {
              'complete',
              'failed',
              'cancelled',
              'preview_ready',
            }.contains(next.phase),
      ),
    );
    _schedule();
  }

  void _schedule() {
    _poll?.cancel();
    if (isClosed || state.id == null || (!state.working && !state.replacing)) {
      return;
    }
    _poll = Timer(const Duration(milliseconds: 350), poll);
  }

  Future<void> poll() async {
    if (isClosed || _polling || state.id == null) return;
    if (state.busy) {
      _schedule();
      return;
    }
    _polling = true;
    try {
      _accept(await service.call('backupStatus', {'operationId': state.id}));
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: _code(error)));
    } finally {
      _polling = false;
      _schedule();
    }
  }

  Future<void> _action(Future<void> Function() action) async {
    if (state.busy || isClosed) return;
    emit(state.copyWith(busy: true, error: null, shareResult: null));
    try {
      await action();
    } catch (error) {
      if (!isClosed) emit(state.copyWith(error: _code(error)));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(busy: false));
        _schedule();
      }
    }
  }

  Future<void> create() => _action(() async {
    _accept(
      await service.call('startExport', {
        'operationId': newId(),
        'datasetId': datasetId,
      }),
    );
  });
  Future<void> choose() => _action(() async {
    final selected = await service.choose();
    if (selected == null || isClosed) return;
    _accept(
      await service.call('startImport', {
        'operationId': newId(),
        'selectionHandle': selected,
      }),
    );
  });
  Future<void> cancel() => _action(() async {
    _accept(await service.call('cancelBackup', {'operationId': state.id}));
  });
  Future<void> retry() => _action(() async {
    _accept(await service.call('retryImport', {'operationId': state.id}));
  });
  Future<void> confirm() => _action(() async {
    if (state.phase != 'preview_ready') return;
    emit(state.copyWith(replacing: true));
    _accept(
      await service.call('confirmImport', {
        'operationId': state.id,
        'preview': state.result['preview'],
        'confirmed': true,
      }),
    );
  });
  Future<void> share() => _action(() async {
    // A persisted handle is not authority after process restart; renew by hash.
    _accept(await service.call('renewExportHandle', {'operationId': state.id}));
    final result = await service.share({
      'operationId': state.id,
      'exportHandle': state.result['exportHandle'],
    });
    final operation = await service.call('backupStatus', {
      'operationId': state.id,
    });
    _accept(operation);
    if (!isClosed) emit(state.copyWith(shareResult: result));
  });
  static String _code(Object error) =>
      error is PlatformException ? error.code : 'IO_FAILURE';
  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
