import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';

Matcher code(String value) =>
    isA<DomainException>().having((error) => error.code, 'code', value);
LocalDate date(String value) => LocalDate.parse(value);

void main() {
  group('LocalDate', () {
    test('strict date syntax, real dates, bounds and leap-century rule', () {
      for (final value in [
        '2026-2-01',
        '2026-02-30',
        '0000-01-01',
        '10000-01-01',
        ' 2026-01-01',
        '2026-01-01\n',
        '2026-01-01T00:00:00Z',
        '1900-02-29',
        '2026-00-01',
        '2026-13-01',
        '2026-01-00',
      ]) {
        expect(
          () => date(value),
          throwsA(code('FIELD_INVALID')),
          reason: value,
        );
      }
      expect(date('2000-02-29').toString(), '2000-02-29');
      expect(date('0001-01-01'), LocalDate(1, 1, 1));
      expect(() => LocalDate(9999, 13, 1), throwsA(code('FIELD_INVALID')));
      expect(() => LocalDate(1, 1, 32), throwsA(code('FIELD_INVALID')));
    });

    test('value equality, hash and chronological ordering', () {
      expect({date('2026-10-30'), LocalDate(2026, 10, 30)}.length, 1);
      final dates = [date('2027-01-01'), date('2026-12-31'), date('2026-10-30')]
        ..sort();
      expect(dates.map((d) => d.toString()), [
        '2026-10-30',
        '2026-12-31',
        '2027-01-01',
      ]);
    });

    test('signed calendar day arithmetic and safe overflow rejection', () {
      expect(date('2024-03-01').addDays(-1), date('2024-02-29'));
      expect(date('0001-01-01').daysUntil(date('9999-12-31')), 3652058);
      expect(date('9999-12-31').addDays(-3652058), date('0001-01-01'));
      for (final amount in [1, 9007199254740991]) {
        expect(
          () => date('9999-12-31').addDays(amount),
          throwsA(code('DATE_OVERFLOW')),
        );
        expect(
          () => date('0001-01-01').addDays(-amount),
          throwsA(code('DATE_OVERFLOW')),
        );
      }
    });
  });

  group('REQ-008 calendar recurrence', () {
    test('reject invalid intervals and occurrences', () {
      for (final n in [-1, 0, 10000]) {
        expect(
          () => CareInterval(n, IntervalUnit.day),
          throwsA(code('FIELD_INVALID')),
        );
      }
      expect(
        () => addInterval(
          date('2026-01-01'),
          CareInterval(1, IntervalUnit.day),
          occurrences: -1,
        ),
        throwsA(code('FIELD_INVALID')),
      );
      for (final unit in IntervalUnit.values) {
        expect(
          () => addInterval(
            date('2026-01-01'),
            CareInterval(9999, unit),
            occurrences: 9007199254740991,
          ),
          throwsA(code('DATE_OVERFLOW')),
        );
      }
    });

    test('days and weeks cross DST dates as seven calendar dates', () {
      for (final start in [
        '2026-03-07',
        '2026-03-28',
        '2026-10-24',
        '2026-10-31',
      ]) {
        final anchor = date(start);
        final days = addInterval(anchor, CareInterval(7, IntervalUnit.day));
        final week = addInterval(anchor, CareInterval(1, IntervalUnit.week));
        expect(days, week);
        expect(anchor.daysUntil(week), 7);
      }
      expect(
        addInterval(date('2026-03-07'), CareInterval(1, IntervalUnit.week)),
        date('2026-03-14'),
      );
    });

    test('month end clamps once but anchored recurrence returns to 31st', () {
      final anchor = date('2026-01-31');
      final interval = CareInterval(1, IntervalUnit.month);
      expect(addInterval(anchor, interval), date('2026-02-28'));
      expect(addInterval(anchor, interval, occurrences: 2), date('2026-03-31'));
      expect(
        nextCadence(
          anchor,
          interval,
          date('2026-02-28'),
          firstCheckAnchor: false,
        ),
        date('2026-03-31'),
      );
      expect(
        nextCadence(
          anchor,
          interval,
          date('2026-03-30'),
          firstCheckAnchor: false,
        ),
        date('2026-03-31'),
      );
    });

    test('leap anniversary returns in the next leap year', () {
      final anchor = date('2024-02-29');
      final yearly = CareInterval(1, IntervalUnit.year);
      expect(addInterval(anchor, yearly), date('2025-02-28'));
      expect(addInterval(anchor, yearly, occurrences: 4), date('2028-02-29'));
      expect(
        nextCadence(
          anchor,
          yearly,
          date('2027-02-28'),
          firstCheckAnchor: false,
        ),
        date('2028-02-29'),
      );
      expect(
        addInterval(date('2096-02-29'), yearly, occurrences: 4),
        date('2100-02-28'),
      );
    });

    test('first-check anchor includes k0; actual-care starts at k1', () {
      final anchor = date('2026-10-30');
      final weekly = CareInterval(1, IntervalUnit.week);
      expect(
        nextCadence(anchor, weekly, date('2026-10-29'), firstCheckAnchor: true),
        anchor,
      );
      expect(
        nextCadence(
          anchor,
          weekly,
          date('2026-10-29'),
          firstCheckAnchor: false,
        ),
        date('2026-11-06'),
      );
      expect(
        nextCadence(anchor, weekly, anchor, firstCheckAnchor: true),
        date('2026-11-06'),
      );
    });

    test('strictly-after and extreme range have bounded results', () {
      expect(
        nextCadence(
          date('0001-01-01'),
          CareInterval(1, IntervalUnit.day),
          date('9999-12-30'),
          firstCheckAnchor: false,
        ),
        date('9999-12-31'),
      );
      expect(
        () => nextCadence(
          date('0001-01-01'),
          CareInterval(1, IntervalUnit.day),
          date('9999-12-31'),
          firstCheckAnchor: false,
        ),
        throwsA(code('DATE_OVERFLOW')),
      );
      expect(
        nextCadence(
          date('9999-12-31'),
          CareInterval(9999, IntervalUnit.year),
          date('9999-12-30'),
          firstCheckAnchor: true,
        ),
        date('9999-12-31'),
      );
      expect(
        () => nextCadence(
          date('9999-12-31'),
          CareInterval(1, IntervalUnit.day),
          date('9999-12-30'),
          firstCheckAnchor: false,
        ),
        throwsA(code('DATE_OVERFLOW')),
      );
    });

    test('sampled addition round trips across a Gregorian 400-year cycle', () {
      for (var year = 1600; year < 2000; year++) {
        for (var month = 1; month <= 12; month++) {
          final anchor = LocalDate(year, month, 28);
          for (final days in [-366, -31, -1, 0, 1, 31, 366]) {
            final later = anchor.addDays(days);
            expect(later.addDays(-days), anchor);
            expect(anchor.daysUntil(later), days);
          }
        }
      }
    });

    test(
      'bounded cadence matches simple reference enumeration on short ranges',
      () {
        for (final unit in IntervalUnit.values) {
          for (final count in [1, 2, 7, 13]) {
            for (final first in [true, false]) {
              final anchor = date('2024-01-31');
              final interval = CareInterval(count, unit);
              for (var days = -1; days < 1500; days += 31) {
                final today = anchor.addDays(days);
                var k = first ? 0 : 1;
                while (addInterval(
                      anchor,
                      interval,
                      occurrences: k,
                    ).compareTo(today) <=
                    0) {
                  k++;
                }
                expect(
                  nextCadence(anchor, interval, today, firstCheckAnchor: first),
                  addInterval(anchor, interval, occurrences: k),
                );
              }
            }
          }
        }
      },
    );
  });
}
