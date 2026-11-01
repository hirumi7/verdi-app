import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:verdi_core/verdi_core.dart';

import '../../../../core/router/app_router.dart';
import '../cubits/workspace_cubit.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class PlantsPage extends StatefulWidget {
  const PlantsPage({super.key});
  @override
  State<PlantsPage> createState() => _PlantsPageState();
}

class _PlantsPageState extends State<PlantsPage> {
  bool grid = true;
  Widget plant(PlantRow row, {required bool portrait}) {
    final s = strings(context), theme = Theme.of(context);
    final date = row.nextCheckDate;
    final late =
        date != null &&
        date.compareTo(context.read<WorkspaceCubit>().today) < 0;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(row.plant.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          row.plant.speciesName,
          style: theme.textTheme.bodySmall!.copyWith(
            fontStyle: FontStyle.italic,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: 4),
          Text(
            s.dueOn(dateLabel(context, date)),
            style: theme.textTheme.labelMedium!.copyWith(
              color: late ? theme.colorScheme.error : theme.colorScheme.primary,
            ),
          ),
        ],
      ],
    );
    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () =>
            context.router.push(PlantDetailRoute(plantId: row.plant.id)),
        child: portrait
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => PlantVisual(
                      speciesId: row.plant.catalogSelection?.speciesId,
                      photoId: row.coverPhotoId,
                      photoRevision: row.coverPhotoRevision ?? 1,
                      height: c.maxWidth * 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  details,
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      child: PlantVisual(
                        speciesId: row.plant.catalogSelection?.speciesId,
                        photoId: row.coverPhotoId,
                        photoRevision: row.coverPhotoRevision ?? 1,
                        height: 80,
                        radius: 10,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: details),
                    const SizedBox(width: 8),
                    const FigmaIcon('chevron', size: 14),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<WorkspaceCubit, WorkspaceState>(
        builder: (context, state) {
          final s = strings(context),
              cubit = context.read<WorkspaceCubit>(),
              page = state.read?.plants;
          final rows = cubit.plantRows;
          final two =
              grid &&
              MediaQuery.sizeOf(context).width - 32 >= 320 &&
              !AppLayout.largeText(context);
          return Scaffold(
            body: RefreshIndicator(
              onRefresh: cubit.refresh,
              child: ListView(
                padding: AppLayout.pagePadding,
                children: [
                  AppPageHeader(
                    title: s.plants,
                    subtitle: page?.activeCount == null
                        ? null
                        : s.plantCount(page!.activeCount!),
                    action: FilledButton.tonalIcon(
                      onPressed: () => context.router.push(PlantEditorRoute()),
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      icon: const Icon(Icons.add),
                      label: Text(s.addPlant),
                    ),
                  ),
                  TextField(
                    decoration: InputDecoration(
                      hintText: s.searchPlants,
                      prefixIcon: const Icon(Icons.search),
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    onChanged: (q) => cubit.refresh(query: q),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ChoiceChip(
                        label: Text(s.active),
                        selected: !state.archived,
                        onSelected: (_) => cubit.refresh(archived: false),
                      ),
                      ChoiceChip(
                        label: Text(s.archived),
                        selected: state.archived,
                        onSelected: (_) => cubit.refresh(archived: true),
                      ),
                      IconButton(
                        tooltip: grid ? s.listView : s.gridView,
                        onPressed: () => setState(() => grid = !grid),
                        icon: Icon(
                          grid
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (state.loading) const LinearProgressIndicator(),
                  if (state.errorCode != null) ErrorNotice(state.errorCode!),
                  const SizedBox(height: 24),
                  if (page != null && rows.isEmpty && !state.loading)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(s.noMatches, textAlign: TextAlign.center),
                    ),
                  if (!two)
                    for (final row in rows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: plant(row, portrait: grid),
                      )
                  else
                    for (var i = 0; i < rows.length; i += 2)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: plant(rows[i], portrait: true)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: i + 1 < rows.length
                                  ? plant(rows[i + 1], portrait: true)
                                  : const SizedBox(),
                            ),
                          ],
                        ),
                      ),
                  if (cubit.plantCursor != null)
                    OutlinedButton(
                      onPressed: state.loadingMore ? null : cubit.loadMore,
                      child: Text(s.loadMore),
                    ),
                ],
              ),
            ),
          );
        },
      );
}
