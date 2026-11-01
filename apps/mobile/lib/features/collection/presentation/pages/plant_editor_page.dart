import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/native/draft_bridge.g.dart';
import '../../../media/presentation/widgets/photo_preview.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../cubits/plant_editor_cubit.dart';
import '../../../catalog/presentation/widgets/species_picker.dart';
import '../widgets/presentation_helpers.dart';
import '../widgets/routine_fields_editor.dart';

@RoutePage()
class PlantEditorPage extends StatefulWidget {
  final String? plantId;
  final String? coverPhotoId;
  final bool removeCover;
  const PlantEditorPage({
    super.key,
    this.plantId,
    this.coverPhotoId,
    this.removeCover = false,
  });
  @override
  State<PlantEditorPage> createState() => _PlantEditorPageState();
}

class _PlantEditorPageState extends State<PlantEditorPage>
    with WidgetsBindingObserver {
  late final PlantEditorCubit editor;
  bool reviewing = false;
  bool photoBusy = false;
  String? photoError;
  bool leaving = false;
  final fieldKeys = {
    for (final name in ['name', 'speciesName', 'location', 'notes'])
      name: GlobalKey(),
  };
  final fieldFocus = {
    for (final name in ['name', 'speciesName', 'location', 'notes'])
      name: FocusNode(),
  };
  final routineKeys = {
    for (final kind in standardCareKinds)
      for (final field in ['count', 'seed', 'date'])
        '${kind.name}-$field': GlobalKey(),
  };
  final routineFocus = {
    for (final kind in standardCareKinds)
      for (final field in ['count', 'seed', 'date'])
        '${kind.name}-$field': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    editor = getIt<PlantEditorCubit>();
    editor.load(widget.plantId).then((_) {
      if (editor.state.fields != null &&
          (widget.coverPhotoId != null || widget.removeCover)) {
        editor.update(
          coverPhotoId: widget.coverPhotoId,
          removeCover: widget.removeCover,
        );
      }
    });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && editor.state.fields != null) {
      editor.flush().catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    editor.close();
    for (final node in fieldFocus.values) {
      node.dispose();
    }
    for (final node in routineFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> back() async {
    if (reviewing || photoBusy || editor.state.photoPending) return;
    final s = strings(context);
    if (editor.state.picking &&
        (widget.plantId != null || editor.state.draft != null)) {
      try {
        await editor.flush();
      } catch (_) {
        return;
      }
      editor.closePicker();
      return;
    }
    if (!editor.state.dirty) {
      setState(() => leaving = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.router.maybePop();
      });
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.discardQuestion),
        content: Text(s.discardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(s.keepEditing),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(s.discard),
          ),
        ],
      ),
    );
    if (discard != true) return;
    try {
      await editor.discard();
      if (mounted) {
        setState(() => leaving = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.router.maybePop();
        });
      }
    } catch (_) {}
  }

  Future<void> save() async {
    FocusScope.of(context).unfocus();
    setState(() => reviewing = true);
    try {
      final preview = await editor.preview();
      if (!mounted) return;
      final result = await reviewCommand(
        context,
        preview,
        title: strings(context).reviewSave,
        explanation: strings(context).plantNamed(
          editor.state.fields!.name,
          editor.state.fields!.speciesName,
        ),
      );
      if (result != null && mounted) {
        editor.committed();
        if (widget.plantId == null) {
          await context.router.replace(
            PlantDetailRoute(plantId: result.primaryId!),
          );
        } else {
          setState(() => leaving = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.router.maybePop();
          });
        }
      }
    } catch (_) {
      // Inline state retains all inputs; no route pop or draft reset on failure.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final key in fieldKeys.keys) {
          final errorKey = key == 'speciesName' ? 'customSpeciesName' : key;
          if (!editor.state.errors.containsKey(errorKey)) continue;
          fieldFocus[key]!.requestFocus();
          final target = fieldKeys[key]!.currentContext;
          if (target != null) Scrollable.ensureVisible(target, alignment: .2);
          return;
        }
        final routines = editor.state.fields!.routines;
        for (var i = 0; i < routines.length; i++) {
          for (final field in ['count', 'seed', 'date']) {
            if (!editor.state.errors.containsKey('routineInputs[$i].$field')) {
              continue;
            }
            final key = '${routines[i].kind.name}-$field';
            routineFocus[key]!.requestFocus();
            final target = routineKeys[key]!.currentContext;
            if (target != null) Scrollable.ensureVisible(target, alignment: .2);
            return;
          }
        }
      });
    } finally {
      if (mounted) setState(() => reviewing = false);
    }
  }

  Future<void> reviewLatest() async {
    try {
      final review = await editor.currentForReview();
      if (!mounted) return;
      final s = strings(context);
      final f = review.editor.initialFields;
      final keep = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.reviewLatest),
          scrollable: true,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.conflictReview),
              const SizedBox(height: 16),
              Text(
                '${s.nickname}: ${f.name}\n${s.species}: ${f.speciesName}\n${s.location}: ${f.location}\n${s.notes}: ${f.notes}',
              ),
              for (final r in review.detail?.routines ?? <RoutineRead>[])
                Text(
                  '${kindLabel(s, r.careKind, customLabel: r.routine.careLabel)} · ${careIntervalLabel(s, r.routine.interval)} · ${s.nextAfter(dateLabel(context, r.routine.nextCheck))}',
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.keepMyFields),
            ),
          ],
        ),
      );
      if (keep == true) await editor.keepFieldsAfterReview(review);
    } catch (error) {
      editor.reportError(error);
    }
  }

  Future<void> pickPhoto(String source) async {
    setState(() {
      photoBusy = true;
      photoError = null;
    });
    try {
      await editor.photoDraft();
      final selected = await MediaPlatformHostApi().choosePhoto(source);
      if (selected == null || !mounted) return;
      final today = DateTime.now();
      final local = LocalDate(today.year, today.month, today.day);
      final date = await chooseDate(
        context,
        initial: local,
        latest: local,
        helpText: strings(context).photoObservationDate,
      );
      if (date != null) await editor.attachPhoto(selected, date);
    } catch (e) {
      if (mounted) {
        setState(
          () => photoError = e is PlatformException
              ? e.code
              : e is DomainException
              ? e.code
              : 'UNKNOWN_OUTCOME',
        );
      }
    } finally {
      if (mounted) setState(() => photoBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: editor,
    child: BlocBuilder<PlantEditorCubit, PlantEditorState>(
      builder: (context, state) {
        final s = strings(context);
        final f = state.fields;
        final photoLocked = photoBusy || state.photoPending;
        return PopScope(
          canPop:
              leaving ||
              (!state.dirty && !reviewing && !state.picking && !photoLocked),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back();
          },
          child: Scaffold(
            appBar: AppPageBar(
              context: context,
              leading: IconButton(
                onPressed: back,
                tooltip: s.cancel,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(
                state.picking
                    ? s.chooseSpecies
                    : widget.plantId == null
                    ? s.addPlant
                    : s.editPlant,
              ),
            ),
            body: state.loading || f == null
                ? ListView(
                    padding: AppLayout.pagePadding,
                    children: [
                      AppScrollTitle(
                        title: Text(
                          widget.plantId == null ? s.addPlant : s.editPlant,
                        ),
                      ),
                      if (state.loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ErrorNotice(state.errorCode ?? 'STORAGE_UNAVAILABLE'),
                    ],
                  )
                : state.picking
                ? SpeciesPicker(editor: editor)
                : SingleChildScrollView(
                    key: const ValueKey('plant-editor-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: AppLayout.formPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AppScrollTitle(
                          title: Text(
                            widget.plantId == null ? s.addPlant : s.editPlant,
                          ),
                        ),
                        if (f.catalogSelection != null) ...[
                          FigmaGroup(
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 64,
                                      height: 80,
                                      child: CatalogArtwork(
                                        speciesId:
                                            f.catalogSelection!.speciesId,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        f.speciesName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium!
                                            .copyWith(
                                              fontStyle: FontStyle.italic,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                        ],
                        if (photoLocked) const LinearProgressIndicator(),
                        if (photoError != null ||
                            state.photoFailed ||
                            state.photoPending) ...[
                          ErrorNotice(
                            photoError ?? state.errorCode ?? 'MEDIA_NOT_READY',
                          ),
                          if (photoError == 'CAMERA_DENIED')
                            TextButton(
                              onPressed: () =>
                                  MediaPlatformHostApi().openMediaSettings(),
                              child: Text(s.openSettings),
                            ),
                          OutlinedButton(
                            onPressed: photoBusy
                                ? null
                                : () async {
                                    setState(() => photoBusy = true);
                                    try {
                                      await editor.recoverPhoto();
                                      if (mounted) {
                                        setState(() => photoError = null);
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        setState(
                                          () =>
                                              photoError = e is DomainException
                                              ? e.code
                                              : 'UNKNOWN_OUTCOME',
                                        );
                                      }
                                    } finally {
                                      if (mounted) {
                                        setState(() => photoBusy = false);
                                      }
                                    }
                                  },
                            child: Text(s.checkAttachment),
                          ),
                          Text(s.photoOptionalHint),
                          if (!state.photoPending)
                            TextButton(
                              onPressed: () {
                                editor.continueWithoutPhoto();
                                setState(() => photoError = null);
                              },
                              child: Text(s.photoContinueWithout),
                            ),
                        ],
                        if (f.coverPhotoId != null) ...[
                          PhotoPreview(photoId: f.coverPhotoId!),
                          TextButton(
                            onPressed: photoLocked
                                ? null
                                : () => editor.update(removeCover: true),
                            child: Text(s.removeCover),
                          ),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: photoLocked
                                  ? null
                                  : () => pickPhoto('camera'),
                              icon: const Icon(Icons.photo_camera_outlined),
                              label: Text(s.camera),
                            ),
                            OutlinedButton.icon(
                              onPressed: photoLocked
                                  ? null
                                  : () => pickPhoto('library'),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: Text(s.library),
                            ),
                          ],
                        ),
                        if (state.errorCode != null)
                          ErrorNotice(state.errorCode!),
                        if (state.errorCode == 'STALE_TARGET' ||
                            state.errorCode == 'DRAFT_CONFLICT')
                          OutlinedButton(
                            onPressed: reviewLatest,
                            child: Text(s.reviewLatest),
                          ),
                        if (state.dirty)
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              state.saving
                                  ? s.savingDraft
                                  : state.errorCode == null
                                  ? s.draftSaved
                                  : s.saveFailed,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        const SizedBox(height: 16),
                        AbsorbPointer(
                          absorbing: photoLocked,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                enabled: !photoLocked,
                                key: fieldKeys['name'],
                                focusNode: fieldFocus['name'],
                                initialValue: f.name,
                                decoration: InputDecoration(
                                  labelText: s.nickname,
                                  errorText: state.errors.containsKey('name')
                                      ? s.fieldInvalid
                                      : null,
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (v) => editor.update(name: v),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: photoLocked
                                    ? null
                                    : editor.openPicker,
                                icon: const Icon(Icons.search),
                                label: Text(s.changeSpecies),
                              ),
                              TextFormField(
                                enabled: !photoLocked,
                                readOnly: f.catalogSelection != null,
                                key: fieldKeys['speciesName'],
                                focusNode: fieldFocus['speciesName'],
                                initialValue: f.speciesName,
                                decoration: InputDecoration(
                                  labelText: f.catalogSelection == null
                                      ? s.species
                                      : s.selectedSpecies,
                                  errorText:
                                      state.errors.containsKey(
                                        'customSpeciesName',
                                      )
                                      ? s.fieldInvalid
                                      : null,
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (v) => editor.update(species: v),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                enabled: !photoLocked,
                                key: fieldKeys['location'],
                                focusNode: fieldFocus['location'],
                                initialValue: f.location,
                                decoration: InputDecoration(
                                  labelText: s.location,
                                  errorText:
                                      state.errors.containsKey('location')
                                      ? s.fieldInvalid
                                      : null,
                                ),
                                textInputAction: TextInputAction.next,
                                onChanged: (v) => editor.update(location: v),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                enabled: !photoLocked,
                                key: fieldKeys['notes'],
                                focusNode: fieldFocus['notes'],
                                initialValue: f.notes,
                                minLines: 3,
                                maxLines: 8,
                                decoration: InputDecoration(
                                  labelText: s.notes,
                                  errorText: state.errors.containsKey('notes')
                                      ? s.fieldInvalid
                                      : null,
                                ),
                                onChanged: (v) => editor.update(notes: v),
                              ),
                              const SizedBox(height: 16),
                              if (f.catalogSelection == null)
                                DropdownButtonFormField<CustomLight>(
                                  initialValue: f.light,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: s.light,
                                  ),
                                  items: [
                                    for (final light in CustomLight.values)
                                      DropdownMenuItem(
                                        value: light,
                                        child: Text(switch (light) {
                                          CustomLight.unknown => s.unknown,
                                          CustomLight.low => s.lowLight,
                                          CustomLight.medium => s.mediumLight,
                                          CustomLight.brightIndirect =>
                                            s.brightIndirect,
                                          CustomLight.direct => s.directLight,
                                        }),
                                      ),
                                  ],
                                  onChanged: (v) => editor.update(light: v),
                                ),
                              const SizedBox(height: 16),
                              if (f.catalogSelection == null)
                                DropdownButtonFormField<CustomToxicity>(
                                  initialValue: f.toxicity,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: s.toxicity,
                                  ),
                                  items: [
                                    for (final value in CustomToxicity.values)
                                      DropdownMenuItem(
                                        value: value,
                                        child: Text(switch (value) {
                                          CustomToxicity.unknown => s.unknown,
                                          CustomToxicity.toxic => s.toxic,
                                          CustomToxicity.nonToxic => s.nonToxic,
                                        }),
                                      ),
                                  ],
                                  onChanged: (v) => editor.update(toxicity: v),
                                ),
                              if (widget.plantId == null)
                                RoutineFieldsEditor(
                                  fieldKeys: routineKeys,
                                  fieldFocus: routineFocus,
                                  routines: f.routines,
                                  suggestions:
                                      f.catalogSelection?.suggestions ?? [],
                                  errors: state.errors,
                                  onChanged: (routines) =>
                                      editor.update(routines: routines),
                                ),
                              if (editor.identityChanged) ...[
                                Text(s.chooseSpeciesRoutine),
                                for (final row in state.existingRoutines)
                                  Builder(
                                    builder: (context) {
                                      final id = row.routine.id,
                                          proposal = f.catalogSelection
                                              ?.suggestion(row.careKind);
                                      return Card(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                kindLabel(
                                                  s,
                                                  row.careKind,
                                                  customLabel:
                                                      row.routine.careLabel,
                                                ),
                                              ),
                                              RadioGroup<String>(
                                                groupValue:
                                                    f.keepRoutineIds.contains(
                                                      id,
                                                    )
                                                    ? 'keep'
                                                    : f.applyRoutineIntervals
                                                          .containsKey(id)
                                                    ? 'apply'
                                                    : null,
                                                onChanged: (value) {
                                                  if (value == 'keep') {
                                                    editor.chooseRoutine(
                                                      id,
                                                      null,
                                                    );
                                                  } else if (proposal != null) {
                                                    editor.chooseRoutine(
                                                      id,
                                                      proposal.interval,
                                                    );
                                                  }
                                                },
                                                child: Column(
                                                  children: [
                                                    RadioListTile(
                                                      value: 'keep',
                                                      title: Text(
                                                        s.keepRoutine,
                                                      ),
                                                      subtitle: Text(
                                                        careIntervalLabel(
                                                          s,
                                                          row.routine.interval,
                                                        ),
                                                      ),
                                                    ),
                                                    if (proposal != null)
                                                      RadioListTile(
                                                        value: 'apply',
                                                        title: Text(
                                                          s.applySuggestion,
                                                        ),
                                                        subtitle: Text(
                                                          proposal.context,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (f.applyRoutineIntervals[id]
                                                  case final interval?)
                                                TextButton(
                                                  onPressed: () async {
                                                    final chosen =
                                                        await chooseInterval(
                                                          context,
                                                          interval,
                                                        );
                                                    if (chosen != null) {
                                                      editor.chooseRoutine(
                                                        id,
                                                        chosen,
                                                      );
                                                    }
                                                  },
                                                  child: Text(
                                                    careIntervalLabel(
                                                      s,
                                                      interval,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                              ],
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed:
                                    reviewing ||
                                        photoLocked ||
                                        state.photoFailed ||
                                        photoError != null
                                    ? null
                                    : save,
                                child: Text(s.reviewSave),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    ),
  );
}
