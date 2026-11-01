import '../../../cards/presentation/card_page.dart';
import 'custom_care_page.dart';
import '../../../../core/di/injection.dart';
import '../../data/repositories/collection_repository.dart';
import '../../../catalog/presentation/widgets/species_picker.dart';
import '../../../media/presentation/widgets/photo_preview.dart';

import 'package:intl/intl.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/router/app_router.dart';
import '../cubits/workspace_cubit.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class PlantDetailPage extends StatefulWidget {
  final String plantId;
  const PlantDetailPage({super.key, required this.plantId});
  @override
  State<PlantDetailPage> createState() => _PlantDetailPageState();
}

class _PlantDetailPageState extends State<PlantDetailPage> {
  PlantDetail? detail;
  ReadPage<TimelineEntry>? timeline;
  List<TimelineEntry> entries = [];
  bool loadingMore = false;
  String? coverId;
  Map<String, int> photoRevisions = {};
  int coverRevision = 1;
  bool includeVoided = false;
  bool loading = true;
  String? error;
  AddPastCare? historyAlternative;
  int sequence = 0;
  int detailSection = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final token = ++sequence;
    setState(() => loading = true);
    try {
      final cubit = context.read<WorkspaceCubit>();
      final next = await cubit.detail(widget.plantId);
      final media = await getIt<CollectionRepository>().mediaSnapshot();
      final history = await cubit.timeline(
        widget.plantId,
        includeVoided: includeVoided,
      );
      if (mounted && token == sequence) {
        setState(() {
          detail = next;
          photoRevisions = {
            for (final photo in media.photos.values) photo.id: photo.revision,
          };
          coverId = media.covers[widget.plantId];
          coverRevision = media.photos[coverId]?.revision ?? 1;
          timeline = history;
          entries = history.items;
          loading = false;
          error = null;
        });
      }
    } catch (e) {
      if (mounted && token == sequence) {
        setState(() {
          error = WorkspaceCubit.code(e);
          loading = false;
        });
      }
    }
  }

  Future<void> moreHistory() async {
    final cursor = timeline?.nextCursor;
    if (cursor == null || loadingMore || loading) return;
    final token = sequence;
    setState(() => loadingMore = true);
    try {
      final page = await context.read<WorkspaceCubit>().timeline(
        widget.plantId,
        includeVoided: includeVoided,
        cursor: cursor,
      );
      if (mounted && token == sequence) {
        setState(() {
          entries = [...entries, ...page.items];
          timeline = page;
        });
      }
    } catch (e) {
      if (mounted && token == sequence) {
        if (e is DomainException && e.code == 'READ_STALE') await load();
        if (mounted) {
          setState(() {
            error = WorkspaceCubit.code(e);
          });
        }
      }
    } finally {
      if (mounted) setState(() => loadingMore = false);
    }
  }

  Future<void> editInterval(RoutineRead routine) async {
    final interval = await chooseInterval(context, routine.routine.interval);
    if (interval == null || !mounted) return;
    await perform(
      SetInterval(routine.target, interval),
      strings(context).editInterval,
    );
  }

  Future<void> perform(
    CoreCommand command,
    String label, {
    String? explanation,
  }) async {
    setState(() {
      historyAlternative = null;
      error = null;
    });
    try {
      final preview = await context.read<WorkspaceCubit>().prepare(command);
      if (!mounted) return;
      final result = await reviewCommand(
        context,
        preview,
        title: label,
        explanation: explanation,
      );
      if (result == null || !mounted) return;
      if (command is DeletePlant || command is ArchivePlant) {
        final tabs = AutoTabsRouter.of(context);
        await context.read<WorkspaceCubit>().refresh(
          archived: command is DeletePlant,
          query: '',
        );
        if (!mounted) return;
        context.router.popUntilRoot();
        tabs.setActiveIndex(1);
        tabs.innerRouterOf<StackRouter>(PlantsTabRoute.name)?.popUntilRoot();
        return;
      }
      await load();
    } catch (e) {
      if (mounted) {
        setState(() {
          error = WorkspaceCubit.code(e);
          if (e is DomainException &&
              e.code == 'CARE_PRECEDES_LATEST' &&
              command is CompleteCurrent) {
            historyAlternative = AddPastCare(
              command.target,
              command.careDate,
              CareOutcome.actualCare,
            );
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = strings(context);
    final cubit = context.read<WorkspaceCubit>();
    final d = detail;
    return Scaffold(
      appBar: AppLayout.largeText(context) || d == null
          ? AppPageBar(
              context: context,
              title: Text(s.plants),
              actions: [
                if (d != null)
                  IconButton(
                    tooltip: s.editPlant,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      await context.router.push(
                        PlantEditorRoute(plantId: widget.plantId),
                      );
                      if (mounted) load();
                    },
                  ),
              ],
            )
          : null,
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: AppLayout.pagePadding,
          children: [
            if (d == null) AppScrollTitle(title: Text(s.plants)),
            if (loading) const LinearProgressIndicator(),
            if (error != null) ErrorNotice(error!),
            if (historyAlternative != null)
              OutlinedButton(
                onPressed: () => perform(historyAlternative!, s.addPastCare),
                child: Text(s.addPastCare),
              ),
            if (d != null) ...[
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: PlantVisual(
                      speciesId: d.plant.catalogSelection?.speciesId,
                      photoId: coverId,
                      photoRevision: coverRevision,
                      height: AppLayout.largeText(context) ? 120 : 220,
                    ),
                  ),
                  if (!AppLayout.largeText(context)) ...[
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        child: BackButton(
                          onPressed: () => context.router.maybePop(),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: s.editPlant,
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () async {
                            await context.router.push(
                              PlantEditorRoute(plantId: widget.plantId),
                            );
                            if (mounted) load();
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              AppPageHeader(
                title: d.plant.name,
                bottomGap: 4,
                titleStyle: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                d.plant.speciesName,
                style: Theme.of(context).textTheme.bodySmall!
                    .copyWith(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              FigmaSegments(
                labels: [s.careTab, s.historyTab, s.statsTab],
                selected: detailSection,
                onSelected: (value) => setState(() => detailSection = value),
              ),
              const SizedBox(height: 12),
              if (detailSection == 2) ...[
                Text(
                  s.statsCareCount,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${d.routines.fold<int>(0, (total, r) => total + r.actualCareCount)}',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                Text(
                  s.statsExplanation,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                for (final routine in d.routines)
                  if (routine.latestActualCare != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${kindLabel(s, routine.careKind, customLabel: routine.routine.careLabel)} · ${s.lastCare}: ${dateLabel(context, routine.latestActualCare!)}',
                      ),
                    ),
                const SizedBox(height: 24),
                Text(
                  d.plant.catalogSelection == null
                      ? s.customIdentity
                      : s.catalogIdentity,
                ),
                if (d.plant.catalogSelection case final selection?)
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline),
                    label: Text(s.speciesInformation),
                    onPressed: () async {
                      try {
                        final catalog = await getIt<CollectionRepository>()
                            .catalog();
                        if (!context.mounted) return;
                        final entry = catalog.entry(selection.speciesId);
                        if (entry != null) {
                          await showSpeciesInformation(
                            context,
                            entry,
                            manifest: catalog.manifest,
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.catalogLimited)),
                          );
                        }
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.catalogLimited)),
                          );
                        }
                      }
                    },
                  ),
                if (d.plant.location.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(d.plant.location),
                  ),
                if (d.plant.notes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(d.plant.notes),
                  ),
                if (d.plant.archived) Chip(label: Text(s.archived)),
              ],
              if (detailSection == 0) ...[
                for (final r in d.routines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                FigmaIconTile(
                                  r.careKind == StandardCareKind.water
                                      ? 'water'
                                      : 'plants',
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    kindLabel(
                                      s,
                                      r.careKind,
                                      customLabel: r.routine.careLabel,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              r.routine.status == RoutineStatus.retired
                                  ? s.retired
                                  : r.routine.status == RoutineStatus.paused
                                  ? s.paused
                                  : s.nextAfter(
                                      dateLabel(context, r.routine.nextCheck),
                                    ),
                            ),
                            Text(
                              careIntervalLabel(s, r.routine.interval),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            for (final pair in [
                              (
                                s.originalSuggestion,
                                r.routine.originalSuggestionId,
                              ),
                              (
                                s.appliedSuggestion,
                                r.routine.appliedSuggestionId,
                              ),
                            ])
                              if (d.suggestions[pair.$2] case final snapshot?)
                                ExpansionTile(
                                  title: Text(pair.$1),
                                  children: [
                                    Text(
                                      careIntervalLabel(
                                        s,
                                        snapshot.suggestion.interval,
                                      ),
                                    ),
                                    Text(snapshot.suggestion.context),
                                    Text(snapshot.suggestion.sourceLabel),
                                  ],
                                ),
                            if (r.latestActualCare != null)
                              Text(
                                '${s.lastCare}: ${dateLabel(context, r.latestActualCare!)}',
                              ),
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: Text(s.moreActions),
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (r.canEditSchedule)
                                      TextButton(
                                        onPressed: () => editInterval(r),
                                        child: Text(s.editInterval),
                                      ),
                                    if (r.canEditSchedule &&
                                        r.routine.overrideDate != null)
                                      TextButton(
                                        onPressed: () async {
                                          final first =
                                              r.latestActualCare == null
                                              ? await chooseDate(
                                                  context,
                                                  helpText: s.firstCheck,
                                                )
                                              : null;
                                          if (!mounted ||
                                              (r.latestActualCare == null &&
                                                  first == null)) {
                                            return;
                                          }
                                          await perform(
                                            ClearOverride(
                                              r.target,
                                              firstCheckDate: first,
                                            ),
                                            s.clearOverride,
                                          );
                                        },
                                        child: Text(s.clearOverride),
                                      ),
                                    if (r.canComplete)
                                      TextButton(
                                        onPressed: () async {
                                          final date = await chooseDate(
                                            context,
                                            latest: cubit.today,
                                            helpText: s.actualCareDate,
                                          );
                                          if (date != null && mounted) {
                                            await perform(
                                              CompleteCurrent(r.target, date),
                                              kindLabel(
                                                s,
                                                r.careKind,
                                                actual: true,
                                                customLabel:
                                                    r.routine.careLabel,
                                              ),
                                            );
                                          }
                                        },
                                        child: Text(
                                          kindLabel(
                                            s,
                                            r.careKind,
                                            actual: true,
                                            customLabel: r.routine.careLabel,
                                          ),
                                        ),
                                      ),
                                    if (r.canComplete)
                                      TextButton(
                                        onPressed: () => perform(
                                          PauseRoutine(r.target),
                                          s.pause,
                                        ),
                                        child: Text(s.pause),
                                      ),
                                    if (r.routine.status ==
                                            RoutineStatus.paused &&
                                        !d.plant.archived)
                                      TextButton(
                                        onPressed: () => perform(
                                          ResumeRoutine(r.target),
                                          s.resume,
                                        ),
                                        child: Text(s.resume),
                                      ),
                                    TextButton(
                                      onPressed: () async {
                                        final date = await chooseDate(
                                          context,
                                          latest: cubit.today,
                                        );
                                        if (date != null && context.mounted) {
                                          final outcome = await chooseOutcome(
                                            context,
                                            r.careKind,
                                          );
                                          if (outcome == null || !mounted) {
                                            return;
                                          }
                                          perform(
                                            AddPastCare(
                                              r.target,
                                              date,
                                              outcome,
                                            ),
                                            s.addPastCare,
                                          );
                                        }
                                      },
                                      child: Text(s.addPastCare),
                                    ),
                                    if (r.canEditSchedule)
                                      TextButton(
                                        onPressed: () => perform(
                                          RetireRoutine(r.target),
                                          s.retire,
                                          explanation: s.retired,
                                        ),
                                        child: Text(s.retire),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              if (detailSection == 1) ...[
                const SizedBox(height: 16),
                Text(s.history, style: Theme.of(context).textTheme.titleLarge),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(s.audit),
                  value: includeVoided,
                  onChanged: (v) {
                    setState(() => includeVoided = v);
                    load();
                  },
                ),
                if (entries.isEmpty) Text(s.historyEmpty),
                for (final (index, entry) in entries.indexed) ...[
                  if (index == 0 ||
                      entries[index - 1].date.year != entry.date.year ||
                      entries[index - 1].date.month != entry.date.month)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        DateFormat.yMMMM().format(
                          DateTime(entry.date.year, entry.date.month),
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: entry is JournalTimelineEntry
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateLabel(context, entry.date)),
                                if (entry.entry.text.isNotEmpty)
                                  Text(entry.entry.text),
                                for (final id in entry.entry.photoIds)
                                  InkWell(
                                    onTap: () async {
                                      await context.router.push(
                                        PhotosRoute(
                                          plantId: widget.plantId,
                                          photoId: id,
                                        ),
                                      );
                                      if (mounted) load();
                                    },
                                    child: PhotoPreview(
                                      photoId: id,
                                      revision: photoRevisions[id] ?? 1,
                                    ),
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        await context.router.push(
                                          JournalEditorRoute(
                                            plantId: widget.plantId,
                                            entryId: entry.id,
                                          ),
                                        );
                                        if (mounted) load();
                                      },
                                      child: Text(s.editJournalEntry),
                                    ),
                                    TextButton(
                                      onPressed: () => perform(
                                        DeleteJournalEntry(
                                          entry.id,
                                          entry.entry.revision,
                                        ),
                                        s.deleteJournalEntry,
                                        explanation: s.deleteJournalExplanation,
                                      ),
                                      child: Text(s.deleteJournalEntry),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : entry is CareTimelineEntry
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateLabel(context, entry.date),
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  entry.event.effective.outcome ==
                                          CareOutcome.actualCare
                                      ? kindLabel(
                                          s,
                                          entry.careKind,
                                          actual: true,
                                          customLabel: entry.careLabel,
                                        )
                                      : entry.event.effective.outcome ==
                                            CareOutcome.checkedNotNeeded
                                      ? s.checkedNotNeeded
                                      : s.skipCheck,
                                ),
                                if (entry.voided) Text(s.removed),
                                if (entry.corrected) Text(s.corrected),
                                Text(
                                  s.recordedOn(
                                    entry.event.recordedAt.toIso8601String(),
                                  ),
                                ),
                                for (final correction
                                    in entry.event.corrections)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      '${dateLabel(context, correction.before.careDate)} · ${outcomeLabel(s, correction.before.outcome, entry.careKind)}${correction.before.voided ? ' · ${s.removed}' : ''}\n→ ${dateLabel(context, correction.after.careDate)} · ${outcomeLabel(s, correction.after.outcome, entry.careKind)}${correction.after.voided ? ' · ${s.removed}' : ''}\n${s.recordedOn(correction.correctedAt.toIso8601String())}',
                                    ),
                                  ),
                                Text(s.historyOnly),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        final date = await chooseDate(
                                          context,
                                          initial: entry.date,
                                          latest: cubit.today,
                                        );
                                        if (date == null || !context.mounted) {
                                          return;
                                        }
                                        final outcome = await chooseOutcome(
                                          context,
                                          entry.careKind,
                                          initial:
                                              entry.event.effective.outcome,
                                        );
                                        if (outcome == null || !mounted) return;
                                        final target = d.routines
                                            .firstWhere(
                                              (r) =>
                                                  r.routine.id ==
                                                  entry.routineId,
                                            )
                                            .target;
                                        await perform(
                                          CorrectEvent(
                                            target,
                                            eventId: entry.id,
                                            eventRevision: entry.event.revision,
                                            careDate: date,
                                            outcome: outcome,
                                            restore: entry.voided,
                                          ),
                                          entry.voided
                                              ? s.restoreCare
                                              : s.correctCare,
                                        );
                                      },
                                      child: Text(
                                        entry.voided
                                            ? s.restoreCare
                                            : s.correctCare,
                                      ),
                                    ),
                                    if (!entry.voided)
                                      TextButton(
                                        onPressed: () {
                                          final target = d.routines
                                              .firstWhere(
                                                (r) =>
                                                    r.routine.id ==
                                                    entry.routineId,
                                              )
                                              .target;
                                          perform(
                                            VoidEvent(
                                              target,
                                              eventId: entry.id,
                                              eventRevision:
                                                  entry.event.revision,
                                            ),
                                            s.removeCare,
                                          );
                                        },
                                        child: Text(s.removeCare),
                                      ),
                                  ],
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.scheduleChange,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(dateLabel(context, entry.date)),
                                Text(
                                  s.nextAfter(
                                    dateLabel(
                                      context,
                                      (entry as ScheduleTimelineEntry)
                                          .change
                                          .after
                                          .nextCheck,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
                if (timeline?.nextCursor != null)
                  OutlinedButton(
                    onPressed: loadingMore ? null : moreHistory,
                    child: Text(s.loadMore),
                  ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => openCard(context, widget.plantId),
                    icon: const Icon(Icons.ios_share),
                    label: Text(s.sharePlantCard),
                  ),
                  if (!d.plant.archived)
                    OutlinedButton.icon(
                      onPressed: () async {
                        await openAddCare(context, widget.plantId);
                        if (mounted) await load();
                      },
                      icon: const Icon(Icons.add_task),
                      label: Text(s.addCare),
                    ),
                  FilledButton.icon(
                    onPressed: () async {
                      await context.router.push(
                        JournalEditorRoute(plantId: widget.plantId),
                      );
                      if (mounted) {
                        setState(() => detailSection = 1);
                        load();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: Text(s.newJournalEntry),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.router.push(
                        PhotosRoute(plantId: widget.plantId),
                      );
                      if (mounted) load();
                    },
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(s.photos),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (!d.plant.archived)
                OutlinedButton(
                  onPressed: () => perform(
                    ArchivePlant(
                      plantId: d.plant.id,
                      plantRevision: d.plant.revision,
                    ),
                    s.archive,
                    explanation: s.archiveBody,
                  ),
                  child: Text(s.archive),
                ),
              if (d.plant.archived) ...[
                OutlinedButton(
                  onPressed: () => perform(
                    RestorePlant(
                      plantId: d.plant.id,
                      plantRevision: d.plant.revision,
                    ),
                    s.restore,
                    explanation: s.restoreBody,
                  ),
                  child: Text(s.restore),
                ),
                TextButton(
                  onPressed: () => perform(
                    DeletePlant(
                      plantId: d.plant.id,
                      plantRevision: d.plant.revision,
                    ),
                    s.deleteForever,
                    explanation: s.deleteBody,
                  ),
                  child: Text(
                    s.deleteForever,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
