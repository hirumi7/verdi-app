import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

class InterleavedRepository extends MemoryCollectionRepository {
  bool interleave = false;
  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    final result = await super.submit(command);
    if (interleave && command is SaveDraft) {
      interleave = false;
      await super.submit(
        SaveDraft(
          draftId: command.draftId,
          expectedRevision: result.newRevisions[command.draftId],
          mode: command.mode,
          plantId: command.plantId,
          basePlantRevision: command.basePlantRevision,
          fields: CustomPlantFields(
            name: 'Other writer',
            speciesName: 'Synthetic',
          ),
        ),
      );
    }
    return result;
  }
}

void main() {
  test(
    'consumed acknowledged draft without newer keystrokes must be dismissible',
    () async {
      final r = MemoryCollectionRepository();
      final a = PlantEditorCubit(r);
      await a.load(null);
      a.update(name: 'Original', species: 'Synthetic');
      await a.flush();
      final b = PlantEditorCubit(r);
      await b.load(null);
      await r.confirm(await a.preview());
      await b.discard();
      expect(b.state.dirty, isFalse);
      await a.close();
      await b.close();
    },
  );
  test(
    'replaced draft survives local discard of previous acknowledged draft',
    () async {
      final r = MemoryCollectionRepository();
      final a = PlantEditorCubit(r);
      await a.load(null);
      a.update(name: 'Saved plant', species: 'Synthetic');
      await a.flush();
      final b = PlantEditorCubit(r);
      await b.load(null);
      final saved = await r.confirm(await a.preview());
      final c = PlantEditorCubit(r);
      await c.load(null);
      c.update(name: 'Replacement draft', species: 'Synthetic');
      await c.flush();
      b.update(notes: 'stale local text');
      await b.discard();
      expect(b.state.dirty, isFalse);
      expect((await r.editor(null)).draft!.fields.name, 'Replacement draft');
      expect((await r.detail(saved.primaryId!)).plant.name, 'Saved plant');
      await a.close();
      await b.close();
      await c.close();
    },
  );
  test('later write invalidates previously captured rebase review', () async {
    final r = MemoryCollectionRepository();
    final a = PlantEditorCubit(r);
    await a.load(null);
    a.update(name: 'Initial', species: 'Synthetic');
    await a.flush();
    final b = PlantEditorCubit(r);
    await b.load(null);
    b.update(name: 'B');
    await b.flush();
    a.update(name: 'A');
    try {
      await a.flush();
    } catch (_) {}
    final review = await a.currentForReview();
    b.update(name: 'Unreviewed newer B');
    await b.flush();
    await expectLater(
      a.keepFieldsAfterReview(review),
      throwsA(isA<CommandRejected>()),
    );
    expect((await r.editor(null)).draft!.fields.name, 'Unreviewed newer B');
    expect(a.state.fields!.name, 'A');
    final next = await a.currentForReview();
    await a.keepFieldsAfterReview(next);
    expect((await r.editor(null)).draft!.fields.name, 'A');
    await a.close();
    await b.close();
  });
  test(
    'intervening read-back revision must require review before overwriting',
    () async {
      final r = InterleavedRepository();
      final a = PlantEditorCubit(r);
      await a.load(null);
      a.update(name: 'Initial', species: 'Synthetic');
      await a.flush();
      r.interleave = true;
      a.update(name: 'Local editor');
      try {
        await a.flush();
      } catch (_) {}
      expect((await r.editor(null)).draft!.fields.name, 'Other writer');
      a.update(notes: 'new local note');
      try {
        await a.flush();
      } catch (_) {}
      expect((await r.editor(null)).draft!.fields.name, 'Other writer');
      await a.close();
    },
  );
}
