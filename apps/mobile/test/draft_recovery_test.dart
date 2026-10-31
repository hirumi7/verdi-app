import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

class FailingReadsRepository extends MemoryCollectionRepository {
  bool loseReplyAndReceipt = false;
  bool failNextRead = false;
  final saves = <SaveDraft>[];

  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    if (command is SaveDraft) saves.add(command);
    if (loseReplyAndReceipt) {
      loseReplyAndReceipt = false;
      store.nextFault = SimulatedFault.afterCommitReplyLost;
      try {
        return await super.submit(command);
      } on UnknownCommandOutcome {
        store.nextFault = SimulatedFault.receiptRead;
        rethrow;
      }
    }
    return super.submit(command);
  }

  @override
  Future<PlantEditor> editor(String? plantId) async {
    if (failNextRead) {
      failNextRead = false;
      throw const RecoveryUnavailable();
    }
    return super.editor(plantId);
  }
}

void main() {
  test('confirmed local discard after another editor consumed the draft preserves its plant', () async {
    final repository = MemoryCollectionRepository();
    final first = PlantEditorCubit(repository);
    await first.load(null);
    first.update(name: 'Saved by first editor', species: 'Synthetic');
    await first.flush();
    final second = PlantEditorCubit(repository);
    await second.load(null);
    final saved = await repository.confirm(await first.preview());
    second.update(name: 'Unsaved local changes');
    await expectLater(second.flush(), throwsA(isA<CommandRejected>()));
    await second.discard();
    expect(second.state.dirty, isFalse);
    expect(
      (await repository.detail(saved.primaryId!)).plant.name,
      'Saved by first editor',
    );
    expect((await repository.editor(null)).draft, isNull);
    await first.close();
    await second.close();
  });
  test(
    'discard reports rollback and resolves a committed lost reply',
    () async {
      final repository = MemoryCollectionRepository();
      final editor = PlantEditorCubit(repository);
      await editor.load(null);
      editor.update(name: 'Keep draft', species: 'Synthetic species');
      await editor.flush();
      repository.store.nextFault = SimulatedFault.beforeCommit;
      await expectLater(editor.discard(), throwsA(isA<CommandRejected>()));
      expect(editor.state.errorCode, isNotNull);
      expect(editor.state.dirty, isTrue);
      expect((await repository.editor(null)).draft, isNotNull);
      repository.store.nextFault = SimulatedFault.afterCommitReplyLost;
      await editor.discard();
      expect(editor.state.dirty, isFalse);
      expect(editor.state.draft, isNull);
      expect(editor.state.errorCode, isNull);
      expect((await repository.editor(null)).draft, isNull);
      await editor.close();
    },
  );

  test('conflicting editors preserve local fields until explicit current-version review', () async {
    final repository = MemoryCollectionRepository();
    final first = PlantEditorCubit(repository);
    await first.load(null);
    first.update(name: 'Original', species: 'Synthetic species');
    await first.flush();
    final second = PlantEditorCubit(repository);
    await second.load(null);
    first.update(name: 'First editor');
    await first.flush();
    second.update(name: 'Second editor');
    await expectLater(second.flush(), throwsA(isA<CommandRejected>()));
    expect(second.state.fields!.name, 'Second editor');
    final review = await second.currentForReview();
    expect(review.editor.initialFields.name, 'First editor');
    expect((await repository.editor(null)).draft!.fields.name, 'First editor');
    await second.keepFieldsAfterReview(review);
    expect((await repository.editor(null)).draft!.fields.name, 'Second editor');
    await second.discard();
    expect((await repository.editor(null)).draft, isNull);
    await first.close();
    await second.close();
  });
  for (final lostReceipt in [true, false]) {
    test(
      'new text survives ${lostReceipt ? 'lost write/receipt' : 'failed read-back'}',
      () async {
        final repository = FailingReadsRepository();
        final editor = PlantEditorCubit(repository);
        await editor.load(null);
        editor.update(name: 'First text', species: 'Synthetic species');
        expect(
          editor.state.saving,
          isTrue,
          reason: 'debounce is not an acknowledgement',
        );
        if (lostReceipt) {
          repository.loseReplyAndReceipt = true;
        } else {
          repository.failNextRead = true;
        }
        await expectLater(editor.flush(), throwsA(isA<RecoveryUnavailable>()));
        expect(editor.state.fields!.name, 'First text');
        expect(editor.state.errorCode, 'UNKNOWN_OUTCOME');
        editor.update(name: 'New text typed during recovery');
        await editor.flush();
        final draft = (await repository.editor(null)).draft!;
        expect(draft.revision, 2);
        expect(draft.fields.name, 'New text typed during recovery');
        expect(editor.state.fields!.name, draft.fields.name);
        expect(editor.state.saving, isFalse);
        expect(editor.state.errorCode, isNull);
        expect(repository.saves.length, lostReceipt ? 3 : 2);
        if (lostReceipt) {
          expect(repository.saves[1], same(repository.saves[0]));
        }
        final saved = await repository.confirm(await editor.preview());
        expect(
          (await repository.detail(saved.primaryId!)).plant.name,
          draft.fields.name,
        );
        expect(
          (await repository.read(
            archived: false,
            query: '',
          )).plants.activeCount,
          1,
        );
        await editor.close();
      },
    );
  }

  test('recovered unselected seed stays unselected and cannot save', () async {
    final repository = MemoryCollectionRepository();
    var editor = PlantEditorCubit(repository);
    await editor.load(null);
    editor.update(
      name: 'Fern',
      species: 'Synthetic fern',
      routines: [
        const RoutineInput(
          kind: StandardCareKind.water,
          count: '7',
          unit: IntervalUnit.day,
          seedKind: null,
          date: '',
        ),
      ],
    );
    await editor.flush();
    await editor.close();
    editor = PlantEditorCubit(repository);
    await editor.load(null);
    expect(editor.state.fields!.routines.single.seedKind, isNull);
    await expectLater(editor.preview(), throwsA(isA<CommandRejected>()));
    expect(editor.state.errors['routineInputs[0].seed'], 'FIELD_INVALID');
    expect(
      (await repository.read(archived: false, query: '')).plants.activeCount,
      0,
    );
    editor.update(
      routines: [
        RoutineInput(
          kind: StandardCareKind.water,
          count: '7',
          unit: IntervalUnit.day,
          seedKind: SeedKind.unknown,
          date: repository.today.toString(),
        ),
      ],
    );
    final result = await repository.confirm(await editor.preview());
    final history = await repository.timeline(result.primaryId!);
    expect(history.items, isEmpty);
    await editor.close();
  });
}
