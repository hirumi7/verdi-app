import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/cubits/workspace_cubit.dart';
import '../../data/optimization_service.dart';
part 'optimization_cubit.freezed.dart';

@freezed
abstract class OptimizationState with _$OptimizationState {
  const factory OptimizationState({
    @Default([]) List<PlantPhoto> photos,
    @Default([]) List<String> selected,
    @Default(false) bool busy,
    @Default(false) bool running,
    @Default(false) bool recoveryRequired,
    Map<String, Object?>? preview,
    Map<String, Object?>? job,
    String? error,
  }) = _OptimizationState;
}

class OptimizationCubit extends Cubit<OptimizationState> {
  final CollectionRepository repository;
  final OptimizationService service;
  final String plantId;
  String? _jobId;
  int _runVersion = 0;
  bool active(int version) =>
      !isClosed && version == _runVersion && !_cancelRequested;
  bool _cancelRequested = false, _stopping = false;
  OptimizationCubit(this.repository, this.service, this.plantId)
    : super(const OptimizationState());
  static const failures = {
    'FIELD_INVALID',
    'STALE_TARGET',
    'DRAFT_CONFLICT',
    'NOT_FOUND',
    'MEDIA_UNSUPPORTED',
    'MEDIA_INVALID',
    'MEDIA_MISSING',
    'MEDIA_TOO_LARGE',
    'MEDIA_NOT_READY',
    'IO_FAILURE',
    'DISK_FULL',
    'NOT_ELIGIBLE',
  };
  Map<String, Object?> map(Object? value) =>
      (value as Map).cast<String, Object?>();
  Future<Map<String, Object?>> call(
    String operation,
    Map<String, Object?> args,
  ) async =>
      (await service.call(operation, args)) ??
      (throw const RecoveryUnavailable());
  void update(OptimizationState next) {
    if (!isClosed) emit(next);
  }

  Future<void> load() async {
    if (state.busy || state.running || state.recoveryRequired) return;
    update(state.copyWith(busy: true, error: null));
    try {
      final snapshot = await repository.mediaSnapshot();
      final latest = await service.call('latestOptimizationJob', {
        'plantId': plantId,
      });
      final photos =
          snapshot.photos.values.where((p) => p.plantId == plantId).toList()
            ..sort((a, b) => b.observedDate.compareTo(a.observedDate));
      _jobId = latest?['jobId'] as String?;
      update(
        state.copyWith(
          photos: photos,
          selected: [],
          preview: null,
          job: latest,
          busy: false,
        ),
      );
      if (latest?['state'] == 'running') await recover();
    } catch (e) {
      update(state.copyWith(busy: false, error: WorkspaceCubit.code(e)));
    }
  }

  void select(String id) {
    if (state.busy || state.running || state.recoveryRequired) return;
    final selected = [...state.selected];
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      if (selected.length >= 200 || !state.photos.any((p) => p.id == id)) {
        return;
      }
      selected.add(id);
    }
    update(state.copyWith(selected: selected, preview: null, error: null));
  }

  Future<bool> preview() async {
    if (state.selected.isEmpty ||
        state.busy ||
        state.running ||
        state.recoveryRequired) {
      return false;
    }
    update(state.copyWith(busy: true, error: null));
    try {
      final preview = await call('previewOptimization', {
        'datasetId': repository.datasetId,
        'plantId': plantId,
        'targets': [
          for (final id in state.selected)
            {
              'photoId': id,
              'photoRevision': state.photos
                  .firstWhere((p) => p.id == id)
                  .revision,
            },
        ],
        'longEdge': 1280,
        'jpegQualityPercent': 85,
      });
      update(state.copyWith(busy: false, preview: preview));
      return !isClosed;
    } catch (e) {
      update(state.copyWith(busy: false, error: WorkspaceCubit.code(e)));
      return false;
    }
  }

  void cancelPreview() => update(state.copyWith(preview: null));
  Future<void> start() async {
    final preview = state.preview;
    if (preview == null ||
        state.busy ||
        state.running ||
        state.recoveryRequired) {
      return;
    }
    final jobId = repository.newId(), version = ++_runVersion;
    _jobId = jobId;
    _cancelRequested = false;
    update(
      state.copyWith(
        busy: true,
        running: true,
        preview: null,
        error: null,
        job: null,
      ),
    );
    try {
      final job = await call('startOptimization', {
        'datasetId': repository.datasetId,
        'jobId': jobId,
        'previewToken': preview['previewToken'],
      });
      if (!active(version)) return;
      update(state.copyWith(job: job, busy: false));
      for (final raw in job['results'] as List) {
        if (!active(version)) return;
        final target = map(raw);
        if (target['state'] != 'pending') continue;
        String? failure;
        try {
          await service.saveDraft(
            SaveMediaDraft(
              draftId: target['draftId'] as String,
              expectedRevision: null,
              plantId: plantId,
              photoId: target['photoId'] as String,
              basePhotoRevision: target['photoRevision'] as int,
            ),
            target['draftCommandId'] as String,
          );
          if (!active(version)) return;
          var status = await call('prepareOptimizationPhoto', {
            'jobId': jobId,
            'photoId': target['photoId'],
          });
          while (status['kind'] == 'copying') {
            await Future<void>.delayed(const Duration(milliseconds: 150));
            if (!active(version)) return;
            status = await repository.photoPreparation(
              target['preparationId'] as String,
            );
          }
          if (!active(version)) return;
          if (status['kind'] != 'ready') {
            throw CommandRejected(
              status['code'] as String? ?? 'MEDIA_NOT_READY',
            );
          }
          final prepared = await repository.prepare(
            ReplacePhoto(
              target['photoId'] as String,
              target['photoRevision'] as int,
              preparationId: target['preparationId'] as String,
              draftId: target['draftId'] as String,
              draftRevision: status['draftRevision'] as int,
            ),
            commandId: target['replaceCommandId'] as String,
          );
          if (!active(version)) return;
          await repository.confirm(prepared);
        } catch (e) {
          if (!active(version)) return;
          final code = WorkspaceCubit.code(e);
          if (e is UnknownCommandOutcome ||
              e is RecoveryUnavailable ||
              !failures.contains(code)) {
            rethrow;
          }
          failure = code;
        }
        if (!active(version)) return;
        final result = await call('finishOptimizationTarget', {
          'jobId': jobId,
          'photoId': target['photoId'],
          'code': failure,
        });
        if (!active(version)) return;
        update(
          state.copyWith(job: result, running: result['state'] == 'running'),
        );
      }
      update(state.copyWith(running: false, busy: false, selected: []));
      await refreshPhotos();
    } catch (e) {
      if (!active(version)) return;
      update(
        state.copyWith(
          busy: false,
          recoveryRequired: true,
          error: WorkspaceCubit.code(e),
        ),
      );
      await recover();
    }
  }

  Future<void> refreshPhotos() async {
    try {
      final snapshot = await repository.mediaSnapshot();
      update(
        state.copyWith(
          photos: snapshot.photos.values
              .where((p) => p.plantId == plantId)
              .toList(),
        ),
      );
    } catch (e) {
      update(state.copyWith(error: WorkspaceCubit.code(e)));
    }
  }

  Future<void> recover() => stop('interrupted');
  Future<void> cancel() => stop('cancelled');
  Future<void> stop(String reason) async {
    if (_stopping || _jobId == null) return;
    _cancelRequested = true;
    ++_runVersion;
    final jobId = _jobId;
    _stopping = true;
    update(state.copyWith(busy: true, recoveryRequired: true));
    try {
      final result = await call('stopOptimization', {
        'jobId': jobId,
        'reason': reason,
      });
      if (result['state'] == 'running') throw const RecoveryUnavailable();
      update(
        state.copyWith(
          job: result,
          busy: false,
          running: false,
          recoveryRequired: false,
          selected: [],
          error: null,
        ),
      );
      await refreshPhotos();
    } on CommandRejected catch (e) {
      if (e.code == 'NOT_FOUND') {
        // Authoritative absence after reconnect means no job was recorded.
        _jobId = null;
        update(
          state.copyWith(
            job: null,
            busy: false,
            running: false,
            recoveryRequired: false,
            error: 'OPTIMIZATION_NOT_STARTED',
          ),
        );
      } else {
        update(
          state.copyWith(busy: false, recoveryRequired: true, error: e.code),
        );
      }
    } catch (e) {
      update(
        state.copyWith(
          busy: false,
          recoveryRequired: true,
          error: WorkspaceCubit.code(e),
        ),
      );
    } finally {
      _stopping = false;
    }
  }

  @override
  Future<void> close() async {
    ++_runVersion;
    if (state.running || state.recoveryRequired) await stop('interrupted');
    return super.close();
  }
}
