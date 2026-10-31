import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real native editor retries retain command identity and later text',
    (tester) async {
      final repository = await NativeCollectionRepository.open();
      expect(await repository.pending(), isEmpty);
      final old = (await repository.editor(null)).draft;
      if (old != null) {
        expect([
          'Unfinished native draft',
          'Native retry fixture',
        ], contains(old.fields.name));
        await repository.submit(
          DiscardDraft(
            draftId: old.id,
            draftRevision: old.revision,
            confirmed: true,
          ),
        );
      }
      final editor = PlantEditorCubit(repository);
      await editor.load(null);
      await repository.injectFaultForTest(CoreVerificationFault.beforeFreeze);
      editor.update(
        name: 'Native retry fixture',
        species: 'Synthetic retry fern',
      );
      String? frozenID;
      try {
        await editor.flush();
        fail('expected interrupted freeze');
      } on UnknownCommandOutcome catch (error) {
        frozenID = error.commandId;
      }
      expect((await repository.editor(null)).draft, isNull);
      await editor.flush();
      expect(editor.state.draft!.revision, 1);
      expect((await repository.resolve(frozenID)).committed, isTrue);

      await repository.injectFaultForTest(CoreVerificationFault.beforeCommit);
      editor.update(notes: 'earlier queued text');
      await expectLater(editor.flush(), throwsA(isA<UnknownCommandOutcome>()));
      final pending = (await repository.pending()).single;
      expect(
        (pending.intent.command as SaveDraft).fields.notes,
        'earlier queued text',
      );
      editor.update(notes: 'latest keystrokes');
      await editor.flush();
      expect(editor.state.draft!.revision, 3);
      expect(editor.state.draft!.fields.notes, 'latest keystrokes');
      expect(
        (await repository.resolve(pending.intent.commandId)).committed,
        isTrue,
      );
      expect(await repository.pending(), isEmpty);

      final draft = editor.state.draft!;
      final command = SaveDraft(
        draftId: draft.id,
        expectedRevision: 3,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: 'Native retry fixture',
          speciesName: 'Synthetic retry fern',
          notes: 'committed before reply',
          routines: [
            RoutineInput(
              kind: StandardCareKind.water,
              count: '7',
              unit: IntervalUnit.day,
              seedKind: SeedKind.unknown,
              date: repository.today.toString(),
            ),
          ],
        ),
      );
      await repository.injectFaultForTest(
        CoreVerificationFault.afterCommitReply,
      );
      String? committedID;
      try {
        await repository.submit(command);
        fail('expected lost commit reply');
      } on UnknownCommandOutcome catch (error) {
        committedID = error.commandId;
      }
      await repository.injectFaultForTest(CoreVerificationFault.receiptRead);
      await expectLater(
        repository.resolve(committedID),
        throwsA(isA<RecoveryUnavailable>()),
      );
      final replay = await repository.submit(command);
      expect(replay.commandId, committedID);
      expect(replay.replayed, isTrue);
      expect((await repository.editor(null)).draft!.revision, 4);
      expect(
        (await repository.editor(null)).draft!.fields.notes,
        'committed before reply',
      );

      final saveCommand = SavePlant(draftId: draft.id, draftRevision: 4);
      await repository.injectFaultForTest(CoreVerificationFault.beforeFreeze);
      await expectLater(
        repository.prepare(saveCommand),
        throwsA(isA<UnknownCommandOutcome>()),
      );
      final savePreview = await repository.prepare(saveCommand);
      await repository.injectFaultForTest(
        CoreVerificationFault.afterCommitReply,
      );
      await expectLater(
        repository.confirm(savePreview),
        throwsA(isA<UnknownCommandOutcome>()),
      );
      await repository.injectFaultForTest(CoreVerificationFault.receiptRead);
      await expectLater(
        repository.confirm(savePreview),
        throwsA(isA<RecoveryUnavailable>()),
      );
      final saved = await repository.confirm(savePreview);
      expect(saved.replayed, isTrue);
      final plant = saved.primaryId!;
      var detail = await repository.detail(plant);
      final prepared = await repository.prepare(
        CompleteCurrent(detail.routines.single.target, repository.today),
      );
      await repository.injectFaultForTest(CoreVerificationFault.slowReadback);
      final care = await repository.confirm(prepared);
      expect(care.undo, isNotNull);
      expect(care.undo!.expiresInMilliseconds, lessThanOrEqualTo(6000));
      await repository.submit(Undo(care.commandId));
      expect(
        (await repository.timeline(
          plant,
          includeVoided: true,
        )).items.whereType<CareTimelineEntry>().single.voided,
        isTrue,
      );
      detail = await repository.detail(plant);
      await repository.confirm(
        await repository.prepare(
          ArchivePlant(plantId: plant, plantRevision: detail.plant.revision),
        ),
      );
      detail = await repository.detail(plant);
      await repository.confirm(
        await repository.prepare(
          DeletePlant(plantId: plant, plantRevision: detail.plant.revision),
        ),
      );
      await editor.close();
      await repository.close();
      expect(tester.takeException(), isNull);
    },
  );
}
