part of 'collection.dart';

String _normalized(String value) => value.trim().toLowerCase();

/// Opaque, immutable keyset for the synthetic store. Native wire encoding is
/// separate; a cursor is not a grant to bypass current dataset/filter guards.
final class ReadCursor {
  final String _dataset;
  final int _revision;
  final LocalDate _date;
  final String _query;
  final String _lastKey;
  const ReadCursor._(
    this._dataset,
    this._revision,
    this._date,
    this._query,
    this._lastKey,
  );
}

class ReadPage<T> {
  final String datasetId;
  final int collectionRevision;
  final LocalDate asOfDate;
  final List<T> items;
  final ReadCursor? nextCursor;
  final int totalCount;
  ReadPage._(
    CollectionSnapshot snapshot,
    this.asOfDate,
    Iterable<T> items,
    this.nextCursor,
    this.totalCount,
  ) : datasetId = snapshot.datasetId,
      collectionRevision = snapshot.revision,
      items = List.unmodifiable(items);
}

final class PlantRow {
  final PlantCore plant;
  final LocalDate? nextCheckDate;
  final String? coverPhotoId;
  final int? coverPhotoRevision;
  const PlantRow._(
    this.plant,
    this.nextCheckDate,
    this.coverPhotoId,
    this.coverPhotoRevision,
  );
}

final class PlantsPage {
  final ReadPage<PlantRow> page;
  final int? activeCount;
  final bool? canAdd;
  const PlantsPage._(this.page, this.activeCount, this.canAdd);
}

final class RoutineRead {
  final PlantCore plant;
  final RoutineCore routine;
  final StandardCareKind careKind;
  final CareTarget target;
  RoutineRead._(this.plant, this.routine, this.careKind)
    : target = _readTarget(plant, routine);
  bool get canComplete =>
      !plant.archived &&
      !routine.archived &&
      routine.status == RoutineStatus.active;
  bool get canEditSchedule => routine.status != RoutineStatus.retired;
  bool get canAddPastCare => true;
  LocalDate? get latestActualCare => routine.latestActualCare;
  int get actualCareCount => routine.actualCareCount;
}

final class PlantDetail {
  final PlantCore plant;
  final List<RoutineRead> routines;
  final Map<String, SuggestionSnapshot> suggestions;
  final bool canRestore;
  PlantDetail._(
    this.plant,
    Iterable<RoutineRead> routines,
    this.canRestore,
    this.suggestions,
  ) : routines = List.unmodifiable(routines);
  bool get canArchive => !plant.archived;
  bool get canDelete => plant.archived;
  bool get canEdit => true;
}

sealed class TimelineEntry {
  final String id;
  final String plantId;
  final String? routineId;
  final LocalDate date;
  final DateTime recordedAt;
  const TimelineEntry._(
    this.id,
    this.plantId,
    this.routineId,
    this.date,
    this.recordedAt,
  );
}

final class JournalTimelineEntry extends TimelineEntry {
  final JournalEntry entry;
  JournalTimelineEntry._(this.entry)
    : super._(entry.id, entry.plantId, null, entry.entryDate, entry.createdAt);
}

final class CareTimelineEntry extends TimelineEntry {
  final CareEvent event;
  final StandardCareKind careKind;
  final String careLabel;
  CareTimelineEntry._(RoutineCore routine, this.event, this.careKind)
    : careLabel = routine.careLabel,
      super._(
        event.id,
        routine.plantId,
        routine.id,
        event.effective.careDate,
        event.recordedAt,
      );
  bool get corrected => event.corrections.isNotEmpty;
  bool get voided => event.effective.voided;
}

final class ScheduleTimelineEntry extends TimelineEntry {
  final ScheduleChange change;
  ScheduleTimelineEntry._(this.change)
    : super._(
        change.id,
        change.plantId,
        change.routineId,
        change.changeDate,
        change.changedAt,
      );
}

enum TodaySection { overdue, today, upcoming, doneToday }

sealed class TodayRow {
  final String plantName;
  final StandardCareKind careKind;
  final String careLabel;
  final String routineId;
  final LocalDate date;
  const TodayRow._(
    this.plantName,
    this.careKind,
    this.careLabel,
    this.routineId,
    this.date,
  );
  String get _stableId;
}

final class CheckRow extends TodayRow {
  final CareTarget target;
  final TodaySection section;
  final int overdueDays;
  CheckRow._(
    PlantCore plant,
    RoutineCore routine,
    StandardCareKind kind,
    LocalDate today,
  ) : target = _readTarget(plant, routine),
      section = routine.nextCheck.compareTo(today) < 0
          ? TodaySection.overdue
          : routine.nextCheck == today
          ? TodaySection.today
          : TodaySection.upcoming,
      overdueDays = routine.nextCheck.compareTo(today) < 0
          ? routine.nextCheck.daysUntil(today)
          : 0,
      super._(
        plant.name,
        kind,
        routine.careLabel,
        routine.id,
        routine.nextCheck,
      );
  LocalDate get nextCheckDate => date;
  @override
  String get _stableId => routineId;
}

final class DoneTodayRow extends TodayRow {
  final CareTimelineEntry care;
  DoneTodayRow._(PlantCore plant, this.care)
    : super._(
        plant.name,
        care.careKind,
        care.careLabel,
        care.routineId!,
        care.date,
      );
  @override
  String get _stableId => care.id;
}

final class TodaySummary {
  final int activePlantCount;
  final int eligibleCheckCount;
  final CheckRow? nextCheck;
  const TodaySummary._(
    this.activePlantCount,
    this.eligibleCheckCount,
    this.nextCheck,
  );
}

final class TodayPage {
  final ReadPage<TodayRow> page;
  final TodaySummary? summary;
  final Map<TodaySection, int> counts;
  TodayPage._(this.page, this.summary, Map<TodaySection, int> counts)
    : counts = Map.unmodifiable(counts);
}

CareTarget _readTarget(PlantCore plant, RoutineCore routine) => CareTarget(
  plantId: plant.id,
  plantRevision: plant.revision,
  routineId: routine.id,
  routineRevision: routine.revision,
  headId: routine.headId,
  headRevision: routine.headRevision,
);

int _compareToday(TodayRow a, TodayRow b) {
  for (final order in [
    a.date.compareTo(b.date),
    _normalized(a.plantName).compareTo(_normalized(b.plantName)),
    a.careKind.index.compareTo(b.careKind.index),
    _normalized(a.careLabel).compareTo(_normalized(b.careLabel)),
    a.routineId.compareTo(b.routineId),
    a._stableId.compareTo(b._stableId),
  ]) {
    if (order != 0) return order;
  }
  return 0;
}

String _todayKey(TodayRow r) => canonicalCommandJson({
  'date': r.date.toString(),
  'name': _normalized(r.plantName),
  'kind': r.careKind.index,
  'label': _normalized(r.careLabel),
  'routineId': r.routineId,
  'id': r._stableId,
});

extension CollectionReads on MemoryOperationCoordinator {
  ReadPage<T> _page<T>(
    CollectionSnapshot snapshot,
    LocalDate today,
    List<T> sorted,
    String query,
    String Function(T) key,
    int limit,
    ReadCursor? cursor,
  ) {
    if (limit < 1 || limit > 200) throw CommandRejected('FIELD_INVALID');
    var start = 0;
    if (cursor != null) {
      if (cursor._dataset != snapshot.datasetId ||
          cursor._revision != snapshot.revision ||
          cursor._date != today ||
          cursor._query != query)
        throw CommandRejected('READ_STALE');
      final last = sorted.indexWhere((row) => key(row) == cursor._lastKey);
      if (last < 0) throw CommandRejected('READ_STALE');
      start = last + 1;
    }
    final selected = sorted.skip(start).take(limit).toList();
    final next = start + selected.length < sorted.length
        ? ReadCursor._(
            snapshot.datasetId,
            snapshot.revision,
            today,
            query,
            key(selected.last),
          )
        : null;
    return ReadPage._(snapshot, today, selected, next, sorted.length);
  }

  PlantsPage listPlants({
    required String datasetId,
    bool archived = false,
    String query = '',
    int limit = 50,
    ReadCursor? cursor,
  }) {
    final snapshot = readCollection(datasetId: datasetId);
    final today = _clock().care.today;
    final search = _normalized(query);
    if (!_validUnicode(query)) throw CommandRejected('FIELD_INVALID');
    final nextDates = <String, LocalDate>{};
    for (final routine in snapshot.eligibleRoutines) {
      nextDates.putIfAbsent(routine.plantId, () => routine.nextCheck);
    }
    final rows =
        snapshot.plants.values
            .where(
              (p) =>
                  p.archived == archived &&
                  [
                    p.name,
                    p.location,
                    p.speciesName,
                  ].any((s) => _normalized(s).contains(search)),
            )
            .map((plant) {
              return PlantRow._(
                plant,
                nextDates[plant.id],
                snapshot.covers[plant.id],
                snapshot.photos[snapshot.covers[plant.id]]?.revision,
              );
            })
            .toList()
          ..sort((a, b) {
            final order = _normalized(
              a.plant.name,
            ).compareTo(_normalized(b.plant.name));
            return order == 0 ? a.plant.id.compareTo(b.plant.id) : order;
          });
    final page = _page(
      snapshot,
      today,
      rows,
      canonicalCommandJson({
        'read': 'plants',
        'archived': archived,
        'query': search,
      }),
      (r) => canonicalCommandJson({
        'name': _normalized(r.plant.name),
        'id': r.plant.id,
      }),
      limit,
      cursor,
    );
    return PlantsPage._(
      page,
      cursor == null ? snapshot.activePlants.length : null,
      cursor == null ? _store._pro || snapshot.activePlants.length < 5 : null,
    );
  }

  RoutineRead getRoutine({
    required String datasetId,
    required String routineId,
  }) {
    _id(routineId);
    final snapshot = readCollection(datasetId: datasetId);
    final routine = snapshot.routines[routineId];
    if (routine == null) throw CommandRejected('NOT_FOUND');
    return RoutineRead._(
      snapshot.plants[routine.plantId]!,
      routine,
      snapshot.careKinds[routine.id]!,
    );
  }

  PlantDetail getPlantDetail({
    required String datasetId,
    required String plantId,
  }) {
    _id(plantId);
    final snapshot = readCollection(datasetId: datasetId);
    final plant = snapshot.plants[plantId];
    if (plant == null) throw CommandRejected('NOT_FOUND');
    final rows =
        snapshot.routines.values.where((r) => r.plantId == plantId).toList()
          ..sort((a, b) {
            final order = snapshot.careKinds[a.id]!.index.compareTo(
              snapshot.careKinds[b.id]!.index,
            );
            return order == 0 ? a.id.compareTo(b.id) : order;
          });
    return PlantDetail._(
      plant,
      rows.map((r) => RoutineRead._(plant, r, snapshot.careKinds[r.id]!)),
      plant.archived && (_store._pro || snapshot.activePlants.length < 5),
      Map.unmodifiable({
        for (final entry in snapshot.suggestions.entries)
          if (entry.value.plantId == plant.id) entry.key: entry.value,
      }),
    );
  }

  CareTimelineEntry getEvent({
    required String datasetId,
    required String eventId,
  }) {
    _id(eventId);
    final snapshot = readCollection(datasetId: datasetId);
    for (final routine in snapshot.routines.values) {
      final event = routine.events.where((e) => e.id == eventId).firstOrNull;
      if (event != null)
        return CareTimelineEntry._(
          routine,
          event,
          snapshot.careKinds[routine.id]!,
        );
    }
    throw CommandRejected('NOT_FOUND');
  }

  ReadPage<TimelineEntry> listTimeline({
    required String datasetId,
    required String plantId,
    bool includeVoided = false,
    int limit = 50,
    ReadCursor? cursor,
  }) {
    _id(plantId);
    final snapshot = readCollection(datasetId: datasetId);
    if (!snapshot.plants.containsKey(plantId))
      throw CommandRejected('NOT_FOUND');
    final rows =
        <TimelineEntry>[
          for (final entry in snapshot.journalEntries.values.where(
            (e) => e.plantId == plantId,
          ))
            JournalTimelineEntry._(entry),
          for (final routine in snapshot.routines.values.where(
            (r) => r.plantId == plantId,
          ))
            for (final event in routine.events)
              if (includeVoided || !event.effective.voided)
                CareTimelineEntry._(
                  routine,
                  event,
                  snapshot.careKinds[routine.id]!,
                ),
          for (final change in snapshot.scheduleChanges.values.where(
            (c) => c.plantId == plantId,
          ))
            ScheduleTimelineEntry._(change),
        ]..sort((a, b) {
          final dateOrder = b.date.compareTo(a.date);
          if (dateOrder != 0) return dateOrder;
          final timeOrder = b.recordedAt.compareTo(a.recordedAt);
          return timeOrder == 0 ? b.id.compareTo(a.id) : timeOrder;
        });
    return _page(
      snapshot,
      _clock().care.today,
      rows,
      canonicalCommandJson({
        'read': 'timeline',
        'plantId': plantId,
        'includeVoided': includeVoided,
      }),
      (r) => canonicalCommandJson({
        'date': r.date.toString(),
        'time': r.recordedAt.toIso8601String(),
        'id': r.id,
      }),
      limit,
      cursor,
    );
  }

  TodayPage getToday({
    required String datasetId,
    required TodaySection section,
    StandardCareKind? careKind,
    int limit = 50,
    ReadCursor? cursor,
  }) {
    final snapshot = readCollection(datasetId: datasetId);
    final today = _clock().care.today;
    final heads =
        snapshot.eligibleRoutines
            .map(
              (r) => CheckRow._(
                snapshot.plants[r.plantId]!,
                r,
                snapshot.careKinds[r.id]!,
                today,
              ),
            )
            .toList()
          ..sort(_compareToday);
    final bySection = {for (final s in TodaySection.values) s: <TodayRow>[]};
    for (final row in heads) {
      if ((careKind == null || row.careKind == careKind) &&
          today.daysUntil(row.date) <= 7) {
        bySection[row.section]!.add(row);
      }
    }
    // Done today is history rather than eligibility: a paused/retired routine's
    // real care remains correctable. Archived plants stay out of Today.
    for (final routine in snapshot.routines.values.where(
      (r) => !snapshot.plants[r.plantId]!.archived,
    )) {
      final kind = snapshot.careKinds[routine.id]!;
      if (careKind != null && kind != careKind) continue;
      for (final event in routine.events) {
        if (!event.effective.voided &&
            event.effective.outcome == CareOutcome.actualCare &&
            event.effective.careDate == today) {
          bySection[TodaySection.doneToday]!.add(
            DoneTodayRow._(
              snapshot.plants[routine.plantId]!,
              CareTimelineEntry._(routine, event, kind),
            ),
          );
        }
      }
    }
    bySection[TodaySection.doneToday]!.sort(_compareToday);
    return TodayPage._(
      _page(
        snapshot,
        today,
        bySection[section]!,
        canonicalCommandJson({
          'read': 'today',
          'section': section.name,
          'kind': careKind?.name,
        }),
        _todayKey,
        limit,
        cursor,
      ),
      cursor == null
          ? TodaySummary._(
              snapshot.activePlants.length,
              heads.length,
              heads.firstOrNull,
            )
          : null,
      {for (final s in TodaySection.values) s: bySection[s]!.length},
    );
  }

  ReadPage<CheckRow> getReminderCandidates({required String datasetId}) {
    final snapshot = readCollection(datasetId: datasetId);
    final today = _clock().care.today;
    final rows =
        snapshot.eligibleRoutines
            .map(
              (r) => CheckRow._(
                snapshot.plants[r.plantId]!,
                r,
                snapshot.careKinds[r.id]!,
                today,
              ),
            )
            .toList()
          ..sort(_compareToday);
    return ReadPage._(snapshot, today, rows, null, rows.length);
  }
}
