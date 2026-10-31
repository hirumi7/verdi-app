import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'support/storage_scenario.dart';
import 'support/journal_scenario.dart';

void main() {
  test(
    'journal commands hydrate, preserve raw drafts and match native vectors',
    () {
      final s = journalScenario();
      expect(s.projection.snapshot.journalEntries, isEmpty);
      expect(
        jsonDecode(s.json()),
        jsonDecode(
          File(
            '../verdi_native/Tests/VerdiNativeTests/Fixtures/journal-storage-v3.json',
          ).readAsStringSync(),
        ),
      );
    },
  );
  StorageScenario setup() {
    final s = StorageScenario();
    s.run(
      SaveDraft(
        draftId: fixtureId(3),
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(name: 'Plant', speciesName: 'Unknown'),
      ),
    );
    s.run(SavePlant(draftId: fixtureId(3), draftRevision: 1));
    return s;
  }

  void prepareFakePhoto(StorageScenario s, String draft, String photo) {
    final hash = 'a' * 64, now = s.projection.clock.instant.toIso8601String();
    s.rows['photos']!.add([
      photo,
      null,
      draft,
      1,
      'media/$photo/$hash.png',
      hash,
      200,
      'image/png',
      10,
      10,
      '2026-10-20',
      'library',
      null,
      now,
    ]);
    final row = s.rows['journal_drafts']!.singleWhere((r) => r[0] == draft);
    row[1] = (row[1] as int) + 1;
    row[5] = canonicalCommandJson({
      ...asMap(jsonDecode(row[5] as String)),
      'selectedPhotoIds': [photo],
    });
    row[6] = canonicalCommandJson([photo]);
    s.projection.hydrate(
      s.rows,
      s.projection.snapshot.revision,
      s.projection.storageRevision + 1,
    );
  }

  test(
    'blank, future and invalid notes remain drafts without a false saved entry',
    () {
      final s = setup(),
          plant = s.projection.snapshot.plants.values.single.id,
          draft = fixtureId(400);
      for (final text in ['', String.fromCharCode(0xd800), 'x' * 2001]) {
        final old = s.projection.snapshot.journalDrafts[draft];
        s.run(
          SaveJournalDraft(
            draftId: draft,
            expectedRevision: old?.revision,
            plantId: plant,
            fields: JournalFields(text: text, entryDate: '2026-10-31'),
          ),
        );
        expect(
          () => s.projection.plan(
            s.projection.freeze(
              SaveJournalEntry(
                draft,
                s.projection.snapshot.journalDrafts[draft]!.revision,
              ),
            ),
            fixtureId(2),
          ),
          throwsA(isA<CommandRejected>()),
        );
        expect(s.projection.snapshot.journalEntries, isEmpty);
      }
      final old = s.projection.snapshot.journalDrafts[draft]!;
      s.run(
        SaveJournalDraft(
          draftId: draft,
          expectedRevision: old.revision,
          plantId: plant,
          fields: JournalFields(text: 'Note', entryDate: '2026-11-01'),
        ),
      );
      expect(
        () => s.projection.plan(
          s.projection.freeze(SaveJournalEntry(draft, old.revision + 1)),
          fixtureId(2),
        ),
        throwsA(isA<CommandRejected>()),
      );
    },
  );
  test(
    'photo-only save transfers ownership, cover shares it, deletion keeps note and clears refs',
    () {
      final s = setup(),
          plant = s.projection.snapshot.plants.values.single,
          draft = fixtureId(400),
          photo = fixtureId(9000);
      s.run(
        SaveJournalDraft(
          draftId: draft,
          expectedRevision: null,
          plantId: plant.id,
          fields: JournalFields(text: 'New leaf', entryDate: '2026-10-20'),
        ),
      );
      prepareFakePhoto(s, draft, photo);
      final entry = s
          .run(SaveJournalEntry(draft, 2))
          .candidate
          .journalEntries
          .values
          .single;
      expect(s.projection.snapshot.photos[photo]!.plantId, plant.id);
      expect(s.projection.snapshot.photos[photo]!.draftId, isNull);
      s.run(
        SaveDraft(
          draftId: fixtureId(401),
          expectedRevision: null,
          mode: DraftMode.edit,
          plantId: plant.id,
          basePlantRevision: plant.revision,
          fields: CustomPlantFields(
            name: plant.name,
            speciesName: plant.speciesName,
            coverPhotoId: photo,
          ),
        ),
      );
      s.run(SavePlant(draftId: fixtureId(401), draftRevision: 1));
      expect(s.projection.snapshot.covers[plant.id], photo);
      final p = s.projection.snapshot.photos[photo]!;
      s.run(DeletePhoto(photo, p.revision));
      expect(s.projection.snapshot.photos, isEmpty);
      expect(s.projection.snapshot.covers, isEmpty);
      expect(s.projection.snapshot.journalEntries[entry.id]!.text, 'New leaf');
      expect(s.projection.snapshot.journalEntries[entry.id]!.photoIds, isEmpty);
    },
  );
  test('delete refuses photo-only entry with an acknowledged edit draft', () {
    final s = setup(),
        plant = s.projection.snapshot.plants.values.single.id,
        draft = fixtureId(400),
        photo = fixtureId(9000);
    s.run(
      SaveJournalDraft(
        draftId: draft,
        expectedRevision: null,
        plantId: plant,
        fields: JournalFields(entryDate: '2026-10-20'),
      ),
    );
    prepareFakePhoto(s, draft, photo);
    final e = s
        .run(SaveJournalEntry(draft, 2))
        .candidate
        .journalEntries
        .values
        .single;
    s.run(
      SaveJournalDraft(
        draftId: fixtureId(401),
        expectedRevision: null,
        plantId: plant,
        entryId: e.id,
        baseEntryRevision: e.revision,
        fields: JournalFields(
          text: 'Unsaved important note',
          entryDate: '2026-10-20',
          selectedPhotoIds: [photo],
        ),
      ),
    );
    expect(
      () => s.projection.plan(
        s.projection.freeze(DeletePhoto(photo, 2)),
        fixtureId(2),
      ),
      throwsA(
        isA<CommandRejected>().having((e) => e.code, 'code', 'DRAFT_CONFLICT'),
      ),
    );
    expect(
      s.projection.snapshot.journalDrafts.values.single.fields.text,
      'Unsaved important note',
    );
  });
  test('foreign parent and duplicate attachment IDs fail whole hydration', () {
    final s = setup(),
        plant = s.projection.snapshot.plants.values.single.id,
        draft = fixtureId(400),
        photo = fixtureId(9000);
    s.run(
      SaveJournalDraft(
        draftId: draft,
        expectedRevision: null,
        plantId: plant,
        fields: JournalFields(entryDate: '2026-10-20'),
      ),
    );
    prepareFakePhoto(s, draft, photo);
    final row = s.rows['photos']!.single;
    row[1] = fixtureId(9001);
    row[2] = null;
    expect(
      () => s.projection.hydrate(
        s.rows,
        s.projection.snapshot.revision,
        s.projection.storageRevision + 1,
      ),
      throwsA(
        isA<CommandRejected>().having((e) => e.code, 'code', 'STORAGE_INVALID'),
      ),
    );
  });
}
