import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/native/draft_bridge.g.dart';
import '../../../collection/data/repositories/collection_repository.dart';
import '../../../collection/presentation/widgets/presentation_helpers.dart';
import '../../../media/presentation/widgets/photo_preview.dart';
import '../cubits/journal_editor_cubit.dart';

@RoutePage()
class JournalEditorPage extends StatefulWidget {
  final String plantId;
  final String? entryId;
  const JournalEditorPage({super.key, required this.plantId, this.entryId});
  @override
  State<JournalEditorPage> createState() => _JournalEditorPageState();
}

class _JournalEditorPageState extends State<JournalEditorPage> {
  late final JournalEditorCubit cubit;
  final note = TextEditingController(), date = TextEditingController();
  bool leaving = false, picking = false, initializedFields = false;
  String? localError;
  @override
  void initState() {
    super.initState();
    cubit = JournalEditorCubit(
      getIt<CollectionRepository>(),
      widget.plantId,
      widget.entryId,
    );
    cubit.load();
  }

  @override
  void dispose() {
    note.dispose();
    date.dispose();
    cubit.close();
    super.dispose();
  }

  Future<void> close() async {
    if (picking || cubit.state.attachmentPending) return;
    final s = strings(context);
    if (cubit.state.changed) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.discardJournal),
          content: Text(s.discardJournalExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.discard),
            ),
          ],
        ),
      );
      if (yes != true) return;
    }
    try {
      if (cubit.state.draft != null) await cubit.discard();
      if (mounted) {
        setState(() => leaving = true);
        context.router.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is DomainException ? e.code : 'UNKNOWN_OUTCOME',
        );
      }
    }
  }

  Future<void> pick(String source) async {
    setState(() {
      picking = true;
      localError = null;
    });
    try {
      await cubit.flush();
      final selection = await MediaPlatformHostApi().choosePhoto(source);
      if (selection == null || !mounted) return;
      LocalDate initial;
      try {
        initial = LocalDate.parse(cubit.state.fields!.entryDate);
      } catch (_) {
        initial = cubit.repository.today;
      }
      if (initial.compareTo(cubit.repository.today) > 0) {
        initial = cubit.repository.today;
      }
      final observed = await chooseDate(
        context,
        initial: initial,
        latest: cubit.repository.today,
        helpText: strings(context).photoObservationDate,
      );
      if (observed != null) await cubit.attach(selection, observed);
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is PlatformException
              ? e.code
              : e is DomainException
              ? e.code
              : 'UNKNOWN_OUTCOME',
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> save() async {
    try {
      final preview = await cubit.prepareSave();
      if (!mounted) return;
      final result = await reviewCommand(
        context,
        preview,
        title: strings(context).saveJournal,
        explanation: strings(context).journalSaveExplanation,
      );
      if (result != null && mounted) {
        setState(() => leaving = true);
        context.router.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => localError = e is DomainException ? e.code : 'UNKNOWN_OUTCOME',
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<JournalEditorCubit, JournalEditorState>(
    bloc: cubit,
    builder: (context, state) {
      final s = strings(context),
          fields = state.fields,
          busy =
              state.loading ||
              picking ||
              state.preparing ||
              state.attachmentPending;
      if (fields != null && !initializedFields) {
        initializedFields = true;
        note.text = fields.text;
        date.text = fields.entryDate;
      }
      final valid =
          fields != null &&
          (fields.text.trim().isNotEmpty || fields.selectedPhotoIds.isNotEmpty);
      return PopScope(
        canPop: leaving,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) close();
        },
        child: Scaffold(
          appBar: AppPageBar(
            context: context,
            leading: IconButton(
              tooltip: s.cancel,
              onPressed: busy ? null : close,
              icon: const Icon(Icons.close),
            ),
            title: Text(
              widget.entryId == null ? s.newJournalEntry : s.editJournalEntry,
            ),
            actions: [
              if (!AppLayout.largeText(context))
                TextButton(
                  onPressed:
                      valid && !busy && !state.saving && !state.attachmentFailed
                      ? save
                      : null,
                  child: Text(s.saveJournal),
                ),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: AppLayout.pagePadding,
              children: [
                AppScrollTitle(
                  title: Text(
                    widget.entryId == null
                        ? s.newJournalEntry
                        : s.editJournalEntry,
                  ),
                ),
                SizedBox(
                  height: 4,
                  child: state.loading || busy || state.saving
                      ? const LinearProgressIndicator()
                      : null,
                ),
                if (localError ?? state.errorCode case final String error) ...[
                  ErrorNotice(error),
                  if (error == 'CAMERA_DENIED')
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          await MediaPlatformHostApi().openMediaSettings();
                        } on PlatformException catch (e) {
                          if (mounted) setState(() => localError = e.code);
                        }
                      },
                      child: Text(s.openSettings),
                    ),
                  if (state.loading == false && state.draft == null)
                    OutlinedButton(onPressed: cubit.load, child: Text(s.retry)),
                  if (state.draft != null)
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          if (state.attachmentFailed) {
                            await cubit.retryAttachment();
                          } else {
                            await cubit.resolvePreparation();
                            await cubit.flush();
                          }
                          if (mounted) setState(() => localError = null);
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => localError = e is DomainException
                                  ? e.code
                                  : 'UNKNOWN_OUTCOME',
                            );
                          }
                        }
                      },
                      child: Text(s.retry),
                    ),
                ],
                if (fields != null) ...[
                  if (fields.selectedPhotoIds.isNotEmpty) ...[
                    for (final id in fields.selectedPhotoIds)
                      FigmaFormSection(
                        children: [
                          PhotoPreview(photoId: id),
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => cubit.removeAttachment(id),
                            icon: const Icon(Icons.close),
                            label: Text(s.removeAttachment),
                          ),
                        ],
                      ),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => pick('camera'),
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: Text(s.camera),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : () => pick('library'),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(s.library),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FigmaFormSection(
                    title: s.notes,
                    children: [
                      TextField(
                        key: const ValueKey('journal-note'),
                        controller: note,
                        enabled: !busy,
                        minLines: 4,
                        maxLines: 10,
                        decoration: InputDecoration(
                          labelText: s.journalNote,
                          errorText: state.errors['text'] == null
                              ? null
                              : s.journalNoteLimit,
                          filled: true,
                        ),
                        onChanged: (v) => cubit.update(text: v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const ValueKey('journal-date'),
                        controller: date,
                        enabled: !busy,
                        decoration: InputDecoration(
                          labelText: s.observationDate,
                          hintText: 'YYYY-MM-DD',
                          errorText: state.errors['entryDate'] == null
                              ? null
                              : s.invalidObservationDate,
                          suffixIcon: IconButton(
                            tooltip: s.chooseObservationDate,
                            onPressed: busy
                                ? null
                                : () async {
                                    final chosen = await chooseDate(
                                      context,
                                      initial: cubit.repository.today,
                                      latest: cubit.repository.today,
                                      helpText: s.observationDate,
                                    );
                                    if (chosen != null) {
                                      date.text = chosen.toString();
                                      cubit.update(date: date.text);
                                    }
                                  },
                            icon: const Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        onChanged: (v) => cubit.update(date: v),
                      ),
                      const SizedBox(height: 16),
                      Text(s.journalHint),
                    ],
                  ),
                  if (state.attachmentFailed && fields.text.trim().isNotEmpty)
                    OutlinedButton(
                      onPressed: () async {
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(s.saveNoteOnly),
                            content: Text(s.saveNoteOnlyExplanation),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(s.cancel),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: Text(s.continueAction),
                              ),
                            ],
                          ),
                        );
                        if (yes == true) cubit.saveNoteOnly();
                      },
                      child: Text(s.saveNoteOnly),
                    ),
                  if (localError == 'DRAFT_CONFLICT' ||
                      state.errorCode == 'DRAFT_CONFLICT')
                    OutlinedButton(
                      onPressed: () async {
                        try {
                          final current = await cubit.currentDraft();
                          if (!context.mounted) return;
                          if (current == null) {
                            setState(() => localError = 'NOT_ELIGIBLE');
                            return;
                          }
                          final keep = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(s.reviewJournalConflict),
                              content: Text(s.journalDraftConflictExplanation),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(s.cancel),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: Text(s.continueAction),
                                ),
                              ],
                            ),
                          );
                          if (keep != true) return;
                          await cubit.keepFieldsAfterReview(current);
                          if (widget.entryId == null) {
                            if (mounted) setState(() => localError = null);
                            return;
                          }
                          final preview = await cubit.prepareRebase();
                          if (!context.mounted) return;
                          final result = await reviewCommand(
                            context,
                            preview,
                            title: s.reviewJournalConflict,
                            explanation: s.rebaseJournalExplanation,
                          );
                          if (result != null) {
                            await cubit.reloadAcknowledged();
                            if (mounted) setState(() => localError = null);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(
                              () => localError = e is DomainException
                                  ? e.code
                                  : 'UNKNOWN_OUTCOME',
                            );
                          }
                        }
                      },
                      child: Text(s.reviewJournalConflict),
                    ),
                  const SizedBox(height: 24),
                  if (AppLayout.largeText(context))
                    FilledButton(
                      onPressed:
                          valid &&
                              !busy &&
                              !state.saving &&
                              !state.attachmentFailed
                          ? save
                          : null,
                      child: Text(s.saveJournal),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
