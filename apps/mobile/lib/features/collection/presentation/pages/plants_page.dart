import '../../../media/presentation/widgets/photo_preview.dart';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/router/app_router.dart';
import '../cubits/workspace_cubit.dart';
import '../widgets/presentation_helpers.dart';

@RoutePage()
class PlantsPage extends StatelessWidget {
  const PlantsPage({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<WorkspaceCubit, WorkspaceState>(
    builder: (context, state) {
      final s = strings(context);
      final cubit = context.read<WorkspaceCubit>();
      final page = state.read?.plants;
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
                  icon: const Icon(Icons.add),
                  label: Text(s.addPlant),
                ),
              ),
              TextField(
                decoration: InputDecoration(
                  labelText: s.searchPlants,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (query) => cubit.refresh(query: query),
              ),
              const SizedBox(height: 12),
              Wrap(
                runSpacing: 8,
                spacing: 8,
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
                ],
              ),
              if (state.loading) const LinearProgressIndicator(),
              if (state.errorCode != null) ErrorNotice(state.errorCode!),
              const SizedBox(height: 16),
              if (page != null && page.page.items.isEmpty && !state.loading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Text(s.noMatches, textAlign: TextAlign.center),
                ),
              for (final row in cubit.plantRows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: row.coverPhotoId != null
                          ? SizedBox(
                              width: 48,
                              child: PhotoPreview(
                                photoId: row.coverPhotoId!,
                                revision: row.coverPhotoRevision!,
                                height: 64,
                              ),
                            )
                          : ExcludeSemantics(
                              child: Container(
                                width: 48,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.spa_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                      title: Text(
                        row.plant.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        '${row.plant.speciesName}${row.nextCheckDate == null ? '' : '\n${s.dueOn(dateLabel(context, row.nextCheckDate!))}'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.router.push(
                        PlantDetailRoute(plantId: row.plant.id),
                      ),
                    ),
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
