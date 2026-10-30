import 'calendar.dart';
import 'errors.dart';

enum CareOutcome { actualCare, checkedNotNeeded, skipped }

enum RoutineStatus { active, paused, retired }

const _maxRevision = 9007199254740991;
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

void _id(String value) {
  if (!_uuid.hasMatch(value)) throw const DomainException('FIELD_INVALID');
}

int _increment(int revision) {
  if (revision < 1 || revision >= _maxRevision) {
    throw const DomainException('FIELD_INVALID');
  }
  return revision + 1;
}

/// Injected context. Production will obtain this at native transaction entry.
/// No device time zone is used to reinterpret [today] or historical care dates.
final class CareClock {
  final LocalDate today;
  final DateTime instant;
  final String zone;

  CareClock(this.today, this.instant, this.zone) {
    if (!instant.isUtc || zone.isEmpty) {
      throw const DomainException('FIELD_INVALID');
    }
  }
}

final class EventValues {
  final LocalDate careDate;
  final CareOutcome outcome;
  final bool voided;
  const EventValues(this.careDate, this.outcome, {this.voided = false});
}

final class EventCorrection {
  final String id;
  final String commandId;
  final EventValues before;
  final EventValues after;
  final DateTime correctedAt;
  final String reason;

  const EventCorrection._(
    this.id,
    this.commandId,
    this.before,
    this.after,
    this.correctedAt,
    this.reason,
  );
}

final class CareEvent {
  final String id;
  final String commandId;
  final EventValues original;
  final DateTime recordedAt;
  final String recordedZone;
  final int revision;
  final List<EventCorrection> corrections;

  CareEvent._(
    this.id,
    this.commandId,
    this.original,
    this.recordedAt,
    this.recordedZone,
    this.revision,
    Iterable<EventCorrection> corrections,
  ) : corrections = List.unmodifiable(corrections);

  EventValues get effective =>
      corrections.isEmpty ? original : corrections.last.after;

  CareEvent _correct(EventCorrection correction) => CareEvent._(
    id,
    commandId,
    original,
    recordedAt,
    recordedZone,
    _increment(revision),
    [...corrections, correction],
  );
}

/// Immutable per-routine state for the first domain slice, not a persisted DTO.
/// Only the named seed factories can construct it. Commands produce new values;
/// callers must eventually use the guarded native transaction protocol to save.
final class RoutineCore {
  final String id;
  final String plantId;
  final String headId;
  final String careLabel;
  final int revision;
  final int headRevision;
  final CareInterval interval;
  final LocalDate anchor;
  final bool firstCheckAnchor;
  final LocalDate? firstCheckDate;
  final LocalDate nextCheck;
  final LocalDate? overrideDate;
  final RoutineStatus status;
  final bool archived;
  final List<CareEvent> events;

  RoutineCore._({
    required this.id,
    required this.plantId,
    required this.headId,
    required this.careLabel,
    required this.revision,
    required this.headRevision,
    required this.interval,
    required this.anchor,
    required this.firstCheckAnchor,
    required this.firstCheckDate,
    required this.nextCheck,
    required this.overrideDate,
    required this.status,
    required this.archived,
    required Iterable<CareEvent> events,
  }) : events = List.unmodifiable(events);

  factory RoutineCore.unknown({
    required String id,
    required String plantId,
    required String headId,
    required String careLabel,
    required CareInterval interval,
    required LocalDate firstCheck,
  }) {
    for (final value in [id, plantId, headId]) {
      _id(value);
    }
    if ({id, plantId, headId}.length != 3 || careLabel.trim().isEmpty) {
      throw const DomainException('FIELD_INVALID');
    }
    return RoutineCore._(
      id: id,
      plantId: plantId,
      headId: headId,
      careLabel: careLabel,
      revision: 1,
      headRevision: 1,
      interval: interval,
      anchor: firstCheck,
      firstCheckAnchor: true,
      firstCheckDate: firstCheck,
      nextCheck: firstCheck,
      overrideDate: null,
      status: RoutineStatus.active,
      archived: false,
      events: [],
    );
  }

  factory RoutineCore.known({
    required String id,
    required String plantId,
    required String headId,
    required String careLabel,
    required CareInterval interval,
    required LocalDate careDate,
    required String eventId,
    required String commandId,
    required CareClock clock,
  }) {
    final seed = RoutineCore.unknown(
      id: id,
      plantId: plantId,
      headId: headId,
      careLabel: careLabel,
      interval: interval,
      firstCheck: careDate,
    );
    final event = seed._event(
      eventId,
      commandId,
      careDate,
      CareOutcome.actualCare,
      clock,
    );
    final candidate = addInterval(careDate, interval);
    return RoutineCore._(
      id: id,
      plantId: plantId,
      headId: headId,
      careLabel: careLabel,
      revision: 1,
      headRevision: 1,
      interval: interval,
      anchor: careDate,
      firstCheckAnchor: false,
      firstCheckDate: null,
      nextCheck: candidate.compareTo(clock.today) < 0 ? clock.today : candidate,
      overrideDate: null,
      status: RoutineStatus.active,
      archived: false,
      events: [event],
    );
  }

  int get actualCareCount => events
      .where(
        (event) =>
            !event.effective.voided &&
            event.effective.outcome == CareOutcome.actualCare,
      )
      .length;

  LocalDate? get latestActualCare {
    LocalDate? latest;
    for (final event in events) {
      final value = event.effective;
      if (!value.voided &&
          value.outcome == CareOutcome.actualCare &&
          (latest == null || value.careDate.compareTo(latest) > 0)) {
        latest = value.careDate;
      }
    }
    return latest;
  }

  void _active() {
    if (archived || status != RoutineStatus.active) {
      throw const DomainException('NOT_ELIGIBLE');
    }
  }

  void _past(LocalDate date, CareClock clock) {
    if (date.compareTo(clock.today) > 0) {
      throw const DomainException('FUTURE_CARE_DATE');
    }
  }

  void _newId(String value) {
    _id(value);
    if ([id, plantId, headId].contains(value) ||
        events.any(
          (e) => e.id == value || e.corrections.any((c) => c.id == value),
        )) {
      throw const DomainException('FIELD_INVALID');
    }
  }

  CareEvent _event(
    String eventId,
    String commandId,
    LocalDate date,
    CareOutcome outcome,
    CareClock clock,
  ) {
    _newId(eventId);
    _id(commandId);
    _past(date, clock);
    return CareEvent._(
      eventId,
      commandId,
      EventValues(date, outcome),
      clock.instant,
      clock.zone,
      1,
      [],
    );
  }

  RoutineCore _next({
    LocalDate? anchor,
    bool? firstCheckAnchor,
    LocalDate? nextCheck,
    LocalDate? overrideDate,
    bool replaceOverride = false,
    Iterable<CareEvent>? events,
    bool headChanged = false,
  }) => RoutineCore._(
    id: id,
    plantId: plantId,
    headId: headId,
    careLabel: careLabel,
    revision: _increment(revision),
    headRevision: headChanged ? _increment(headRevision) : headRevision,
    interval: interval,
    anchor: anchor ?? this.anchor,
    firstCheckAnchor: firstCheckAnchor ?? this.firstCheckAnchor,
    firstCheckDate: firstCheckDate,
    nextCheck: nextCheck ?? this.nextCheck,
    overrideDate: replaceOverride ? overrideDate : this.overrideDate,
    status: status,
    archived: archived,
    events: events ?? this.events,
  );

  RoutineCore complete({
    required LocalDate careDate,
    required String eventId,
    required String commandId,
    required CareClock clock,
  }) {
    _active();
    _past(careDate, clock);
    final latest = latestActualCare;
    if (latest != null && careDate.compareTo(latest) < 0) {
      throw const DomainException('CARE_PRECEDES_LATEST');
    }
    final candidate = addInterval(careDate, interval);
    final head = candidate.compareTo(clock.today) < 0 ? clock.today : candidate;
    final event = _event(
      eventId,
      commandId,
      careDate,
      CareOutcome.actualCare,
      clock,
    );
    return _next(
      anchor: careDate,
      firstCheckAnchor: false,
      nextCheck: head,
      replaceOverride: true,
      events: [...events, event],
      headChanged: head != nextCheck || overrideDate != null,
    );
  }

  RoutineCore addPast({
    required LocalDate careDate,
    required CareOutcome outcome,
    required String eventId,
    required String commandId,
    required CareClock clock,
  }) {
    final event = _event(eventId, commandId, careDate, outcome, clock);
    return _next(events: [...events, event]);
  }

  RoutineCore correct({
    required String eventId,
    required int eventRevision,
    required String correctionId,
    required String commandId,
    required LocalDate careDate,
    required CareOutcome outcome,
    required CareClock clock,
    bool restore = false,
  }) {
    _past(careDate, clock);
    final event = _findEvent(eventId, eventRevision);
    if (event.effective.voided != restore) {
      throw const DomainException('NOT_ELIGIBLE');
    }
    return _correction(
      event,
      EventValues(careDate, outcome),
      correctionId,
      commandId,
      clock,
      'correction',
    );
  }

  RoutineCore voidEvent({
    required String eventId,
    required int eventRevision,
    required String correctionId,
    required String commandId,
    required CareClock clock,
  }) {
    final event = _findEvent(eventId, eventRevision);
    if (event.effective.voided) throw const DomainException('NOT_ELIGIBLE');
    return _correction(
      event,
      EventValues(
        event.effective.careDate,
        event.effective.outcome,
        voided: true,
      ),
      correctionId,
      commandId,
      clock,
      'void',
    );
  }

  CareEvent _findEvent(String eventId, int expectedRevision) {
    final matches = events.where((e) => e.id == eventId);
    if (matches.isEmpty) throw const DomainException('NOT_FOUND');
    final event = matches.single;
    if (event.revision != expectedRevision)
      throw const DomainException('STALE_TARGET');
    return event;
  }

  RoutineCore _correction(
    CareEvent event,
    EventValues after,
    String correctionId,
    String commandId,
    CareClock clock,
    String reason,
  ) {
    _newId(correctionId);
    _id(commandId);
    final correction = EventCorrection._(
      correctionId,
      commandId,
      event.effective,
      after,
      clock.instant,
      reason,
    );
    return _next(
      events: events.map((e) => e.id == event.id ? e._correct(correction) : e),
    );
  }

  RoutineCore checkNotNeeded({
    required LocalDate checkDate,
    required LocalDate nextDate,
    required String eventId,
    required String commandId,
    required CareClock clock,
  }) {
    _active();
    final event = _event(
      eventId,
      commandId,
      checkDate,
      CareOutcome.checkedNotNeeded,
      clock,
    );
    // Explicit past next dates are permitted; they remain overdue.
    return _next(
      nextCheck: nextDate,
      overrideDate: nextDate,
      replaceOverride: true,
      headChanged: nextDate != nextCheck || nextDate != overrideDate,
      events: [...events, event],
    );
  }

  RoutineCore snooze(LocalDate nextDate, CareClock clock) {
    _active();
    if (nextDate.compareTo(clock.today) < 0)
      throw const DomainException('FIELD_INVALID');
    return _next(
      nextCheck: nextDate,
      overrideDate: nextDate,
      replaceOverride: true,
      headChanged: nextDate != nextCheck || nextDate != overrideDate,
    );
  }

  RoutineCore skip({
    required String eventId,
    required String commandId,
    required CareClock clock,
  }) {
    _active();
    final head = nextCadence(
      anchor,
      interval,
      clock.today,
      firstCheckAnchor: firstCheckAnchor,
    );
    final event = _event(
      eventId,
      commandId,
      clock.today,
      CareOutcome.skipped,
      clock,
    );
    return _next(
      nextCheck: head,
      replaceOverride: true,
      headChanged: head != nextCheck || overrideDate != null,
      events: [...events, event],
    );
  }
}
