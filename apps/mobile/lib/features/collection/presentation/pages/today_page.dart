import '../../../reminders/presentation/reminder_page.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/router/app_router.dart';
import '../cubits/workspace_cubit.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  bool selecting = false;
  StandardCareKind? selectedKind;
  String? selectedCustomTypeId;
  final selected = <String, CareTarget>{};
  String? error;
  AddPastCare? historyAlternative;
  LocalDate? selectedDate;
  Set<String> affected = {};
  final selectedNames = <String, String>{};

  Future<void> perform(CoreCommand command, String label) async {
    setState(() {
      error = null;
      affected = {};
      historyAlternative = null;
    });
    try {
      final preview = await context.read<WorkspaceCubit>().prepare(command);
      if (!mounted) return;
      final result = await reviewCommand(context, preview, title: label);
      if (result != null && mounted) {
        setState(() {
          selected.clear();
          selectedNames.clear();
          selecting = false;
          selectedKind = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = WorkspaceCubit.code(e);
          affected = e is CommandRejected ? e.fields.keys.toSet() : {};
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

  Future<void> careAction(String value, CheckRow row) async {
    final s = strings(context), cubit = context.read<WorkspaceCubit>();
    if (value == 'complete') {
      final date = await chooseDate(
        context,
        initial: cubit.today,
        latest: cubit.today,
        helpText: s.actualCareDate,
      );
      if (date != null && mounted) {
        await perform(
          CompleteCurrent(row.target, date),
          kindLabel(s, row.careKind, actual: true, customLabel: row.careLabel),
        );
      }
    } else if (value == 'check') {
      final checked = await chooseDate(
        context,
        latest: cubit.today,
        helpText: s.checkDate,
      );
      if (checked == null || !mounted) return;
      final next = await chooseDate(context, helpText: s.nextCheckDate);
      if (next != null && mounted) {
        await perform(
          CheckNotNeeded(row.target, checked, next),
          s.checkedNotNeeded,
        );
      }
    } else if (value == 'skip') {
      await perform(Skip(row.target), s.skipCheck);
    } else {
      final next = await chooseDate(
        context,
        earliest: cubit.today,
        helpText: s.nextCheckDate,
        initial: row.date.compareTo(cubit.today) < 0 ? cubit.today : row.date,
      );
      if (next != null && mounted) {
        await perform(Snooze(row.target, next), s.moveCheck);
      }
    }
  }

  Widget check(CheckRow row, WorkspaceState state) {
    final s = strings(context);
    final compatible =
        selectedKind == null ||
        (selectedKind == row.careKind &&
            selectedCustomTypeId == row.customTypeId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (selecting)
            Checkbox(
              value: selected.containsKey(row.routineId),
              semanticLabel: s.plantNamed(
                row.plantName,
                kindLabel(s, row.careKind, customLabel: row.careLabel),
              ),
              onChanged: !compatible || state.busy
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        selected[row.routineId] = row.target;
                        selectedNames[row.routineId] = row.plantName;
                        selectedKind = row.careKind;
                        selectedCustomTypeId = row.customTypeId;
                      } else {
                        selected.remove(row.routineId);
                        selectedNames.remove(row.routineId);
                        if (selected.isEmpty) selectedKind = null;
                      }
                    }),
            ),
          if (!AppLayout.largeText(context)) ...[
            SizedBox(
              width: 48,
              child: PlantVisual(
                height: 48,
                radius: 10,
                speciesId: row.speciesId,
                photoId: row.coverPhotoId,
                photoRevision: row.coverPhotoRevision ?? 1,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextButton(
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
              ),
              onPressed: () => context.router.push(
                PlantDetailRoute(plantId: row.target.plantId),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.plantName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${kindLabel(s, row.careKind, customLabel: row.careLabel)} · ${row.overdueDays > 0 ? s.lateDays(row.overdueDays) : s.dueOn(dateLabel(context, row.date))}',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: row.overdueDays > 0
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!selecting)
            PopupMenuButton<String>(
              tooltip: s.moreActions,
              enabled: !state.busy,
              icon: Icon(
                Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.outline,
              ),
              onSelected: (value) => careAction(value, row),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'complete',
                  child: Text(
                    kindLabel(
                      s,
                      row.careKind,
                      actual: true,
                      customLabel: row.careLabel,
                    ),
                  ),
                ),
                PopupMenuItem(value: 'check', child: Text(s.checkedNotNeeded)),
                PopupMenuItem(value: 'move', child: Text(s.moveCheck)),
                PopupMenuItem(value: 'skip', child: Text(s.skipCheck)),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
    builder: (context, state) {
      final s = strings(context);
      final cubit = context.read<WorkspaceCubit>();
      final read = state.read;
      final summary = read?.today[TodaySection.today]?.summary;
      final dueCount =
          (read?.today[TodaySection.today]?.counts[TodaySection.today] ?? 0) +
          (read?.today[TodaySection.overdue]?.counts[TodaySection.overdue] ??
              0);
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: cubit.refresh,
          child: ListView(
            padding: AppLayout.pagePadding,
            children: [
              AppPageHeader(
                title: s.today,
                subtitle: dateLabel(context, cubit.today),
              ),
              if (summary != null && summary.activePlantCount > 0)
                FigmaWeek(today: cubit.today),
              const ReminderTodayCard(),
              if (state.loading) const LinearProgressIndicator(),
              if (error != null || state.errorCode != null)
                ErrorNotice(error ?? state.errorCode!),
              for (final id in affected)
                Text(s.affectedPlant(selectedNames[id] ?? id)),
              if (historyAlternative != null)
                OutlinedButton(
                  onPressed: () => perform(historyAlternative!, s.addPastCare),
                  child: Text(s.addPastCare),
                ),
              if (summary != null && summary.activePlantCount == 0) ...[
                const SizedBox(height: 40),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ExcludeSemantics(
                    child: Image.asset(
                      'assets/illustrations/empty-plants.png',
                      fit: BoxFit.fitWidth,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  s.noPlants,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(s.noPlantsBody, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                Center(
                  child: FilledButton.icon(
                    onPressed: () => context.router.push(PlantEditorRoute()),
                    icon: const Icon(Icons.add),
                    label: Text(s.addPlant),
                  ),
                ),
              ] else if (summary != null) ...[
                if (dueCount > 0) ...[
                  Text(
                    s.checksDueSummary(dueCount),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.checksDueBody,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (dueCount == 0) ...[
                  Text(
                    s.noChecksDue,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.nextCheck == null
                        ? s.noRoutines
                        : s.nextForPlant(
                            summary.nextCheck!.plantName,
                            dateLabel(context, summary.nextCheck!.date),
                          ),
                  ),
                ],
                TextButton(
                  onPressed: () => setState(() {
                    selecting = !selecting;
                    selectedDate = cubit.today;
                    selected.clear();
                    selectedNames.clear();
                    selectedKind = null;
                  }),
                  child: Text(selecting ? s.cancel : s.selectCare),
                ),
                if (selecting) ...[
                  Text(s.selectionCount(selected.length)),
                  TextButton(
                    onPressed: () async {
                      final date = await chooseDate(
                        context,
                        initial: selectedDate,
                        latest: cubit.today,
                        helpText: s.actualCareDate,
                      );
                      if (date != null && mounted) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Text(
                      '${s.actualCareDate}: ${dateLabel(context, selectedDate ?? cubit.today)}',
                    ),
                  ),
                  FilledButton(
                    onPressed: selected.isEmpty || state.busy
                        ? null
                        : () => perform(
                            BulkComplete(
                              careKind: selectedKind!,
                              customTypeId: selectedCustomTypeId,
                              careDate: selectedDate ?? cubit.today,
                              targets: selected.values,
                            ),
                            selectedKind == StandardCareKind.water
                                ? s.markSelectedWatered
                                : kindLabel(s, selectedKind!, actual: true),
                          ),
                    child: Text(
                      selectedKind == StandardCareKind.water
                          ? s.markSelectedWatered
                          : s.confirmCare,
                    ),
                  ),
                ],
                for (final section in [
                  TodaySection.overdue,
                  TodaySection.today,
                ])
                  if (read!.today[section]!.page.items.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppLayout.section,
                        bottom: 12,
                      ),
                      child: Text(
                        section == TodaySection.overdue
                            ? s.overdue
                            : s.dueToday,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FigmaGroup(
                      children: [
                        for (final row
                            in cubit.todayRows(section).cast<CheckRow>())
                          check(row, state),
                      ],
                    ),
                    if (cubit.todayCursor(section) != null)
                      OutlinedButton(
                        onPressed: state.loadingMore
                            ? null
                            : () => cubit.loadMore(section: section),
                        child: Text(s.loadMore),
                      ),
                  ],
                if (read!.today[TodaySection.upcoming]!.page.items.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(s.upcoming),
                    children: [
                      FigmaGroup(
                        children: [
                          for (final row
                              in cubit
                                  .todayRows(TodaySection.upcoming)
                                  .cast<CheckRow>())
                            check(row, state),
                        ],
                      ),
                      if (cubit.todayCursor(TodaySection.upcoming) != null)
                        OutlinedButton(
                          onPressed: state.loadingMore
                              ? null
                              : () => cubit.loadMore(
                                  section: TodaySection.upcoming,
                                ),
                          child: Text(s.loadMore),
                        ),
                    ],
                  ),
                if (read
                    .today[TodaySection.doneToday]!
                    .page
                    .items
                    .isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      s.doneToday,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  for (final row
                      in cubit
                          .todayRows(TodaySection.doneToday)
                          .cast<DoneTodayRow>())
                    ListTile(
                      title: Text(row.plantName),
                      subtitle: Text(
                        kindLabel(
                          s,
                          row.careKind,
                          actual: true,
                          customLabel: row.careLabel,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.router.push(
                        PlantDetailRoute(plantId: row.care.plantId),
                      ),
                    ),
                ],
              ],
              if (cubit.todayCursor(TodaySection.doneToday) != null)
                OutlinedButton(
                  onPressed: state.loadingMore
                      ? null
                      : () => cubit.loadMore(section: TodaySection.doneToday),
                  child: Text(s.loadMore),
                ),
              if (state.undo != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Card(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    child: Padding(
                      padding: AppLayout.cardPadding,
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            s.careSaved,
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onInverseSurface,
                            ),
                          ),
                          TextButton(
                            onPressed: state.busy
                                ? null
                                : () async {
                                    try {
                                      await cubit.submit(
                                        Undo(state.undo!.commandId),
                                      );
                                    } catch (e) {
                                      if (mounted) {
                                        setState(
                                          () => error = WorkspaceCubit.code(e),
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              s.undo,
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .inversePrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
}
