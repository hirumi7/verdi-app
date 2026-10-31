part of 'care.dart';

/// Lossless stored construction, deliberately separate from new-care validation.
/// Past dates/retired state are not re-seeded against today's clock.
abstract final class CareStorage {
  static RoutineCore hydrate({
    required List<Object?> routine,
    required List<Object?> head,
    required bool archived,
    required List<List<Object?>> events,
    required List<List<Object?>> corrections,
  }) {
    if (routine.length != 13 || head.length != 5 || head[1] != routine[0]) {
      throw const DomainException('STORAGE_INVALID');
    }
    for (final id in [routine[0], routine[1], head[0]]) {
      _id(id as String);
    }
    for (final n in [routine[2], head[2]]) {
      if (n is! int || n < 1 || n > _maxRevision)
        throw const DomainException('STORAGE_INVALID');
    }
    final parsed = <CareEvent>[];
    final seen = <String>{};
    for (final row in events) {
      if (row.length != 11 ||
          row[1] != routine[1] ||
          row[2] != routine[0] ||
          row[4] != routine[3] ||
          row[5] != routine[4])
        throw const DomainException('STORAGE_INVALID');
      final id = row[0] as String;
      _id(id);
      _id(row[10] as String);
      if (!seen.add(id)) throw const DomainException('STORAGE_INVALID');
      final original = EventValues(
        LocalDate.parse(row[6] as String),
        outcome(row[7] as String),
      );
      var prior = original;
      final chain = <EventCorrection>[];
      final owned = corrections.where((r) => r[1] == id).toList()
        ..sort((a, b) => (a[2] as int).compareTo(b[2] as int));
      for (final c in owned) {
        if (c.length != 12 || c[2] != chain.length + 1)
          throw const DomainException('STORAGE_INVALID');
        _id(c[0] as String);
        _id(c[10] as String);
        final before = EventValues(
          LocalDate.parse(c[3] as String),
          outcome(c[4] as String),
          voided: flag(c[5]),
        );
        final after = EventValues(
          LocalDate.parse(c[6] as String),
          outcome(c[7] as String),
          voided: flag(c[8]),
        );
        if (before.careDate != prior.careDate ||
            before.outcome != prior.outcome ||
            before.voided != prior.voided) {
          throw const DomainException('STORAGE_INVALID');
        }
        chain.add(
          EventCorrection._(
            c[0] as String,
            c[10] as String,
            before,
            after,
            instant(c[9]),
            c[11] as String,
          ),
        );
        prior = after;
      }
      if (row[3] != chain.length + 1 || (row[9] as String).isEmpty)
        throw const DomainException('STORAGE_INVALID');
      parsed.add(
        CareEvent._(
          id,
          row[10] as String,
          original,
          instant(row[8]),
          row[9] as String,
          row[3] as int,
          chain,
        ),
      );
    }
    final label = routine[4] as String;
    if (label.isEmpty) throw const DomainException('STORAGE_INVALID');
    return RoutineCore._(
      id: routine[0] as String,
      plantId: routine[1] as String,
      headId: head[0] as String,
      careLabel: label,
      revision: routine[2] as int,
      headRevision: head[2] as int,
      interval: CareInterval(
        routine[6] as int,
        IntervalUnit.values.byName(routine[7] as String),
      ),
      anchor: LocalDate.parse(routine[8] as String),
      firstCheckAnchor: flag(routine[9]),
      firstCheckDate: date(routine[10]),
      nextCheck: LocalDate.parse(head[3] as String),
      overrideDate: date(head[4]),
      status: RoutineStatus.values.byName(routine[5] as String),
      archived: archived,
      events: parsed,
    );
  }

  static bool flag(Object? value) {
    if (value != 0 && value != 1)
      throw const DomainException('STORAGE_INVALID');
    return value == 1;
  }

  static LocalDate? date(Object? value) =>
      value == null ? null : LocalDate.parse(value as String);
  static DateTime instant(Object? value) {
    final parsed = DateTime.parse(value as String);
    if (!parsed.isUtc || parsed.toIso8601String() != value)
      throw const DomainException('STORAGE_INVALID');
    return parsed;
  }

  static CareOutcome outcome(String value) => switch (value) {
    'actual_care' => CareOutcome.actualCare,
    'checked_not_needed' => CareOutcome.checkedNotNeeded,
    'skipped' => CareOutcome.skipped,
    _ => throw const DomainException('STORAGE_INVALID'),
  };
}
