import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
LocalDate date(String text) => LocalDate.parse(text);
CareClock clock(String today, {String zone = 'Asia/Jakarta'}) =>
    CareClock(date(today), DateTime.utc(2026, 10, 25, 12), zone);
Matcher error(String code) =>
    throwsA(isA<DomainException>().having((e) => e.code, 'code', code));

RoutineCore unknown({CareInterval? interval, String first = '2026-10-27'}) =>
    RoutineCore.unknown(
      id: id(1),
      plantId: id(2),
      headId: id(3),
      careLabel: 'Water',
      interval: interval ?? CareInterval(1, IntervalUnit.week),
      firstCheck: date(first),
    );

RoutineCore known() => RoutineCore.known(
  id: id(1),
  plantId: id(2),
  headId: id(3),
  careLabel: 'Water',
  interval: CareInterval(1, IntervalUnit.week),
  careDate: date('2026-10-20'),
  eventId: id(10),
  commandId: id(110),
  clock: clock('2026-10-25'),
);

void main() {
  test('unknown seed has one chosen head and no manufactured history', () {
    final value = unknown(first: '2026-01-01');
    expect(value.events, isEmpty);
    expect(value.latestActualCare, isNull);
    expect(value.nextCheck, date('2026-01-01'));
    expect(value.firstCheckAnchor, isTrue);
  });

  test('known seed records actual date independently of UTC entry time', () {
    final value = known();
    expect(value.firstCheckDate, isNull);
    expect(value.events.single.original.careDate, date('2026-10-20'));
    expect(value.events.single.recordedAt, DateTime.utc(2026, 10, 25, 12));
    expect(value.events.single.recordedZone, 'Asia/Jakarta');
    expect(value.nextCheck, date('2026-10-27'));
    expect(value.revision, 1);
  });

  test('CARE-04 earlier completion rejects without modifying original', () {
    final value = known();
    expect(
      () => value.complete(
        careDate: date('2026-10-10'),
        eventId: id(11),
        commandId: id(111),
        clock: clock('2026-10-25'),
      ),
      error('CARE_PRECEDES_LATEST'),
    );
    expect(value.events.length, 1);
    expect(value.nextCheck, date('2026-10-27'));
    final past = value.addPast(
      careDate: date('2026-10-10'),
      outcome: CareOutcome.actualCare,
      eventId: id(11),
      commandId: id(111),
      clock: clock('2026-10-25'),
    );
    expect(past.latestActualCare, date('2026-10-20'));
    expect(past.nextCheck, value.nextCheck);
    expect(past.headRevision, value.headRevision);
    expect(past.anchor, value.anchor);
    expect(past.events.length, 2);
  });

  test('latest history-only addition changes facts not anchor or override', () {
    final value = known().snooze(date('2026-11-01'), clock('2026-10-25'));
    final past = value.addPast(
      careDate: date('2026-10-24'),
      outcome: CareOutcome.actualCare,
      eventId: id(11),
      commandId: id(111),
      clock: clock('2026-10-25'),
    );
    expect(past.latestActualCare, date('2026-10-24'));
    expect(past.nextCheck, value.nextCheck);
    expect(past.overrideDate, value.overrideDate);
    expect(past.anchor, value.anchor);
    expect(past.headRevision, value.headRevision);
  });

  test(
    'completion uses actual date plus interval, clamps overdue to today',
    () {
      final value = unknown().complete(
        careDate: date('2026-10-01'),
        eventId: id(10),
        commandId: id(110),
        clock: clock('2026-10-25'),
      );
      expect(value.nextCheck, date('2026-10-25'));
      expect(value.anchor, date('2026-10-01'));
      expect(value.latestActualCare, date('2026-10-01'));
      expect(
        value.firstCheckDate,
        date('2026-10-27'),
      ); // retained seed, not cadence
      expect(value.firstCheckAnchor, isFalse);
    },
  );

  test('completion consumes override and preserves stable head identity', () {
    final original = known().snooze(date('2026-12-01'), clock('2026-10-25'));
    final value = original.complete(
      careDate: date('2026-10-25'),
      eventId: id(11),
      commandId: id(111),
      clock: clock('2026-10-25'),
    );
    expect(value.nextCheck, date('2026-11-01'));
    expect(value.overrideDate, isNull);
    expect(value.headId, original.headId);
    expect(value.headRevision, original.headRevision + 1);
  });

  test(
    'check-not-needed can choose past next date without actual-care change',
    () {
      final value = known().checkNotNeeded(
        checkDate: date('2026-10-25'),
        nextDate: date('2026-10-24'),
        eventId: id(11),
        commandId: id(111),
        clock: clock('2026-10-25'),
      );
      expect(value.nextCheck, date('2026-10-24'));
      expect(value.latestActualCare, date('2026-10-20'));
      expect(value.actualCareCount, 1);
      expect(
        () => value.snooze(date('2026-10-24'), clock('2026-10-25')),
        error('FIELD_INVALID'),
      );
      expect(
        value.snooze(date('2026-10-25'), clock('2026-10-25')).events.length,
        2,
      );
    },
  );

  test('CARE-03 monthly skip returns to original 31st, ignores override', () {
    final value =
        unknown(
              interval: CareInterval(1, IntervalUnit.month),
              first: '2027-01-31',
            )
            .complete(
              careDate: date('2027-01-31'),
              eventId: id(10),
              commandId: id(110),
              clock: clock('2027-01-31'),
            )
            .snooze(date('2027-04-05'), clock('2027-03-01'));
    final skipped = value.skip(
      eventId: id(11),
      commandId: id(111),
      clock: clock('2027-03-01'),
    );
    expect(skipped.nextCheck, date('2027-03-31'));
    expect(skipped.anchor, date('2027-01-31'));
    expect(skipped.overrideDate, isNull);
    expect(skipped.actualCareCount, 1);
    expect(skipped.events.last.effective.outcome, CareOutcome.skipped);
  });

  test(
    'correction and void retain originals, later events, head and audit',
    () {
      final original = known().addPast(
        careDate: date('2026-10-01'),
        outcome: CareOutcome.actualCare,
        eventId: id(11),
        commandId: id(111),
        clock: clock('2026-10-25'),
      );
      final corrected = original.correct(
        eventId: id(11),
        eventRevision: 1,
        correctionId: id(20),
        commandId: id(120),
        careDate: date('2026-09-30'),
        outcome: CareOutcome.actualCare,
        clock: clock('2026-10-25', zone: 'Pacific/Kiritimati'),
      );
      final voided = corrected.voidEvent(
        eventId: id(11),
        eventRevision: 2,
        correctionId: id(21),
        commandId: id(121),
        clock: clock('2026-10-25'),
      );
      final event = voided.events.last;
      expect(event.id, id(11));
      expect(event.original.careDate, date('2026-10-01'));
      expect(event.recordedZone, 'Asia/Jakarta');
      expect(event.corrections.length, 2);
      expect(event.corrections.last.before.careDate, date('2026-09-30'));
      expect(event.effective.voided, isTrue);
      expect(voided.latestActualCare, date('2026-10-20'));
      expect(voided.nextCheck, original.nextCheck);
      expect(voided.anchor, original.anchor);
      expect(voided.headRevision, original.headRevision);
      expect(voided.events.first, same(original.events.first));
      expect(original.events.last.corrections, isEmpty);
    },
  );

  test(
    'correcting outcome changes effective count but not recording facts/head',
    () {
      final original = known();
      final changed = original.correct(
        eventId: id(10),
        eventRevision: 1,
        correctionId: id(20),
        commandId: id(120),
        careDate: date('2026-10-20'),
        outcome: CareOutcome.checkedNotNeeded,
        clock: clock('2026-10-25'),
      );
      expect(changed.actualCareCount, 0);
      expect(changed.latestActualCare, isNull);
      expect(changed.nextCheck, original.nextCheck);
      expect(
        changed.events.single.recordedAt,
        original.events.single.recordedAt,
      );
    },
  );

  test('void requires explicit restore, stale correction cannot overwrite', () {
    final value = known().voidEvent(
      eventId: id(10),
      eventRevision: 1,
      correctionId: id(20),
      commandId: id(120),
      clock: clock('2026-10-25'),
    );
    RoutineCore edit(int rev, bool restore) => value.correct(
      eventId: id(10),
      eventRevision: rev,
      correctionId: id(21),
      commandId: id(121),
      careDate: date('2026-10-20'),
      outcome: CareOutcome.actualCare,
      clock: clock('2026-10-25'),
      restore: restore,
    );
    expect(() => edit(1, true), error('STALE_TARGET'));
    expect(() => edit(2, false), error('NOT_ELIGIBLE'));
    expect(edit(2, true).actualCareCount, 1);
  });

  test('future dates and duplicate entity IDs fail without mutation', () {
    final value = known();
    expect(
      () => value.addPast(
        careDate: date('2026-10-26'),
        outcome: CareOutcome.actualCare,
        eventId: id(11),
        commandId: id(111),
        clock: clock('2026-10-25'),
      ),
      error('FUTURE_CARE_DATE'),
    );
    expect(
      () => value.complete(
        careDate: date('2026-10-25'),
        eventId: id(10),
        commandId: id(111),
        clock: clock('2026-10-25'),
      ),
      error('FIELD_INVALID'),
    );
    expect(
      () => value.correct(
        eventId: id(10),
        eventRevision: 1,
        correctionId: id(20),
        commandId: id(120),
        careDate: date('2026-10-26'),
        outcome: CareOutcome.actualCare,
        clock: clock('2026-10-25'),
      ),
      error('FUTURE_CARE_DATE'),
    );
    expect(value.events.length, 1);
    expect(() => value.events.clear(), throwsUnsupportedError);
    expect(
      () => value.events.single.corrections.clear(),
      throwsUnsupportedError,
    );
  });
}
