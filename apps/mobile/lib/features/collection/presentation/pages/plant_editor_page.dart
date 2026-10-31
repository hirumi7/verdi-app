import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../cubits/plant_editor_cubit.dart';
import '../widgets/presentation_helpers.dart';
import '../widgets/routine_fields_editor.dart';

@RoutePage()
class PlantEditorPage extends StatefulWidget {
  final String? plantId;
  const PlantEditorPage({super.key, this.plantId});
  @override
  State<PlantEditorPage> createState() => _PlantEditorPageState();
}

class _PlantEditorPageState extends State<PlantEditorPage>
    with WidgetsBindingObserver {
  late final PlantEditorCubit editor;
  bool reviewing = false;
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
    for (final kind in StandardCareKind.values)
      for (final field in ['count', 'seed', 'date'])
        '${kind.name}-$field': GlobalKey(),
  };
  final routineFocus = {
    for (final kind in StandardCareKind.values)
      for (final field in ['count', 'seed', 'date'])
        '${kind.name}-$field': FocusNode(),
  };

  @override
  void initState() {
    super.initState();
    editor = getIt<PlantEditorCubit>()..load(widget.plantId);
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
    if (reviewing) return;
    final s = strings(context);
    if (!editor.state.dirty) {
      await context.router.maybePop();
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
                  '${kindLabel(s, r.careKind)} · ${s.routineEvery(r.routine.interval.count, unitLabel(s, r.routine.interval.unit))} · ${s.nextAfter(dateLabel(context, r.routine.nextCheck))}',
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

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: editor,
    child: BlocBuilder<PlantEditorCubit, PlantEditorState>(
      builder: (context, state) {
        final s = strings(context);
        final f = state.fields;
        return PopScope(
          canPop: leaving || (!state.dirty && !reviewing),
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) back();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                onPressed: back,
                tooltip: s.cancel,
                icon: const Icon(Icons.arrow_back),
              ),
              title: Text(widget.plantId == null ? s.addPlant : s.editPlant),
            ),
            body: state.loading
                ? const Center(child: CircularProgressIndicator())
                : f == null
                ? Center(
                    child: ErrorNotice(
                      state.errorCode ?? 'STORAGE_UNAVAILABLE',
                    ),
                  )
                : SingleChildScrollView(
                    key: const ValueKey('plant-editor-scroll'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                        TextFormField(
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
                        TextFormField(
                          key: fieldKeys['speciesName'],
                          focusNode: fieldFocus['speciesName'],
                          initialValue: f.speciesName,
                          decoration: InputDecoration(
                            labelText: s.species,
                            errorText:
                                state.errors.containsKey('customSpeciesName')
                                ? s.fieldInvalid
                                : null,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (v) => editor.update(species: v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          key: fieldKeys['location'],
                          focusNode: fieldFocus['location'],
                          initialValue: f.location,
                          decoration: InputDecoration(
                            labelText: s.location,
                            errorText: state.errors.containsKey('location')
                                ? s.fieldInvalid
                                : null,
                          ),
                          textInputAction: TextInputAction.next,
                          onChanged: (v) => editor.update(location: v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
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
                        DropdownButtonFormField<CustomLight>(
                          initialValue: f.light,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: s.light),
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
                        DropdownButtonFormField<CustomToxicity>(
                          initialValue: f.toxicity,
                          isExpanded: true,
                          decoration: InputDecoration(labelText: s.toxicity),
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
                            errors: state.errors,
                            onChanged: (routines) =>
                                editor.update(routines: routines),
                          ),
                        if (widget.plantId != null &&
                            f.keepRoutineIds.isNotEmpty)
                          Text(s.keepCurrentSchedules),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: reviewing ? null : save,
                          child: Text(s.reviewSave),
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
