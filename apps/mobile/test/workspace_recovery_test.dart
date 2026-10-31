import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/workspace_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

Future<String> add(
  MemoryCollectionRepository repository,
  String name, {
  bool routine = false,
}) async {
  final draftId = repository.newId();
  final result = await repository.submit(
    SaveDraft(
      draftId: draftId,
      expectedRevision: null,
      mode: DraftMode.add,
      fields: CustomPlantFields(
        name: name,
        speciesName: 'Synthetic',
        routines: [
          if (routine)
            RoutineInput(
              kind: StandardCareKind.water,
              count: '7',
              unit: IntervalUnit.day,
              seedKind: SeedKind.unknown,
              date: repository.today.toString(),
            ),
        ],
      ),
    ),
  );
  return (await repository.confirm(
    await repository.prepare(
      SavePlant(draftId: draftId, draftRevision: result.newRevisions[draftId]!),
    ),
  )).primaryId!;
}

void main() {
  test('pagination preserves full counts and restarts when an external write stales the cursor', () async {
    final repository = MemoryCollectionRepository();
    repository.store.setProForTest(true);
    for (var i = 0; i < 55; i++) {
      await add(repository, 'Sample ${i.toString().padLeft(2, '0')}');
    }
    final workspace = WorkspaceCubit(repository);
    await workspace.refresh();
    expect(workspace.state.read!.plants.activeCount, 55);
    expect(workspace.plantRows.length, 50);
    await workspace.loadMore();
    expect(workspace.plantRows.length, 55);
    expect(workspace.plantRows.map((r) => r.plant.id).toSet().length, 55);
    expect(workspace.plantCursor, isNull);
    await workspace.refresh();
    final plant = workspace.plantRows.first.plant;
    await repository.confirm(
      await repository.prepare(
        ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
      ),
    );
    await workspace.loadMore();
    expect(workspace.state.errorCode, 'READ_STALE');
    expect(workspace.state.read!.plants.activeCount, 54);
    expect(workspace.plantRows.any((r) => r.plant.id == plant.id), isFalse);
    await workspace.close();
  });

  test(
    'unrelated draft writes do not revoke a still-valid care Undo',
    () async {
      final repository = MemoryCollectionRepository();
      final id = await add(repository, 'Care sample', routine: true);
      final routine = (await repository.detail(id)).routines.single;
      final workspace = WorkspaceCubit(repository);
      final result = await workspace.confirm(
        await workspace.prepare(
          CompleteCurrent(routine.target, repository.today),
        ),
      );
      expect(workspace.state.undo?.commandId, result.commandId);
      await workspace.submit(
        SaveDraft(
          draftId: repository.newId(),
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(name: 'Other draft'),
        ),
      );
      expect(workspace.state.undo?.commandId, result.commandId);
      await workspace.submit(Undo(result.commandId));
      expect(workspace.state.undo, isNull);
      expect((await repository.detail(id)).routines.single.actualCareCount, 0);
      await workspace.close();
    },
  );
}
