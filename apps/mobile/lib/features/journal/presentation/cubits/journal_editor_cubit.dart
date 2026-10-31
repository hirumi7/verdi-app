import 'dart:async';

import '../../../media/domain/preparation_failure.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/cubits/workspace_cubit.dart';
part 'journal_editor_cubit.freezed.dart';

@freezed
abstract class JournalEditorState with _$JournalEditorState {
  const factory JournalEditorState({
    JournalDraft? draft,
    JournalFields? fields,
    @Default(true) bool loading,
    @Default(false) bool saving,
    @Default(false) bool preparing,
    @Default(false) bool changed,
    @Default(false) bool attachmentFailed,
    @Default(false) bool attachmentPending,
    String? errorCode,
    @Default({}) Map<String, String> errors,
  }) = _JournalEditorState;
}

class JournalEditorCubit extends Cubit<JournalEditorState> {
  final CollectionRepository repository;
  final String plantId;
  final String? entryId;
  Timer? _timer;
  Future<void>? _writing;
  SaveJournalDraft? _pending;
  int _version = 0, _ack = 0;
  String? _draftId, _preparationId, _selectionId;
  LocalDate? _observation;
  int? _preparationRevision;
  bool _noteOnly = false, _conflicted = false;
  JournalEditorCubit(this.repository, this.plantId, this.entryId)
    : super(const JournalEditorState());
  Future<void> load() async {
    try {
      var snapshot = await repository.mediaSnapshot();
      var draft = snapshot.journalDrafts.values
          .where((d) => d.plantId == plantId && d.entryId == entryId)
          .firstOrNull;
      if (draft != null &&
          _pending?.expectedRevision == null &&
          _pending != null) {
        try {
          await repository.submit(_pending!);
        } on CommandRejected catch (e) {
          if (e.code != 'DRAFT_CONFLICT' && e.code != 'STALE_TARGET') rethrow;
        }
        _pending = null;
        _pendingVersion = null;
      }
      if (draft == null) {
        final entry = snapshot.journalEntries[entryId];
        if (entryId != null && entry == null) {
          throw CommandRejected('NOT_FOUND');
        }
        _draftId ??= repository.newId();
        final command = _pending ??= SaveJournalDraft(
          draftId: _draftId!,
          expectedRevision: null,
          plantId: plantId,
          entryId: entryId,
          baseEntryRevision: entry?.revision,
          fields: JournalFields(
            text: entry?.text ?? '',
            entryDate: (entry?.entryDate ?? repository.today).toString(),
            selectedPhotoIds: entry?.photoIds ?? [],
          ),
        );
        try {
          await repository.submit(command);
          _pending = null;
        } on CommandRejected catch (e) {
          if (e.code != 'DRAFT_CONFLICT') rethrow;
          _pending = null;
        }
        snapshot = await repository.mediaSnapshot();
        draft = snapshot.journalDrafts.values
            .where((d) => d.plantId == plantId && d.entryId == entryId)
            .firstOrNull;
      }
      if (draft == null) throw const RecoveryUnavailable();
      _draftId = draft.id;
      if (isClosed) return;
      emit(
        state.copyWith(
          draft: draft,
          fields: draft.fields,
          loading: true,
          changed: draft.revision > 1,
          errorCode: null,
        ),
      );
      final history = await repository.draftPreparations(draft.id);
      if (history.isNotEmpty) {
        final last = history.last,
            status = (last['status'] as Map).cast<String, Object?>();
        if (status['kind'] == 'copying' || status['kind'] == 'failed') {
          _preparationRevision = last['draftRevision'] as int;
          _preparationId = last['preparationId'] as String;
          _selectionId = last['selectionId'] as String;
          _observation = LocalDate.parse(last['observedDate'] as String);
          if (status['kind'] == 'copying') {
            emit(state.copyWith(preparing: true, attachmentPending: true));
            await _poll();
          } else {
            emit(
              state.copyWith(
                attachmentFailed: true,
                errorCode: status['code'] as String?,
              ),
            );
          }
        }
      }
      if (!isClosed) emit(state.copyWith(loading: false));
    } catch (e) {
      _error(e);
    }
  }

  void update({String? text, String? date}) {
    if (state.attachmentPending || state.fields == null) return;
    final old = state.fields!;
    _version++;
    emit(
      state.copyWith(
        fields: JournalFields(
          text: text ?? old.text,
          entryDate: date ?? old.entryDate,
          selectedPhotoIds: old.selectedPhotoIds,
        ),
        changed: true,
        saving: true,
        errorCode: _conflicted ? 'DRAFT_CONFLICT' : null,
        errors: {},
      ),
    );
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 250), () {
      unawaited(flush().catchError((Object _) {}));
    });
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_writing != null) await _writing;
    if (_conflicted) throw CommandRejected('DRAFT_CONFLICT');
    if (_ack == _version && _pending == null) return;
    final work = _write();
    _writing = work;
    try {
      await work;
    } finally {
      _writing = null;
    }
  }

  Future<void> _write() async {
    try {
      while (_ack < _version || _pending != null) {
        final version = _version, draft = state.draft!;
        final command = _pending ??= SaveJournalDraft(
          draftId: draft.id,
          expectedRevision: draft.revision,
          plantId: plantId,
          entryId: entryId,
          baseEntryRevision: draft.baseEntryRevision,
          fields: state.fields!,
          readyPhotoIds: draft.readyPhotoIds,
        );
        _pendingVersion ??= version;
        final result = await repository.submit(command);
        final saved =
            (await repository.mediaSnapshot()).journalDrafts[draft.id];
        if (saved == null || saved.revision != result.newRevisions[draft.id]) {
          _pending = null;
          _pendingVersion = null;
          _conflicted = true;
          throw CommandRejected('DRAFT_CONFLICT');
        }
        // Later keystrokes remain in state; only the frozen payload is acknowledged.
        final sentVersion = command == _pending
            ? _pendingVersion ?? version
            : version;
        _pending = null;
        _pendingVersion = null;
        _ack = sentVersion;
        if (isClosed) return;
        emit(
          state.copyWith(
            draft: saved,
            fields: _ack == _version ? saved.fields : state.fields,
            saving: _ack != _version,
            errorCode: null,
          ),
        );
      }
    } catch (e) {
      if (e is CommandRejected) {
        _pending = null;
        _pendingVersion = null;
        if (e.code == 'STALE_TARGET' ||
            e.code == 'DRAFT_CONFLICT' ||
            e.code == 'NOT_FOUND') {
          _conflicted = true;
        }
      }
      _error(_conflicted ? CommandRejected('DRAFT_CONFLICT') : e);
      rethrow;
    }
  }

  int? _pendingVersion;
  void _error(Object e) {
    if (!isClosed) {
      emit(
        state.copyWith(
          loading: false,
          saving: false,
          errorCode: WorkspaceCubit.code(e),
          errors: e is CommandRejected ? e.fields : {},
        ),
      );
    }
  }

  Future<void> attach(String selection, LocalDate date) async {
    await flush();
    _selectionId = selection;
    _observation = date;
    _noteOnly = false;
    await _startPreparation();
  }

  Future<void> _startPreparation() async {
    _preparationId = repository.newId();
    _preparationRevision = state.draft!.revision;
    emit(
      state.copyWith(
        preparing: true,
        attachmentPending: true,
        attachmentFailed: false,
        errorCode: null,
      ),
    );
    try {
      await repository.preparePhoto(
        draftId: state.draft!.id,
        draftRevision: state.draft!.revision,
        preparationId: _preparationId!,
        selectionId: _selectionId!,
        observedDate: _observation!,
      );
      await _poll();
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            preparing: false,
            attachmentPending: preparationRejected(e)
                ? false
                : state.attachmentPending,
            attachmentFailed: preparationRejected(e)
                ? true
                : state.attachmentFailed,
            errorCode: WorkspaceCubit.code(e),
          ),
        );
      }
    }
  }

  Future<void> _poll() async {
    try {
      while (!isClosed) {
        Map<String, Object?> status;
        try {
          status = await repository.photoPreparation(_preparationId!);
        } on CommandRejected catch (e) {
          if (e.code != 'NOT_FOUND' ||
              _selectionId == null ||
              _preparationRevision == null ||
              _observation == null) {
            rethrow;
          }
          status = await repository.preparePhoto(
            draftId: state.draft!.id,
            draftRevision: _preparationRevision!,
            preparationId: _preparationId!,
            selectionId: _selectionId!,
            observedDate: _observation!,
          );
        }
        if (status['kind'] == 'copying') {
          await Future<void>.delayed(const Duration(milliseconds: 250));
          continue;
        }
        if (status['kind'] == 'failed') {
          emit(
            state.copyWith(
              preparing: false,
              attachmentPending: false,
              attachmentFailed: true,
              errorCode: status['code'] as String?,
            ),
          );
          return;
        }
        final draft =
            (await repository.mediaSnapshot()).journalDrafts[state.draft!.id];
        if (draft == null ||
            status['kind'] != 'ready' ||
            draft.revision != status['draftRevision']) {
          _conflicted = true;
          emit(state.copyWith(attachmentPending: false, preparing: false));
          throw CommandRejected('DRAFT_CONFLICT');
        }
        emit(
          state.copyWith(
            draft: draft,
            fields: draft.fields,
            preparing: false,
            attachmentPending: false,
            changed: true,
            attachmentFailed: false,
            errorCode: null,
          ),
        );
        return;
      }
    } catch (e) {
      if (!isClosed) {
        emit(
          state.copyWith(
            preparing: false,
            attachmentPending: preparationRejected(e)
                ? false
                : state.attachmentPending,
            attachmentFailed: preparationRejected(e)
                ? true
                : state.attachmentFailed,
            errorCode: WorkspaceCubit.code(e),
          ),
        );
      }
    }
  }

  Future<void> resolvePreparation() async {
    if (_preparationId != null) {
      emit(state.copyWith(preparing: true));
      await _poll();
    }
  }

  Future<void> retryAttachment() async {
    await flush();
    // Resolve the original first; only an acknowledged failure permits a new ID.
    Map<String, Object?> status;
    try {
      status = await repository.photoPreparation(_preparationId!);
    } on CommandRejected catch (e) {
      if (e.code != 'NOT_FOUND') rethrow;
      await _startPreparation();
      return;
    }
    if (status['kind'] != 'failed') {
      await resolvePreparation();
      return;
    }
    final draft =
        (await repository.mediaSnapshot()).journalDrafts[state.draft!.id];
    if (draft == null) throw const RecoveryUnavailable();
    emit(state.copyWith(draft: draft));
    await _startPreparation();
  }

  void removeAttachment([String? photoId]) {
    if (state.attachmentPending) return;
    final f = state.fields!;
    _version++;
    emit(
      state.copyWith(
        fields: JournalFields(
          text: f.text,
          entryDate: f.entryDate,
          selectedPhotoIds: photoId == null
              ? const []
              : f.selectedPhotoIds.where((id) => id != photoId),
        ),
        changed: true,
        saving: true,
      ),
    );
    _timer?.cancel();
    _timer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(flush().catchError((Object _) {})),
    );
  }

  void saveNoteOnly() {
    if (state.attachmentPending) return;
    _noteOnly = true;
    emit(state.copyWith(attachmentFailed: false, errorCode: null));
  }

  Future<PreparedCommand> prepareSave() async {
    if (state.attachmentPending ||
        (_preparationId != null &&
            !state.attachmentFailed &&
            !_noteOnly &&
            state.errorCode != null)) {
      throw const RecoveryUnavailable();
    }
    if (state.attachmentFailed && !_noteOnly) {
      throw CommandRejected('MEDIA_NOT_READY');
    }
    await flush();
    return repository.prepare(
      SaveJournalEntry(state.draft!.id, state.draft!.revision),
    );
  }

  Future<JournalDraft?> currentDraft() async {
    if (_pending != null) await flush();
    return (await repository.mediaSnapshot()).journalDrafts[state.draft!.id];
  }

  Future<void> keepFieldsAfterReview(JournalDraft reviewed) async {
    if (_pending != null || state.attachmentPending) {
      throw const RecoveryUnavailable();
    }
    if (reviewed.id != state.draft!.id) throw CommandRejected('DRAFT_CONFLICT');
    _conflicted = false;
    emit(state.copyWith(draft: reviewed, errorCode: null));
    _version++;
    await flush();
  }

  Future<void> discard() async {
    _timer?.cancel();
    if (_pending != null) await flush();
    final current = await currentDraft();
    if (current == null) return; // Only local unsaved fields remain; never delete a replacement slot.
    if (current.revision != state.draft!.revision) {
      throw CommandRejected('DRAFT_CONFLICT');
    }
    await repository.submit(
      DiscardJournalDraft(current.id, current.revision, confirmed: true),
    );
  }

  Future<PreparedCommand> prepareRebase() async {
    await flush();
    final e = (await repository.mediaSnapshot()).journalEntries[entryId];
    if (e == null) throw CommandRejected('NOT_FOUND');
    return repository.prepare(
      RebaseJournalDraft(state.draft!.id, state.draft!.revision, e.revision),
    );
  }

  Future<void> reloadAcknowledged() async {
    final d = (await repository.mediaSnapshot()).journalDrafts[state.draft!.id];
    if (d == null) throw const RecoveryUnavailable();
    emit(state.copyWith(draft: d, fields: d.fields, errorCode: null));
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
