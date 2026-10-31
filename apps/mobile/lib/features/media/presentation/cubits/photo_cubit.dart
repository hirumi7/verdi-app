import 'dart:async';

import '../../domain/preparation_failure.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/cubits/workspace_cubit.dart';
part 'photo_cubit.freezed.dart';

@freezed
abstract class PhotoState with _$PhotoState {
  const factory PhotoState({
    @Default([]) List<PlantPhoto> photos,
    String? coverId,
    MediaDraft? replacement,
    @Default(false) bool busy,
    String? errorCode,
    String? preparationId,
    String? preparationKind,
  }) = _PhotoState;
}

class PhotoCubit extends Cubit<PhotoState> {
  final CollectionRepository repository;
  final String plantId;
  String? _selection;
  LocalDate? _date;
  SaveMediaDraft? _pendingDraft;
  int _loadVersion = 0;
  int? _preparationRevision;
  PhotoCubit(this.repository, this.plantId) : super(const PhotoState());
  Future<bool> load({String? photoId}) async {
    final version = ++_loadVersion;
    try {
      final snapshot = await repository.mediaSnapshot();
      final photos =
          snapshot.photos.values.where((p) => p.plantId == plantId).toList()
            ..sort((a, b) {
              final order = b.observedDate.compareTo(a.observedDate);
              if (order != 0) return order;
              final recorded = b.createdAt.compareTo(a.createdAt);
              return recorded == 0 ? b.id.compareTo(a.id) : recorded;
            });
      final draft = snapshot.mediaDrafts.values
          .where((d) => d.photoId == photoId)
          .firstOrNull;
      if (isClosed || version != _loadVersion) return false;
      emit(
        state.copyWith(
          photos: photos,
          coverId: snapshot.covers[plantId],
          replacement: draft,
          errorCode: null,
          preparationId: null,
          preparationKind: null,
        ),
      );
      if (draft != null) {
        final preparations = await repository.draftPreparations(draft.id);
        if (isClosed || version != _loadVersion) return false;
        if (preparations.isNotEmpty) {
          final last = preparations.last;
          _preparationRevision = last['draftRevision'] as int;
          final status = (last['status'] as Map).cast<String, Object?>();
          _selection = last['selectionId'] as String;
          _date = last['observedDate'] == null
              ? null
              : LocalDate.parse(last['observedDate'] as String);
          emit(
            state.copyWith(
              preparationId: last['preparationId'] as String,
              preparationKind: status['kind'] as String,
              errorCode: status['code'] as String?,
            ),
          );
        }
      }
      return true;
    } catch (e) {
      error(e);
      return false;
    }
  }

  void error(Object e) {
    if (!isClosed) {
      emit(
        state.copyWith(
          busy: false,
          preparationKind: preparationRejected(e)
              ? 'failed'
              : state.preparationKind,
          errorCode: WorkspaceCubit.code(e),
        ),
      );
    }
  }

  Future<MediaDraft> editor(PlantPhoto photo) async {
    if (_pendingDraft != null) {
      await repository.submit(_pendingDraft!);
      _pendingDraft = null;
    }
    if (!await load(photoId: photo.id)) throw const RecoveryUnavailable();
    if (state.replacement != null) {
      if (_pendingDraft != null) {
        await repository.submit(_pendingDraft!);
        _pendingDraft = null;
      }
      return state.replacement!;
    }
    final command = _pendingDraft ??= SaveMediaDraft(
      draftId: repository.newId(),
      expectedRevision: null,
      plantId: plantId,
      photoId: photo.id,
      basePhotoRevision: photo.revision,
    );
    await repository.submit(command);
    _pendingDraft = null;
    await load(photoId: photo.id);
    final draft = state.replacement;
    if (draft == null) throw const RecoveryUnavailable();
    return draft;
  }

  Future<void> attach(
    PlantPhoto photo,
    String selection,
    LocalDate date,
  ) async {
    final draft = await editor(photo), id = repository.newId();
    _selection = selection;
    _date = date;
    _preparationRevision = draft.revision;
    emit(
      state.copyWith(
        busy: true,
        preparationId: id,
        preparationKind: 'copying',
        errorCode: null,
      ),
    );
    try {
      await repository.preparePhoto(
        draftId: draft.id,
        draftRevision: draft.revision,
        preparationId: id,
        selectionId: selection,
        observedDate: date,
      );
      await resolve(photo.id);
    } catch (e) {
      error(e);
    }
  }

  Future<void> resolve(String photoId) async {
    final id = state.preparationId;
    if (id == null) return;
    emit(state.copyWith(busy: true));
    try {
      while (!isClosed) {
        Map<String, Object?> status;
        try {
          status = await repository.photoPreparation(id);
        } on CommandRejected catch (e) {
          if (e.code != 'NOT_FOUND' ||
              _selection == null ||
              _date == null ||
              _preparationRevision == null ||
              state.replacement == null) {
            rethrow;
          }
          status = await repository.preparePhoto(
            draftId: state.replacement!.id,
            draftRevision: _preparationRevision!,
            preparationId: id,
            selectionId: _selection!,
            observedDate: _date!,
          );
        }
        if (status['kind'] == 'copying') {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        emit(
          state.copyWith(
            preparationKind: status['kind'] as String,
            busy: false,
            errorCode: status['code'] as String?,
          ),
        );
        await load(photoId: photoId);
        return;
      }
    } catch (e) {
      error(e);
    }
  }

  Future<void> retry(PlantPhoto photo) async {
    final id = state.preparationId;
    if (id == null) return;
    if (state.preparationKind != 'failed') {
      await resolve(photo.id);
      return;
    }
    Map<String, Object?> status;
    try {
      status = await repository.photoPreparation(id);
    } on CommandRejected catch (e) {
      if (e.code != 'NOT_FOUND') rethrow;
      await resolve(photo.id);
      return;
    }
    if (status['kind'] != 'failed') {
      await resolve(photo.id);
      return;
    }
    if (_selection == null || _date == null) throw const RecoveryUnavailable();
    await attach(photo, _selection!, _date!);
  }

  Future<PreparedCommand> prepareReplacement(PlantPhoto photo) async {
    final draft = state.replacement, id = state.preparationId;
    if (draft == null || id == null || state.preparationKind != 'ready') {
      throw CommandRejected('MEDIA_NOT_READY');
    }
    return repository.prepare(
      ReplacePhoto(
        photo.id,
        photo.revision,
        preparationId: id,
        draftId: draft.id,
        draftRevision: draft.revision,
      ),
    );
  }

  Future<void> discardReplacement() async {
    final draft = state.replacement;
    if (draft == null) return;
    await repository.submit(
      DiscardMediaDraft(draft.id, draft.revision, confirmed: true),
    );
    emit(
      state.copyWith(
        replacement: null,
        preparationId: null,
        preparationKind: null,
        errorCode: null,
      ),
    );
  }

  Future<PreparedCommand> rebase(PlantPhoto photo) async {
    final draft = state.replacement;
    if (draft == null) throw CommandRejected('NOT_FOUND');
    return repository.prepare(
      RebaseMediaDraft(draft.id, draft.revision, photo.revision),
    );
  }
}
