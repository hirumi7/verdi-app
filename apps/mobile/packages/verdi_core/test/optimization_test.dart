import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'support/storage_scenario.dart';

void main() {
  test(
    'replacement preserves trusted optimization provenance, imported date and shared references',
    () {
      final s = StorageScenario();
      s.run(
        SaveDraft(
          draftId: fixtureId(3),
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(name: 'QA', speciesName: 'Synthetic'),
        ),
      );
      s.run(SavePlant(draftId: fixtureId(3), draftRevision: 1));
      final plant = s.projection.snapshot.plants.keys.single,
          photo = fixtureId(90),
          draft = fixtureId(91),
          fresh = fixtureId(92),
          hash = 'a' * 64,
          newHash = 'b' * 64;
      const date = '2030-01-01', instant = '2026-10-20T00:00:00.000Z';
      s.rows['photos']!.add([
        photo,
        plant,
        null,
        1,
        'media/$photo/$hash.jpg',
        hash,
        10000,
        'image/jpeg',
        2400,
        1600,
        date,
        'library',
        null,
        instant,
      ]);
      s.rows['plant_covers']!.add([plant, photo]);
      s.rows['journal_entries']!.add([
        fixtureId(93),
        plant,
        1,
        date,
        'Saved photo',
        canonicalCommandJson([photo]),
        instant,
        instant,
      ]);
      s.projection.hydrate(
        s.rows,
        s.projection.snapshot.revision,
        s.projection.storageRevision + 1,
      );
      s.run(
        SaveMediaDraft(
          draftId: draft,
          expectedRevision: null,
          plantId: plant,
          photoId: photo,
          basePhotoRevision: 1,
        ),
      );
      s.rows['photos']!.add([
        fresh,
        null,
        draft,
        1,
        'media/$fresh/$newHash.jpg',
        newHash,
        4000,
        'image/jpeg',
        1280,
        853,
        date,
        'library',
        hash,
        instant,
      ]);
      final row = s.rows['media_drafts']!.single;
      row[1] = 2;
      row[5] = canonicalCommandJson([fresh]);
      s.projection.hydrate(
        s.rows,
        s.projection.snapshot.revision,
        s.projection.storageRevision + 1,
      );
      final result = s
          .run(
            ReplacePhoto(
              photo,
              1,
              preparationId: fixtureId(94),
              draftId: draft,
              draftRevision: 2,
            ),
          )
          .candidate;
      final saved = result.photos[photo]!;
      expect(saved.optimizedFromHash, hash);
      expect(saved.observedDate.toString(), date);
      expect(saved.createdAt, DateTime.parse(instant));
      expect(saved.sourceKind, 'library');
      expect(saved.contentPath, 'media/$photo/$newHash.jpg');
      expect(result.covers[plant], photo);
      expect(result.journalEntries[fixtureId(93)]!.photoIds, [photo]);
      expect(result.mediaDrafts, isEmpty);
      expect(result.photos.keys, [photo]);
      expect(saved.revision, 2);
    },
  );
}
