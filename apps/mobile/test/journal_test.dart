import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/journal/presentation/cubits/journal_editor_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

import 'package:verdi_mobile/features/collection/presentation/cubits/plant_editor_cubit.dart';

import 'presentation_test.dart' show seed, press, field;

class DelayedJournalRepository extends MemoryCollectionRepository {
  Completer<void>? gate;
  Completer<void>? started;
  bool dropReply = false;
  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    if (command is SaveJournalDraft &&
        command.expectedRevision != null &&
        gate != null) {
      started?.complete();
      final pending = gate!;
      gate = null;
      await pending.future;
    }
    return super.submit(command);
  }
}

class UncertainPhotoRepository extends MemoryCollectionRepository {
  final requests = <String>[];
  bool lost = true, knownFailure = false;
  @override
  Future<Map<String, Object?>> preparePhoto({
    required String draftId,
    required int draftRevision,
    required String preparationId,
    required String selectionId,
    required LocalDate observedDate,
  }) async {
    requests.add(preparationId);
    if (knownFailure) throw CommandRejected('MEDIA_SELECTION_EXPIRED');
    if (lost) {
      lost = false;
      throw const RecoveryUnavailable();
    }
    return {
      'kind': 'failed',
      'code': 'IO_FAILURE',
      'preparationId': preparationId,
      'draftRevision': draftRevision,
    };
  }

  @override
  Future<Map<String, Object?>> photoPreparation(String preparationId) async {
    if (requests.length < 2) throw CommandRejected('NOT_FOUND');
    return {
      'kind': 'failed',
      'code': 'IO_FAILURE',
      'preparationId': preparationId,
      'draftRevision': 1,
    };
  }
}

class RacingJournalRepository extends MemoryCollectionRepository {
  bool race = false;
  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    final result = await super.submit(command);
    if (race &&
        command is SaveJournalDraft &&
        command.expectedRevision != null) {
      race = false;
      final d = (await mediaSnapshot()).journalDrafts[command.draftId]!;
      await super.submit(
        SaveJournalDraft(
          draftId: d.id,
          expectedRevision: d.revision,
          plantId: d.plantId,
          entryId: d.entryId,
          baseEntryRevision: d.baseEntryRevision,
          fields: JournalFields(
            text: 'Other editor',
            entryDate: d.fields.entryDate,
          ),
          readyPhotoIds: d.readyPhotoIds,
        ),
      );
    }
    return result;
  }
}

class ReadyRetryRepository extends MemoryCollectionRepository {
  int attempts = 0, revision = 1;
  bool raceReady = false;
  @override
  Future<Map<String, Object?>> preparePhoto({
    required String draftId,
    required int draftRevision,
    required String preparationId,
    required String selectionId,
    required LocalDate observedDate,
  }) async {
    attempts++;
    if (attempts > 1) {
      final d = (await mediaSnapshot()).journalDrafts[draftId]!;
      await submit(
        SaveJournalDraft(
          draftId: d.id,
          expectedRevision: d.revision,
          plantId: d.plantId,
          fields: d.fields,
          readyPhotoIds: d.readyPhotoIds,
        ),
      );
      revision = d.revision + 1;
      if (raceReady) {
        final current = (await mediaSnapshot()).journalDrafts[d.id]!;
        await submit(
          SaveJournalDraft(
            draftId: d.id,
            expectedRevision: current.revision,
            plantId: d.plantId,
            fields: JournalFields(
              text: 'Other editor after ready',
              entryDate: d.fields.entryDate,
            ),
          ),
        );
      }
    }
    return photoPreparation(preparationId);
  }

  @override
  Future<Map<String, Object?>> photoPreparation(String id) async => {
    'kind': attempts > 1 ? 'ready' : 'failed',
    'code': 'IO_FAILURE',
    'preparationId': id,
    'draftRevision': revision,
  };
}

class TombstonedPhotoRepository extends MemoryCollectionRepository {
  @override
  Future<Map<String, Object?>> photoPreparation(String id) async => {
    'kind': 'consumed',
    'preparationId': id,
    'draftRevision': 2,
  };
}

class ReadyPlantRepository extends MemoryCollectionRepository {
  Map<String, Object?>? ready;
  @override
  Future<Map<String, Object?>> photoPreparation(String id) async {
    if (ready == null) throw CommandRejected('NOT_FOUND');
    return ready!;
  }

  @override
  Future<Map<String, Object?>> preparePhoto({
    required String draftId,
    required int draftRevision,
    required String preparationId,
    required String selectionId,
    required LocalDate observedDate,
  }) async {
    final draft = (await mediaSnapshot()).drafts[draftId]!;
    await submit(
      SaveDraft(
        draftId: draft.id,
        expectedRevision: draft.revision,
        mode: draft.mode,
        plantId: draft.plantId,
        basePlantRevision: draft.basePlantRevision,
        fields: draft.fields,
      ),
    );
    return ready = {
      'kind': 'ready',
      'preparationId': preparationId,
      'draftRevision': draft.revision + 1,
    };
  }
}

void main() {
  test(
    'journal autosave acknowledges only frozen text and retries later edits',
    () async {
      final r = DelayedJournalRepository();
      await seed(r, 'Autosave fern');
      final plant = (await r.read(
        archived: false,
        query: '',
      )).plants.page.items.single.plant;
      final c = JournalEditorCubit(r, plant.id, null);
      await c.load();
      final gate = Completer<void>();
      r.gate = gate;
      r.started = Completer<void>();
      c.update(text: 'Before await');
      final flush = c.flush();
      await r.started!.future;
      c.update(text: 'After await');
      gate.complete();
      await flush;
      expect(c.state.draft!.fields.text, 'After await');
      expect(c.state.fields!.text, 'After await');
      expect(c.state.saving, false);
      final preview = await c.prepareSave();
      await r.confirm(preview);
      final snapshot = await r.mediaSnapshot();
      expect(snapshot.journalEntries.values.single.text, 'After await');
      expect(snapshot.journalDrafts, isEmpty);
      await c.close();
    },
  );
  test(
    'lost draft acknowledgement resolves once without duplicate journal slot',
    () async {
      final r = MemoryCollectionRepository();
      await seed(r, 'Recovery fern');
      final plant = (await r.read(
        archived: false,
        query: '',
      )).plants.page.items.single.plant;
      final c = JournalEditorCubit(r, plant.id, null);
      await c.load();
      r.store.nextFault = SimulatedFault.afterCommitReplyLost;
      c.update(text: 'Retained note');
      await expectLater(c.flush(), throwsA(isA<UnknownCommandOutcome>()));
      c.update(text: 'Later note');
      await c.flush();
      expect(c.state.draft!.fields.text, 'Later note');
      expect((await r.mediaSnapshot()).journalDrafts.length, 1);
      await c.close();
    },
  );
  test('journal uncertain preparation retries exact ID and requires explicit note continuation', () async {
    final r = UncertainPhotoRepository();
    await seed(r, 'Pending photo fern');
    final plant = (await r.mediaSnapshot()).plants.values.single;
    final c = JournalEditorCubit(r, plant.id, null);
    await c.load();
    c.update(text: 'Keep my note');
    await c.flush();
    await c.attach('selection', r.today);
    expect(c.state.attachmentPending, true);
    c.update(
      text: 'Must not replace acknowledged fields during native attachment',
    );
    expect(c.state.fields!.text, 'Keep my note');
    await expectLater(c.prepareSave(), throwsA(isA<RecoveryUnavailable>()));
    await c.resolvePreparation();
    expect(r.requests.length, 2);
    expect(r.requests.toSet().length, 1);
    expect(c.state.attachmentPending, false);
    expect(c.state.attachmentFailed, true);
    await expectLater(c.prepareSave(), throwsA(isA<CommandRejected>()));
    c.saveNoteOnly();
    await r.confirm(await c.prepareSave());
    expect(
      (await r.mediaSnapshot()).journalEntries.values.single.text,
      'Keep my note',
    );
    await c.close();
  });
  test(
    'known expired selection unlocks explicit journal continuation',
    () async {
      final r = UncertainPhotoRepository()..knownFailure = true;
      await seed(r, 'Expired photo fern');
      final c = JournalEditorCubit(
        r,
        (await r.mediaSnapshot()).plants.values.single.id,
        null,
      );
      await c.load();
      c.update(text: 'Retained');
      await c.attach('expired', r.today);
      expect(c.state.attachmentPending, false);
      expect(c.state.attachmentFailed, true);
      c.saveNoteOnly();
      await r.confirm(await c.prepareSave());
      await c.close();
    },
  );
  test('plant attachment recovery keeps frozen ID and prevents save until failure acknowledged', () async {
    final r = UncertainPhotoRepository();
    await seed(r, 'Cover fern');
    final c = PlantEditorCubit(r);
    await c.load((await r.mediaSnapshot()).plants.values.single.id);
    await expectLater(
      c.attachPhoto('selection', r.today),
      throwsA(isA<RecoveryUnavailable>()),
    );
    expect(c.state.photoPending, true);
    await expectLater(c.preview(), throwsA(isA<CommandRejected>()));
    await expectLater(c.recoverPhoto(), throwsA(isA<CommandRejected>()));
    expect(r.requests.toSet().length, 1);
    expect(c.state.photoPending, false);
    expect(c.state.photoFailed, true);
    c.continueWithoutPhoto();
    await r.confirm(await c.preview());
    await c.close();
  });
  test(
    'retry flushes immediately typed note before native acknowledgement',
    () async {
      final r = ReadyRetryRepository();
      await seed(r, 'Retry fern');
      final c = JournalEditorCubit(
        r,
        (await r.mediaSnapshot()).plants.values.single.id,
        null,
      );
      await c.load();
      c.update(text: 'Old');
      await c.attach('selection', r.today);
      c.update(text: 'New pending note');
      await c.retryAttachment();
      expect(c.state.fields!.text, 'New pending note');
      expect(c.state.draft!.fields.text, 'New pending note');
      await c.close();
    },
  );
  test(
    'newer journal draft requires review and preserves this editor fields',
    () async {
      final r = RacingJournalRepository();
      await seed(r, 'Conflict fern');
      final c = JournalEditorCubit(
        r,
        (await r.mediaSnapshot()).plants.values.single.id,
        null,
      );
      await c.load();
      r.race = true;
      c.update(text: 'My retained text');
      await expectLater(c.flush(), throwsA(isA<CommandRejected>()));
      expect(c.state.errorCode, 'DRAFT_CONFLICT');
      expect(c.state.fields!.text, 'My retained text');
      final current = (await c.currentDraft())!;
      expect(current.fields.text, 'Other editor');
      await c.keepFieldsAfterReview(current);
      expect(c.state.draft!.fields.text, 'My retained text');
      await r.confirm(await c.prepareSave());
      await c.close();
    },
  );
  test('consumed journal draft allows confirmed local-only discard', () async {
    final r = MemoryCollectionRepository();
    await seed(r, 'Consumed fern');
    final c = JournalEditorCubit(
      r,
      (await r.mediaSnapshot()).plants.values.single.id,
      null,
    );
    await c.load();
    c.update(text: 'Saved elsewhere');
    await c.flush();
    await r.confirm(
      await r.prepare(
        SaveJournalEntry(c.state.draft!.id, c.state.draft!.revision),
      ),
    );
    c.update(text: 'Unsaved local');
    await expectLater(c.flush(), throwsA(isA<CommandRejected>()));
    await c.discard();
    expect(
      (await r.mediaSnapshot()).journalEntries.values.single.text,
      'Saved elsewhere',
    );
    await c.close();
  });
  test(
    'ready attachment followed by draft race enters usable conflict review',
    () async {
      final r = ReadyRetryRepository()..raceReady = true;
      await seed(r, 'Ready conflict');
      final c = JournalEditorCubit(
        r,
        (await r.mediaSnapshot()).plants.values.single.id,
        null,
      );
      await c.load();
      c.update(text: 'Retain my text');
      await c.attach('selection', r.today);
      await c.retryAttachment();
      expect(c.state.attachmentPending, false);
      expect(c.state.errorCode, 'DRAFT_CONFLICT');
      expect(c.state.fields!.text, 'Retain my text');
      await c.keepFieldsAfterReview((await c.currentDraft())!);
      expect(c.state.draft!.fields.text, 'Retain my text');
      await c.close();
    },
  );
  test(
    'plant preparation tombstone unlocks conflict handling without recreation',
    () async {
      final r = TombstonedPhotoRepository();
      await seed(r, 'Tombstone fern');
      final c = PlantEditorCubit(r);
      await c.load((await r.mediaSnapshot()).plants.values.single.id);
      await expectLater(
        c.attachPhoto('selection', r.today),
        throwsA(isA<CommandRejected>()),
      );
      expect(c.state.photoPending, false);
      expect((await r.mediaSnapshot()).photos, isEmpty);
      await c.close();
    },
  );
  test(
    'checking acknowledged cover never overwrites newly typed plant fields',
    () async {
      final r = ReadyPlantRepository();
      await seed(r, 'Old name');
      final c = PlantEditorCubit(r);
      await c.load((await r.mediaSnapshot()).plants.values.single.id);
      await c.attachPhoto('selection', r.today);
      c.update(name: 'New unflushed name');
      await c.recoverPhoto();
      expect(c.state.fields!.name, 'New unflushed name');
      expect(c.state.draft!.fields.name, 'New unflushed name');
      await c.close();
    },
  );
  testWidgets('main journal note add, backdate, edit and delete retains care', (
    tester,
  ) async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
    addTearDown(getIt.reset);
    final r = getIt<CollectionRepository>();
    await seed(r, 'Journal UI fern');
    await tester.pumpWidget(const VerdiApp());
    await tester.pumpAndSettle();
    await press(tester, 'Plants');
    await press(tester, 'Journal UI fern');
    await press(tester, 'New journal entry');
    expect(field('Note'), findsOneWidget);
    await tester.enterText(field('Note'), 'A new leaf unfurled');
    await tester.enterText(field('Observation date'), '2026-09-15');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(
      (await r.mediaSnapshot()).journalDrafts.values.single.fields.entryDate,
      '2026-09-15',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await press(tester, 'Save entry');
    await press(tester, 'Confirm');
    await press(tester, 'September 2026');
    expect(find.text('September 2026'), findsOneWidget);
    await press(tester, 'Edit entry');
    await tester.enterText(field('Note'), 'Two leaves unfurled');
    await tester.pump(const Duration(milliseconds: 400));
    FocusManager.instance.primaryFocus?.unfocus();
    await press(tester, 'Save entry');
    await press(tester, 'Confirm');
    await press(tester, 'Delete entry');
    await press(tester, 'Confirm');
    expect((await r.mediaSnapshot()).journalEntries, isEmpty);
    expect((await r.mediaSnapshot()).routines.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'small screen and large text keep journal error and retry reachable',
    (tester) async {
      await getIt.reset();
      await configureDependencies(environment: 'memory');
      addTearDown(getIt.reset);
      tester.view.physicalSize = const Size(375, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final r = getIt<CollectionRepository>();
      await seed(r, 'Large journal');
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Plants');
      await press(tester, 'Large journal');
      await press(tester, 'New journal entry');
      await tester.scrollUntilVisible(
        field('Note'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(field('Note'), 'Preserve this note');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        field('Observation date'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(field('Observation date'), 'invalid');
      await tester.pump(const Duration(milliseconds: 400));
      FocusManager.instance.primaryFocus?.unfocus();
      await press(tester, 'Save entry');
      expect(
        (await r.mediaSnapshot()).journalDrafts.values.single.fields.text,
        'Preserve this note',
      );
      expect((await r.mediaSnapshot()).journalEntries, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
