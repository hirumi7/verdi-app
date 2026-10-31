import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../data/repositories/collection_repository.dart';
import 'workspace_cubit.dart';
part 'plant_editor_cubit.freezed.dart';

@freezed
abstract class PlantEditorState with _$PlantEditorState {
  const factory PlantEditorState({
    CustomPlantFields? fields,
    PlantDraft? draft,
    @Default(true) bool loading,
    @Default(false) bool picking,
    @Default([]) List<RoutineRead> existingRoutines,
    @Default(false) bool saving,
    @Default(false) bool dirty,
    String? errorCode,
    @Default({}) Map<String, String> errors,
  }) = _PlantEditorState;
}

@injectable
class PlantEditorCubit extends Cubit<PlantEditorState> {
  final CollectionRepository _repository;
  Timer? _debounce;
  Future<void>? _writing;
  int _version = 0;
  int _acknowledged = 0;
  SaveDraft? _pendingSave;
  int? _pendingVersion;
  CommandSuccess? _pendingResult;
  DiscardDraft? _pendingDiscard;
  String? _plantId;
  int? _baseRevision;
  late String _draftId;
  CustomPlantFields? _original;
  PlantEditorCubit(this._repository) : super(const PlantEditorState());

  Future<void> load(String? plantId) async {
    _plantId = plantId;
    try {
      final editor = await _repository.editor(plantId);
      if (isClosed) return;
      _draftId = editor.draft?.id ?? _repository.newId();
      _baseRevision = editor.draft?.basePlantRevision ?? editor.plantRevision;
      final detail = plantId == null ? null : await _repository.detail(plantId);
      if (detail != null) {
        final plant = detail.plant;
        _original = CustomPlantFields(
          name: plant.name,
          speciesName: plant.speciesName,
          light: plant.light,
          toxicity: plant.toxicity,
          catalogSelection: plant.catalogSelection,
        );
      }
      if (isClosed) return;
      emit(
        state.copyWith(
          fields: editor.initialFields,
          draft: editor.draft,
          loading: false,
          picking: plantId == null && editor.draft == null,
          existingRoutines:
              detail?.routines
                  .where((r) => r.routine.status != RoutineStatus.retired)
                  .toList() ??
              [],
          dirty: editor.draft != null,
        ),
      );
    } catch (error) {
      if (!isClosed) {
        emit(
          state.copyWith(loading: false, errorCode: WorkspaceCubit.code(error)),
        );
      }
    }
  }

  void update({
    String? name,
    String? species,
    String? location,
    String? notes,
    CustomLight? light,
    CustomToxicity? toxicity,
    List<RoutineInput>? routines,
    CatalogSelection? selection,
    bool custom = false,
    bool resetChoices = false,
    Iterable<String>? keep,
    Map<String, CareInterval>? apply,
  }) {
    final old = state.fields!;
    final selected = custom ? null : selection ?? old.catalogSelection;
    final nextSpecies =
        selected?.speciesNameSnapshot ?? species ?? old.speciesName;
    final nextLight = light ?? old.light;
    final nextToxicity = toxicity ?? old.toxicity;
    final changed =
        _original != null &&
        (nextSpecies.trim() != _original!.speciesName ||
            nextLight != _original!.light ||
            nextToxicity != _original!.toxicity ||
            !(selected?.same(_original!.catalogSelection) ??
                _original!.catalogSelection == null));
    final identityEdited =
        nextSpecies != old.speciesName ||
        nextLight != old.light ||
        nextToxicity != old.toxicity ||
        !(selected?.same(old.catalogSelection) ?? old.catalogSelection == null);
    final clearChoices = resetChoices || identityEdited;
    final fields = CustomPlantFields(
      name: name ?? old.name,
      speciesName: nextSpecies,
      location: location ?? old.location,
      notes: notes ?? old.notes,
      light: nextLight,
      toxicity: nextToxicity,
      routines: routines ?? old.routines,
      baseRoutineRevisions: old.baseRoutineRevisions,
      catalogSelection: selected,
      keepRoutineIds: changed && !clearChoices
          ? keep ?? old.keepRoutineIds
          : const [],
      applyRoutineIntervals: changed && !clearChoices
          ? apply ?? old.applyRoutineIntervals
          : const {},
    );
    _version++;
    emit(
      state.copyWith(
        fields: fields,
        dirty: true,
        saving: true,
        errorCode: null,
        errors: {},
      ),
    );
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        await flush();
      } catch (_) {}
    });
  }

  void openPicker() => emit(state.copyWith(picking: true));
  void closePicker() => emit(state.copyWith(picking: false));
  bool get identityChanged {
    final f = state.fields, original = _original;
    return f != null &&
        original != null &&
        (f.speciesName.trim() != original.speciesName ||
            f.light != original.light ||
            f.toxicity != original.toxicity ||
            !(f.catalogSelection?.same(original.catalogSelection) ??
                original.catalogSelection == null));
  }

  Future<void> select(CatalogEntry entry) async {
    try {
      final catalog = await _repository.catalog();
      final current = catalog.entry(entry.id);
      if (catalog.version != entry.version ||
          current?.active != true ||
          !entry.selection.same(current!.selection)) {
        throw CommandRejected('CATALOG_SELECTION_STALE');
      }
      update(
        selection: entry.selection,
        light: CustomLight.unknown,
        toxicity: CustomToxicity.unknown,
        resetChoices: true,
      );
      await flush();
      if (!isClosed) closePicker();
    } catch (error) {
      reportError(error);
      rethrow;
    }
  }

  Future<void> selectCustom(String query) async {
    final f = state.fields!;
    update(
      custom: true,
      species: f.catalogSelection == null && f.speciesName.isNotEmpty
          ? f.speciesName
          : query.trim(),
      resetChoices: f.catalogSelection != null,
    );
    await flush();
    if (!isClosed) closePicker();
  }

  void chooseRoutine(String id, CareInterval? interval) {
    final f = state.fields!;
    final keep = f.keepRoutineIds.toSet()..remove(id);
    final apply = {...f.applyRoutineIntervals}..remove(id);
    if (interval == null) {
      keep.add(id);
    } else {
      apply[id] = interval;
    }
    update(keep: keep, apply: apply);
  }

  Future<void> flush() async {
    _debounce?.cancel();
    if (_writing != null) {
      await _writing;
      if (_acknowledged == _version) return;
    }
    if (_acknowledged == _version) return;
    final operation = _drain();
    _writing = operation;
    try {
      await operation;
    } finally {
      if (identical(_writing, operation)) _writing = null;
    }
  }

  Future<void> _drain() async {
    while (_acknowledged != _version && !isClosed) {
      emit(state.copyWith(saving: true, errorCode: null));
      try {
        // Retain the exact payload/version until both the write and read-back
        // are acknowledged. New keystrokes remain in state and follow it.
        _pendingVersion ??= _version;
        final command = _pendingSave ??= SaveDraft(
          draftId: _draftId,
          expectedRevision: state.draft?.revision,
          mode: _plantId == null ? DraftMode.add : DraftMode.edit,
          plantId: _plantId,
          basePlantRevision: _baseRevision,
          fields: state.fields!,
        );
        if (_pendingResult == null) {
          try {
            _pendingResult = await _repository.submit(command);
          } on UnknownCommandOutcome catch (error) {
            final resolution = await _repository.resolve(error.commandId);
            if (!resolution.committed) rethrow;
            _pendingResult = resolution.result;
          }
        }
        final editor = await _repository.editor(_plantId);
        if (isClosed) return;
        if (editor.draft?.id != _draftId ||
            editor.draft?.revision != _pendingResult!.newRevisions[_draftId]) {
          // The receipt acknowledges our write, not a newer editor's revision.
          // Keep local fields and require explicit current-version review.
          _pendingSave = null;
          _pendingVersion = null;
          _pendingResult = null;
          throw CommandRejected('DRAFT_CONFLICT');
        }
        _acknowledged = _pendingVersion!;
        _pendingSave = null;
        _pendingVersion = null;
        _pendingResult = null;
        emit(
          state.copyWith(
            draft: editor.draft,
            saving: _acknowledged != _version,
          ),
        );
      } catch (error) {
        if (error is CommandRejected && _pendingResult == null) {
          _pendingSave = null;
          _pendingVersion = null;
        }
        if (!isClosed) {
          emit(
            state.copyWith(
              saving: false,
              errorCode: WorkspaceCubit.code(error),
            ),
          );
        }
        rethrow;
      }
    }
  }

  Future<PreparedCommand> preview() async {
    if (state.draft == null && _version == 0) _version++;
    await flush();
    try {
      final draft = state.draft!;
      return await _repository.prepare(
        SavePlant(draftId: draft.id, draftRevision: draft.revision),
      );
    } on CommandRejected catch (error) {
      emit(state.copyWith(errorCode: error.code, errors: error.fields));
      rethrow;
    }
  }

  Future<({PlantEditor editor, PlantDetail? detail})> currentForReview() async {
    final editor = await _repository.editor(_plantId);
    final detail = _plantId == null
        ? null
        : await _repository.detail(_plantId!);
    if (detail != null && detail.plant.revision != editor.plantRevision) {
      throw CommandRejected('STALE_TARGET');
    }
    return (editor: editor, detail: detail);
  }

  /// Called only after the user reviews the newly read version and explicitly
  /// keeps this editor's fields. Saving still guards that exact reviewed base.
  Future<void> keepFieldsAfterReview(
    ({PlantEditor editor, PlantDetail? detail}) review,
  ) async {
    final reviewed = review.editor;
    _debounce?.cancel();
    if (_pendingSave != null || _pendingDiscard != null) {
      throw const RecoveryUnavailable();
    }
    if (reviewed.draft == null && state.draft != null) {
      throw CommandRejected('NOT_ELIGIBLE');
    }
    _draftId = reviewed.draft?.id ?? _draftId;
    _baseRevision = reviewed.plantRevision;
    final savedPlant = review.detail?.plant;
    if (savedPlant != null && savedPlant.revision != reviewed.plantRevision) {
      throw CommandRejected('STALE_TARGET');
    }
    final f = state.fields!;
    final bases = _plantId == null
        ? const <String, int>{}
        : {
            for (final r in review.detail!.routines)
              if (r.routine.status != RoutineStatus.retired)
                r.routine.id: r.routine.revision,
          };
    if (savedPlant != null) {
      _original = CustomPlantFields(
        name: savedPlant.name,
        speciesName: savedPlant.speciesName,
        light: savedPlant.light,
        toxicity: savedPlant.toxicity,
        catalogSelection: savedPlant.catalogSelection,
      );
    }
    emit(
      state.copyWith(
        draft: reviewed.draft,
        existingRoutines:
            review.detail?.routines
                .where((r) => r.routine.status != RoutineStatus.retired)
                .toList() ??
            [],
        fields: CustomPlantFields(
          name: f.name,
          speciesName: f.speciesName,
          location: f.location,
          notes: f.notes,
          light: f.light,
          toxicity: f.toxicity,
          routines: f.routines,
          catalogSelection: f.catalogSelection,
          baseRoutineRevisions: bases,
        ),
      ),
    );
    update();
    await flush();
  }

  Future<void> discard() async {
    try {
      if (_pendingDiscard == null) {
        await flush();
        final draft = state.draft;
        if (draft != null) {
          _pendingDiscard = DiscardDraft(
            draftId: draft.id,
            draftRevision: draft.revision,
            confirmed: true,
          );
        }
      }
      if (_pendingDiscard != null) {
        try {
          await _repository.submit(_pendingDiscard!);
        } on UnknownCommandOutcome catch (error) {
          final result = await _repository.resolve(error.commandId);
          if (!result.committed) rethrow;
        }
      }
      _pendingDiscard = null;
      _acknowledged = _version;
      emit(
        state.copyWith(
          dirty: false,
          draft: null,
          saving: false,
          errorCode: null,
        ),
      );
    } catch (error) {
      if (error is CommandRejected) _pendingDiscard = null;
      if (error is CommandRejected &&
          const {
            'STALE_TARGET',
            'DRAFT_CONFLICT',
            'NOT_ELIGIBLE',
            'NOT_FOUND',
          }.contains(error.code) &&
          _pendingSave == null) {
        // Confirmed discard may abandon a consumed/replaced draft locally. It
        // must never remove the other editor's plant or replacement draft.
        try {
          final current = await _repository.editor(_plantId);
          if (current.draft?.id != _draftId) {
            _debounce?.cancel();
            _acknowledged = _version;
            emit(
              state.copyWith(
                dirty: false,
                draft: null,
                saving: false,
                errorCode: null,
              ),
            );
            return;
          }
        } catch (readError) {
          if (readError is DomainException && readError.code == 'NOT_FOUND') {
            _debounce?.cancel();
            _acknowledged = _version;
            emit(
              state.copyWith(
                dirty: false,
                draft: null,
                saving: false,
                errorCode: null,
              ),
            );
            return;
          }
          reportError(readError);
          rethrow;
        }
      }
      emit(
        state.copyWith(saving: false, errorCode: WorkspaceCubit.code(error)),
      );
      rethrow;
    }
  }

  void committed() {
    _debounce?.cancel();
    emit(state.copyWith(dirty: false, draft: null));
  }

  void reportError(Object error) {
    if (!isClosed) emit(state.copyWith(errorCode: WorkspaceCubit.code(error)));
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
