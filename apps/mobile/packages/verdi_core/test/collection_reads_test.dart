import 'package:test/test.dart' hide Skip;
import 'package:verdi_core/verdi_core.dart';
import 'catalog_test.dart' show bundledCatalog;
import 'support/storage_scenario.dart' show fixtureId, StorageScenario;
import 'collection_test.dart'
    show Harness, id, date, known, unknown, fields, rejected;

void main() {
  test(
    'Today art and user cover use the same snapshot regardless of Plants filters',
    () {
      final s = StorageScenario();
      final catalog = bundledCatalog();
      s.projection.reader.catalog = catalog;
      final selection = catalog.entry('sp_monstera_deliciosa')!.selection;
      s.run(
        SaveDraft(
          draftId: fixtureId(3),
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(
            name: 'Monstera',
            speciesName: selection.speciesNameSnapshot,
            catalogSelection: selection,
            routines: [
              RoutineInput(
                kind: StandardCareKind.water,
                count: '7',
                unit: IntervalUnit.day,
                seedKind: SeedKind.unknown,
                date: '2026-10-31',
              ),
            ],
          ),
        ),
      );
      s.run(SavePlant(draftId: fixtureId(3), draftRevision: 1));
      final plant = s.projection.snapshot.plants[s.plant]!;
      final photo = fixtureId(9991), hash = 'a' * 64;
      s.rows['photos']!.add([
        photo,
        plant.id,
        null,
        3,
        'media/$photo/$hash.jpg',
        hash,
        1000,
        'image/jpeg',
        100,
        100,
        '2026-10-20',
        'library',
        null,
        '2026-10-20T00:00:00.000Z',
      ]);
      s.rows['plant_covers']!.add([plant.id, photo]);
      s.projection.hydrate(
        s.rows,
        s.projection.snapshot.revision,
        s.projection.storageRevision + 1,
      );
      final reader = s.projection.reader;
      final before = reader
          .getReminderCandidates(datasetId: s.projection.snapshot.datasetId)
          .items;
      expect(before, isNotEmpty);
      reader.listPlants(
        datasetId: s.projection.snapshot.datasetId,
        archived: true,
        query: 'absent',
        limit: 1,
      );
      final after = reader
          .getReminderCandidates(datasetId: s.projection.snapshot.datasetId)
          .items;
      final todayRows = reader
          .getToday(
            datasetId: s.projection.snapshot.datasetId,
            section: TodaySection.today,
          )
          .page
          .items
          .cast<CheckRow>();
      expect(todayRows, isNotEmpty);
      for (final row in [...after, ...todayRows]) {
        expect(row.speciesId, plant.catalogSelection!.speciesId);
        expect(row.coverPhotoId, photo);
        expect(row.coverPhotoRevision, 3);
      }
      expect(
        after.map((r) => r.target.plantId),
        before.map((r) => r.target.plantId),
      );
    },
  );

  test(
    'plants filter before limit; stable name/ID pages and complete active count',
    () {
      final h = Harness();
      for (final name in ['Zulu', 'alpha', 'Alpha']) {
        h.confirm(
          h.previewDraft(h.draft(fields(name: name, location: 'Kitchen'))),
        );
      }
      final first = h.core.listPlants(
        datasetId: id(1),
        query: '  KITCHEN ',
        limit: 1,
      );
      expect(first.activeCount, 3);
      expect(first.page.totalCount, 3);
      expect(first.page.items.single.plant.name, 'alpha');
      final next = h.core.listPlants(
        datasetId: id(1),
        query: 'kitchen',
        limit: 1,
        cursor: first.page.nextCursor,
      );
      expect(next.page.items.single.plant.name, 'Alpha');
      expect(next.activeCount, isNull);
      final last = h.core.listPlants(
        datasetId: id(1),
        query: 'kitchen',
        cursor: next.page.nextCursor,
      );
      expect(last.page.items.single.plant.name, 'Zulu');
      expect(last.page.nextCursor, isNull);
      expect(
        h.core
            .listPlants(datasetId: id(1), query: 'absent', limit: 1)
            .page
            .items,
        isEmpty,
      );
    },
  );

  test(
    'query, date, dataset and collection changes invalidate keysets, drafts do not',
    () {
      final h = Harness()
        ..add()
        ..add();
      final cursor = h.core
          .listPlants(datasetId: id(1), limit: 1)
          .page
          .nextCursor!;
      expect(
        () =>
            h.core.listPlants(datasetId: id(1), query: 'fern', cursor: cursor),
        rejected('READ_STALE'),
      );
      expect(
        () =>
            h.core.listPlants(datasetId: id(1), archived: true, cursor: cursor),
        rejected('READ_STALE'),
      );
      h.draft(fields(name: 'unfinished'));
      expect(
        h.core.listPlants(datasetId: id(1), cursor: cursor).page.items.length,
        1,
      );
      h.today = h.today.addDays(1);
      expect(
        () => h.core.listPlants(datasetId: id(1), cursor: cursor),
        rejected('READ_STALE'),
      );
      h.today = h.today.addDays(-1);
      final plant = h.snapshot.plants.values.first;
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      expect(
        () => h.core.listPlants(datasetId: id(1), cursor: cursor),
        rejected('READ_STALE'),
      );
      h.store.replaceWithEmptyDatasetForTest(id(2));
      expect(
        () => h.core.listPlants(datasetId: id(2), cursor: cursor),
        rejected('READ_STALE'),
      );
    },
  );

  test(
    'Today sections use calendar dates, full counts and fixed care order',
    () {
      final h = Harness()
        ..add(
          routines: [
            unknown(kind: StandardCareKind.rotate, day: '2026-10-25'),
            unknown(kind: StandardCareKind.water, day: '2026-10-25'),
            unknown(kind: StandardCareKind.mist, day: '2026-10-23'),
            unknown(kind: StandardCareKind.repot, day: '2026-11-01'),
            unknown(kind: StandardCareKind.fertilize, day: '2026-11-02'),
          ],
        );
      final page = h.core.getToday(
        datasetId: id(1),
        section: TodaySection.today,
        limit: 1,
      );
      expect(page.page.items.single.careKind, StandardCareKind.water);
      expect(page.counts, {
        TodaySection.overdue: 1,
        TodaySection.today: 2,
        TodaySection.upcoming: 1,
        TodaySection.doneToday: 0,
      });
      expect(page.summary!.activePlantCount, 1);
      expect(page.summary!.eligibleCheckCount, 5);
      expect(page.summary!.nextCheck!.overdueDays, 2);
      final next = h.core.getToday(
        datasetId: id(1),
        section: TodaySection.today,
        cursor: page.page.nextCursor,
      );
      expect(next.page.items.single.careKind, StandardCareKind.rotate);
      expect(next.summary, isNull);
      final filtered = h.core.getToday(
        datasetId: id(1),
        section: TodaySection.today,
        careKind: StandardCareKind.mist,
      );
      expect(filtered.page.items, isEmpty);
      expect(filtered.counts[TodaySection.overdue], 1);
      expect(filtered.summary!.eligibleCheckCount, 5);
      expect(h.core.getReminderCandidates(datasetId: id(1)).items.length, 5);
    },
  );

  test('no checks due still exposes the next head beyond seven days', () {
    final h = Harness()..add(routines: [unknown(day: '2026-12-31')]);
    final result = h.core.getToday(
      datasetId: id(1),
      section: TodaySection.upcoming,
    );
    expect(result.page.items, isEmpty);
    expect(result.summary!.nextCheck!.date, date('2026-12-31'));
    h.confirm(h.preview(PauseRoutine(h.target())));
    final paused = h.core.getToday(
      datasetId: id(1),
      section: TodaySection.today,
    );
    expect(paused.summary!.nextCheck, isNull);
    expect(paused.summary!.activePlantCount, 1);
    expect(h.core.getReminderCandidates(datasetId: id(1)).items, isEmpty);
  });

  test(
    'done today includes backfilled actual care and excludes check, skip and void',
    () {
      final h = Harness()..add(routines: [known()]);
      h.confirm(
        h.preview(CheckNotNeeded(h.target(), h.today, h.today.addDays(2))),
      );
      h.confirm(h.preview(Skip(h.target())));
      final saved = h.confirm(
        h.preview(AddPastCare(h.target(), h.today, CareOutcome.actualCare)),
      );
      var result = h.core.getToday(
        datasetId: id(1),
        section: TodaySection.doneToday,
      );
      final done = result.page.items.single as DoneTodayRow;
      expect(done.care.id, saved.primaryId);
      expect(done.care.routineId, h.target().routineId);
      h.confirm(h.preview(RetireRoutine(h.target())));
      expect(
        h.core
            .getToday(datasetId: id(1), section: TodaySection.doneToday)
            .page
            .items
            .length,
        1,
      );
      final event = h.core.getEvent(
        datasetId: id(1),
        eventId: saved.primaryId!,
      );
      h.confirm(
        h.preview(
          VoidEvent(
            h.target(),
            eventId: event.id,
            eventRevision: event.event.revision,
          ),
        ),
      );
      result = h.core.getToday(
        datasetId: id(1),
        section: TodaySection.doneToday,
      );
      expect(result.page.items, isEmpty);
    },
  );

  test(
    'archive excludes Today/reminders but keeps detail and full audit readable',
    () {
      final h = Harness()..add(routines: [known()]);
      h.confirm(
        h.preview(AddPastCare(h.target(), h.today, CareOutcome.actualCare)),
      );
      h.confirm(h.preview(RetireRoutine(h.target())));
      var plant = h.snapshot.plants.values.single;
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      plant = h.snapshot.plants[plant.id]!;
      final detail = h.core.getPlantDetail(datasetId: id(1), plantId: plant.id);
      expect(detail.canDelete, isTrue);
      expect(detail.canRestore, isTrue);
      expect(detail.routines.single.canComplete, isFalse);
      expect(detail.routines.single.canAddPastCare, isTrue);
      expect(detail.routines.single.actualCareCount, 2);
      expect(
        h.core
            .listPlants(datasetId: id(1), archived: true)
            .page
            .items
            .single
            .plant
            .id,
        plant.id,
      );
      expect(
        h.core
            .getToday(datasetId: id(1), section: TodaySection.doneToday)
            .page
            .items,
        isEmpty,
      );
      expect(h.core.getReminderCandidates(datasetId: id(1)).items, isEmpty);
      final timeline = h.core.listTimeline(datasetId: id(1), plantId: plant.id);
      expect(timeline.items.whereType<CareTimelineEntry>().length, 2);
      expect(timeline.items.whereType<ScheduleTimelineEntry>().length, 2);
      h.confirm(
        h.preview(
          DeletePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      expect(
        () => h.core.getPlantDetail(datasetId: id(1), plantId: plant.id),
        rejected('NOT_FOUND'),
      );
      expect(
        () => h.core.getEvent(
          datasetId: id(1),
          eventId: timeline.items.whereType<CareTimelineEntry>().first.id,
        ),
        rejected('NOT_FOUND'),
      );
    },
  );

  test(
    'timeline sorts effective local date then original recording instant and ID',
    () {
      final h = Harness()..add(routines: [known()]);
      h.instant = DateTime.utc(2026, 10, 25, 13);
      final saved = h.confirm(
        h.preview(
          AddPastCare(h.target(), date('2026-10-10'), CareOutcome.actualCare),
        ),
      );
      var page = h.core.listTimeline(
        datasetId: id(1),
        plantId: h.target().plantId,
        limit: 1,
      );
      expect(page.items.single.date, date('2026-10-20'));
      final cursor = page.nextCursor!;
      h.confirm(
        h.preview(
          CorrectEvent(
            h.target(),
            eventId: saved.primaryId!,
            eventRevision: 1,
            careDate: date('2026-10-20'),
            outcome: CareOutcome.actualCare,
          ),
        ),
      );
      expect(
        () => h.core.listTimeline(
          datasetId: id(1),
          plantId: h.target().plantId,
          cursor: cursor,
        ),
        rejected('READ_STALE'),
      );
      page = h.core.listTimeline(datasetId: id(1), plantId: h.target().plantId);
      expect(page.items.first.id, saved.primaryId);
      final row = page.items.first as CareTimelineEntry;
      expect(row.corrected, isTrue);
      expect(row.event.original.careDate, date('2026-10-10'));
      expect(row.recordedAt, DateTime.utc(2026, 10, 25, 13));
      h.confirm(
        h.preview(
          VoidEvent(
            h.target(),
            eventId: row.id,
            eventRevision: row.event.revision,
          ),
        ),
      );
      expect(
        h.core
            .listTimeline(datasetId: id(1), plantId: h.target().plantId)
            .items
            .length,
        1,
      );
      expect(
        h.core
            .listTimeline(
              datasetId: id(1),
              plantId: h.target().plantId,
              includeVoided: true,
            )
            .items
            .length,
        2,
      );
    },
  );

  test('reads validate limits and return immutable items without mutation', () {
    final h = Harness()..add(routines: [known()]);
    final before = h.snapshot;
    for (final limit in [0, -1, 201]) {
      expect(
        () => h.core.listPlants(datasetId: id(1), limit: limit),
        rejected('FIELD_INVALID'),
      );
      expect(
        () => h.core.getToday(
          datasetId: id(1),
          section: TodaySection.upcoming,
          limit: limit,
        ),
        rejected('FIELD_INVALID'),
      );
    }
    final rows = h.core.getReminderCandidates(datasetId: id(1)).items;
    expect(rows.clear, throwsUnsupportedError);
    expect(h.snapshot, same(before));
  });

  test(
    'Today supports end of date range without overflowing a seven-day window',
    () {
      final h = Harness()..today = date('9999-12-31');
      h.add(routines: [unknown(day: '9999-12-31')]);
      expect(
        h.core
            .getToday(datasetId: id(1), section: TodaySection.today)
            .page
            .items
            .length,
        1,
      );
    },
  );
}
