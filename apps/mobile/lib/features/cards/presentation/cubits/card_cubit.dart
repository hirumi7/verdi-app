import 'dart:async';

import 'package:flutter/services.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/cubits/workspace_cubit.dart';
import '../../data/card_service.dart';
part 'card_cubit.freezed.dart';

@freezed
abstract class CardState with _$CardState {
  const factory CardState({
    @Default(false) bool busy,
    @Default([]) List<PlantPhoto> photos,
    @Default([]) List<String> selected,
    @Default('illustration') String imageChoice,
    @Default(false) bool hasCover,
    String? token,
    Uint8List? bytes,
    @Default('') String name,
    @Default('') String species,
    @Default([]) List<String> dates,
    String? error,
    String? outcome,
  }) = _CardState;
}

class CardCubit extends Cubit<CardState> {
  final CollectionRepository repository;
  final CardService service;
  final String plantId;
  final bool comparison;
  String? dataset;
  CardCubit(
    this.repository,
    this.service,
    this.plantId, {
    this.comparison = false,
  }) : super(const CardState());
  Future<void> release(String? token) async {
    if (token == null) return;
    try {
      await service.release(token);
    } catch (_) {
      /* Native monotonic expiry/restart cleanup remains authoritative. */
    }
  }

  Future<void> load() async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      final snapshot = await repository.mediaSnapshot();
      if (isClosed) return;
      final plant = snapshot.plants[plantId];
      if (plant == null) throw const DomainException('NOT_FOUND');
      final old = state.token;
      dataset = snapshot.datasetId;
      emit(
        state.copyWith(
          busy: false,
          photos: snapshot.photos.values
              .where((p) => p.plantId == plantId)
              .toList(),
          selected: [],
          token: null,
          bytes: null,
          hasCover: snapshot.covers.containsKey(plantId),
          imageChoice: snapshot.covers.containsKey(plantId)
              ? 'cover'
              : 'illustration',
          name: plant.name,
          species: plant.speciesName,
          error: null,
          outcome: null,
        ),
      );
      await release(old);
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: e is PlatformException ? e.code : WorkspaceCubit.code(e),
          ),
        );
      }
    }
  }

  void select(String id) {
    if (state.busy) return;
    final ids = [...state.selected];
    if (ids.contains(id)) {
      ids.remove(id);
    } else if (ids.length < 2) {
      ids.add(id);
    } else {
      return;
    }
    unawaited(release(state.token));
    emit(
      state.copyWith(
        selected: ids,
        token: null,
        bytes: null,
        error: null,
        outcome: null,
      ),
    );
  }

  void imageChoice(String choice) {
    if (state.busy || state.imageChoice == choice) return;
    unawaited(release(state.token));
    emit(
      state.copyWith(
        imageChoice: choice,
        token: null,
        bytes: null,
        error: null,
        outcome: null,
      ),
    );
  }

  Future<void> prepare() async {
    if (state.busy || (comparison && state.selected.length != 2)) return;
    emit(state.copyWith(busy: true, error: null, outcome: null));
    String? newToken;
    try {
      final snapshot = await repository.mediaSnapshot();
      if (isClosed) return;
      if (snapshot.datasetId != dataset) {
        throw const DomainException('DATASET_CHANGED');
      }
      final plant = snapshot.plants[plantId];
      if (plant == null) throw const DomainException('NOT_FOUND');
      // Selected revisions stay explicit. A changed source requires reloading/reselection.
      final response = await service.prepare({
        'datasetId': snapshot.datasetId,
        'kind': comparison ? 'comparison' : 'plant',
        'plantId': plantId,
        'plantRevision': plant.revision,
        'imageChoice': comparison ? null : state.imageChoice,
        'photos': [
          if (comparison)
            for (final id in state.selected)
              {
                'id': id,
                'revision': state.photos.firstWhere((p) => p.id == id).revision,
              },
        ],
      });
      newToken = response['token'] as String;
      if (isClosed) {
        await release(newToken);
        return;
      }
      final bytes = await service.read(newToken);
      if (isClosed) {
        await release(newToken);
        return;
      }
      final old = state.token;
      emit(
        state.copyWith(
          busy: false,
          token: newToken,
          bytes: bytes,
          name: response['plantName'] as String,
          species: response['speciesName'] as String,
          dates: (response['dates'] as List).cast<String>(),
          error: null,
        ),
      );
      await release(old);
    } catch (e) {
      await release(newToken);
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            error: e is PlatformException ? e.code : WorkspaceCubit.code(e),
          ),
        );
      }
    }
  }

  Future<void> handoff({required bool save}) async {
    final token = state.token;
    if (state.busy || token == null) return;
    emit(state.copyWith(busy: true, error: null, outcome: null));
    try {
      final result = await service.handoff(token, save: save);
      if (!isClosed) {
        emit(
          state.copyWith(
            busy: false,
            outcome: result['outcome'] as String,
            error: result['code'] as String?,
          ),
        );
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(busy: false, error: handoffFailure(e, save: save)));
      }
    }
  }

  static String handoffFailure(Object error, {required bool save}) {
    final code = error is PlatformException
        ? error.code
        : WorkspaceCubit.code(error);
    const known = {
      'BUSY',
      'CARD_EXPIRED',
      'PREVIEW_STALE',
      'MEDIA_MISSING',
      'MEDIA_INVALID',
      'MEDIA_PATH_INVALID',
      'DATASET_CHANGED',
      'STALE_TARGET',
      'PRO_REQUIRED',
      'IO_FAILURE',
      'STORAGE_UNAVAILABLE',
      'CARD_GENERATION_FAILED',
      'PHOTO_SAVE_DENIED',
      'PHOTO_SAVE_FAILED',
      'PHOTO_SAVE_UNKNOWN',
    };
    if (save &&
        (!(error is PlatformException || error is DomainException) ||
            !known.contains(code))) {
      return 'PHOTO_SAVE_UNKNOWN';
    }
    return code;
  }

  @override
  Future<void> close() async {
    final token = state.token;
    await super.close();
    await release(token);
  }
}
