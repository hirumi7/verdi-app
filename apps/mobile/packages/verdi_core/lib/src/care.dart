import 'calendar.dart';
import 'errors.dart';

part 'care_storage.dart';

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

/// Value-only rollback capture: never duplicates plant text or historical rows.
final class RoutineUndoValues {
  final String routineId;
  final String headId;
  final CareInterval interval;
  final LocalDate anchor;
  final bool firstCheckAnchor;
  final LocalDate? firstCheckDate;
  final LocalDate nextCheck;
  final LocalDate? overrideDate;
  final RoutineStatus status;
  final bool archived;
  RoutineUndoValues(RoutineCore r)
    : routineId = r.id,
      headId = r.headId,
      interval = r.interval,
      anchor = r.anchor,
      firstCheckAnchor = r.firstCheckAnchor,
      firstCheckDate = r.firstCheckDate,
      nextCheck = r.nextCheck,
      overrideDate = r.overrideDate,
      status = r.status,
      archived = r.archived;
}

/// Immutable per-routine state for the first domain slice, not a persisted DTO.
/// New routines use seed factories; CareStorage hydrates existing facts directly.
/// Commands produce new values; native transactions own durable saves.
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
  final String? originalSuggestionId, appliedSuggestionId;

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
    this.originalSuggestionId,
    this.appliedSuggestionId,
  }) : events = List.unmodifiable(events);

  /// Storage/selection metadata; no care or revision is fabricated.
  RoutineCore withSuggestions(String? original, String? applied) =>
      RoutineCore._(
        id: id,
        plantId: plantId,
        headId: headId,
        careLabel: careLabel,
        revision: revision,
        headRevision: headRevision,
        interval: interval,
        anchor: anchor,
        firstCheckAnchor: firstCheckAnchor,
        firstCheckDate: firstCheckDate,
        nextCheck: nextCheck,
        overrideDate: overrideDate,
        status: status,
        archived: archived,
        events: events,
        originalSuggestionId: original,
        appliedSuggestionId: applied,
      );

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
    CareInterval? interval,
    LocalDate? anchor,
    bool? firstCheckAnchor,
    LocalDate? firstCheckDate,
    LocalDate? nextCheck,
    LocalDate? overrideDate,
    bool replaceOverride = false,
    Iterable<CareEvent>? events,
    bool headChanged = false,
    RoutineStatus? status,
    bool? archived,
  }) => RoutineCore._(
    id: id,
    plantId: plantId,
    headId: headId,
    careLabel: careLabel,
    revision: _increment(revision),
    headRevision: headChanged ? _increment(headRevision) : headRevision,
    interval: interval ?? this.interval,
    anchor: anchor ?? this.anchor,
    firstCheckAnchor: firstCheckAnchor ?? this.firstCheckAnchor,
    firstCheckDate: firstCheckDate ?? this.firstCheckDate,
    nextCheck: nextCheck ?? this.nextCheck,
    overrideDate: replaceOverride ? overrideDate : this.overrideDate,
    status: status ?? this.status,
    archived: archived ?? this.archived,
    events: events ?? this.events,
    originalSuggestionId: originalSuggestionId,
    appliedSuggestionId: appliedSuggestionId,
  );

  void _editable() {
    if (status == RoutineStatus.retired) {
      throw const DomainException('NOT_ELIGIBLE');
    }
  }

  /// Changing an interval is explicit; historical additions never call this.
  RoutineCore setInterval(
    CareInterval value,
    CareClock clock, {
    LocalDate? chosenFirstCheck,
  }) {
    _editable();
    if (overrideDate != null) return _next(interval: value);
    return _recalculate(
      value,
      clock,
      chosenFirstCheck: chosenFirstCheck,
      requireChosenFirstCheck: false,
    );
  }

  RoutineCore clearOverride(CareClock clock, {LocalDate? chosenFirstCheck}) {
    _editable();
    return _recalculate(
      interval,
      clock,
      chosenFirstCheck: chosenFirstCheck,
      requireChosenFirstCheck: true,
    );
  }

  RoutineCore _recalculate(
    CareInterval value,
    CareClock clock, {
    LocalDate? chosenFirstCheck,
    required bool requireChosenFirstCheck,
  }) {
    final latest = latestActualCare;
    if (latest != null) {
      final candidate = addInterval(latest, value);
      final head = candidate.compareTo(clock.today) < 0
          ? clock.today
          : candidate;
      return _next(
        interval: value,
        anchor: latest,
        firstCheckAnchor: false,
        nextCheck: head,
        replaceOverride: true,
        headChanged: head != nextCheck || overrideDate != null,
      );
    }
    final first = requireChosenFirstCheck
        ? chosenFirstCheck
        : firstCheckDate ?? chosenFirstCheck;
    if (first == null) throw const DomainException('FIRST_CHECK_REQUIRED');
    return _next(
      interval: value,
      anchor: first,
      firstCheckAnchor: true,
      firstCheckDate: first,
      nextCheck: first,
      replaceOverride: true,
      headChanged: first != nextCheck || overrideDate != null,
    );
  }

  RoutineCore pause() {
    _active();
    return _next(status: RoutineStatus.paused, headChanged: true);
  }

  RoutineCore resume(CareClock clock) {
    if (archived || status != RoutineStatus.paused) {
      throw const DomainException('NOT_ELIGIBLE');
    }
    final head = nextCheck.compareTo(clock.today) < 0 ? clock.today : nextCheck;
    return _next(
      status: RoutineStatus.active,
      nextCheck: head,
      overrideDate: overrideDate == null ? null : head,
      replaceOverride: true,
      headChanged: true,
    );
  }

  RoutineCore retire() {
    _editable();
    return _next(status: RoutineStatus.retired, headChanged: true);
  }

  /// Collection-owned lifecycle propagation. Retired heads never resume/clamp.
  RoutineCore archive() {
    if (archived) throw const DomainException('NOT_ELIGIBLE');
    return _next(archived: true, headChanged: true);
  }

  RoutineCore restore(CareClock clock) {
    if (!archived) throw const DomainException('NOT_ELIGIBLE');
    if (status == RoutineStatus.retired) {
      return _next(archived: false, headChanged: true);
    }
    final head = nextCheck.compareTo(clock.today) < 0 ? clock.today : nextCheck;
    return _next(
      archived: false,
      nextCheck: head,
      overrideDate: overrideDate == null ? null : head,
      replaceOverride: true,
      headChanged: true,
    );
  }

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

  /// The coordinator supplies the session/deadline/all-member guard. The domain
  /// additionally checks identity, revision and event-command ownership.
  RoutineCore undoTo(
    RoutineUndoValues before, {
    required int expectedRevision,
    required String originalCommandId,
    required String commandId,
    required Map<String, String> correctionIds,
    required CareClock clock,
  }) {
    _id(commandId);
    _id(originalCommandId);
    if (before.routineId != id ||
        before.headId != headId ||
        expectedRevision != revision)
      throw const DomainException('UNDO_CHANGED');
    if (correctionIds.values.toSet().length != correctionIds.length) {
      throw const DomainException('FIELD_INVALID');
    }
    for (final entry in correctionIds.entries) {
      _newId(entry.value);
      final event = events.where((e) => e.id == entry.key).firstOrNull;
      if (event == null ||
          event.commandId != originalCommandId ||
          event.effective.voided) {
        throw const DomainException('UNDO_CHANGED');
      }
    }
    final revised = events.map((event) {
      final correctionId = correctionIds[event.id];
      if (correctionId == null) return event;
      return event._correct(
        EventCorrection._(
          correctionId,
          commandId,
          event.effective,
          EventValues(
            event.effective.careDate,
            event.effective.outcome,
            voided: true,
          ),
          clock.instant,
          'undo',
        ),
      );
    });
    return RoutineCore._(
      id: id,
      plantId: plantId,
      headId: headId,
      careLabel: careLabel,
      revision: _increment(revision),
      headRevision:
          nextCheck != before.nextCheck ||
              overrideDate != before.overrideDate ||
              status != before.status ||
              archived != before.archived
          ? _increment(headRevision)
          : headRevision,
      interval: before.interval,
      anchor: before.anchor,
      firstCheckAnchor: before.firstCheckAnchor,
      firstCheckDate: before.firstCheckDate,
      nextCheck: before.nextCheck,
      overrideDate: before.overrideDate,
      status: before.status,
      archived: before.archived,
      events: revised,
      originalSuggestionId: originalSuggestionId,
      appliedSuggestionId: appliedSuggestionId,
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
