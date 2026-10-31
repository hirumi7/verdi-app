import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/media/presentation/cubits/photo_cubit.dart';
import 'package:verdi_mobile/features/journal/presentation/cubits/journal_editor_cubit.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

import '../packages/verdi_core/test/support/storage_scenario.dart';

class MediaScenarioRepository extends MemoryCollectionRepository {
  final scenario = StorageScenario();
  late String plant, photo, draft;
  final requests = <Map<String, Object?>>[];
  bool lost = true;
  MediaScenarioRepository() {
    scenario.run(
      SaveDraft(
        draftId: fixtureId(3),
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(name: 'Photo test', speciesName: 'Synthetic'),
      ),
    );
    plant = scenario
        .run(SavePlant(draftId: fixtureId(3), draftRevision: 1))
        .candidate
        .plants
        .values
        .single
        .id;
    photo = fixtureId(800);
    draft = fixtureId(801);
    final now = scenario.projection.clock.instant, hash = 'a' * 64;
    scenario.rows['photos']!.add(
      PlantPhoto(
        photo,
        plant,
        null,
        1,
        'media/$photo/$hash.png',
        hash,
        99,
        'image/png',
        32,
        32,
        LocalDate(2026, 10, 20),
        'library',
        null,
        now,
      ).toRow(),
    );
    final older = fixtureId(999);
    scenario.rows['photos']!.add(
      PlantPhoto(
        older,
        plant,
        null,
        1,
        'media/$older/$hash.png',
        hash,
        99,
        'image/png',
        32,
        32,
        LocalDate(2026, 10, 20),
        'library',
        null,
        now.subtract(const Duration(days: 1)),
      ).toRow(),
    );
    scenario.projection.hydrate(
      scenario.rows,
      scenario.projection.snapshot.revision,
      scenario.projection.storageRevision + 1,
    );
    scenario.run(
      SaveMediaDraft(
        draftId: draft,
        expectedRevision: null,
        plantId: plant,
        photoId: photo,
        basePhotoRevision: 1,
      ),
    );
  }
  @override
  Future<CollectionSnapshot> mediaSnapshot() async =>
      scenario.projection.snapshot;
  @override
  Future<List<Map<String, Object?>>> draftPreparations(String draftId) async =>
      draftId == draft
      ? [
          {
            'draftRevision': 1,
            'preparationId': 'old-preparation',
            'selectionId': 'old-selection',
            'observedDate': '2026-10-18',
            'status': {'kind': 'failed', 'code': 'IO_FAILURE'},
          },
        ]
      : [];
  @override
  Future<Map<String, Object?>> preparePhoto({
    required String draftId,
    required int draftRevision,
    required String preparationId,
    required String selectionId,
    required LocalDate observedDate,
  }) async {
    requests.add({
      'id': preparationId,
      'selection': selectionId,
      'date': observedDate.toString(),
      'revision': draftRevision,
    });
    if (lost) {
      lost = false;
      throw const RecoveryUnavailable();
    }
    return {'kind': 'failed', 'code': 'IO_FAILURE'};
  }

  @override
  Future<Map<String, Object?>> photoPreparation(String id) async {
    if (requests.length < 2) throw CommandRejected('NOT_FOUND');
    return {'kind': 'failed', 'code': 'IO_FAILURE'};
  }

  @override
  Future<CommandSuccess> submit(CoreCommand command) async {
    return scenario.projection.success(
      (scenario.run(command).body()['result'] as Map).cast<String, Object?>(),
    );
  }
}

void main() {
  test('replacement retries the new selection/date after old failed preparation and lost start', () async {
    final r = MediaScenarioRepository();
    final editor = PhotoCubit(r, r.plant),
        photo = (await r.mediaSnapshot()).photos[r.photo]!;
    await editor.attach(photo, 'new-selection', LocalDate(2026, 10, 19));
    expect(editor.state.preparationKind, 'copying');
    await editor.resolve(photo.id);
    expect(r.requests.length, 2);
    expect(r.requests[1], r.requests[0]);
    expect(r.requests[1]['selection'], 'new-selection');
    expect(r.requests[1]['date'], '2026-10-19');
    await editor.close();
  });
  test(
    'gallery equal observation dates use creation time before stable ID',
    () async {
      final r = MediaScenarioRepository();
      final editor = PhotoCubit(r, r.plant);
      await editor.load();
      expect(editor.state.photos.first.id, r.photo);
      await editor.close();
    },
  );
  test(
    'removing a journal attachment autosaves and survives reopening',
    () async {
      final r = MediaScenarioRepository(), id = fixtureId(850);
      r.scenario.run(
        SaveJournalDraft(
          draftId: id,
          expectedRevision: null,
          plantId: r.plant,
          fields: JournalFields(
            text: 'Retain note',
            entryDate: '2026-10-20',
            selectedPhotoIds: [r.photo],
          ),
        ),
      );
      final editor = JournalEditorCubit(r, r.plant, null);
      await editor.load();
      editor.removeAttachment(r.photo);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(editor.state.saving, false);
      expect(editor.state.draft!.fields.selectedPhotoIds, isEmpty);
      await editor.close();
      final reopened = JournalEditorCubit(r, r.plant, null);
      await reopened.load();
      expect(reopened.state.fields!.selectedPhotoIds, isEmpty);
      expect(reopened.state.fields!.text, 'Retain note');
      expect((await r.mediaSnapshot()).photos.containsKey(r.photo), true);
      await reopened.close();
    },
  );
}
