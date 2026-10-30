import 'errors.dart';

/// A Gregorian calendar date, never a timestamp or a device-local DateTime.
final class LocalDate implements Comparable<LocalDate> {
  LocalDate(this.year, this.month, this.day) {
    if (year < 1 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > _daysInMonth(year, month)) {
      throw DomainException('FIELD_INVALID');
    }
  }

  factory LocalDate.parse(String value) {
    if (value.length != 10 ||
        !RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$').hasMatch(value)) {
      throw DomainException('FIELD_INVALID');
    }
    return LocalDate(
      int.parse(value.substring(0, 4)),
      int.parse(value.substring(5, 7)),
      int.parse(value.substring(8, 10)),
    );
  }

  final int year;
  final int month;
  final int day;

  // UTC is only a bounded component-arithmetic helper. No clock, timezone,
  // offset or timestamp enters the public model or persistence representation.
  static final _origin = DateTime.utc(1);
  static final _lastOrdinal = DateTime.utc(
    9999,
    12,
    31,
  ).difference(_origin).inDays;
  int get _ordinal => DateTime.utc(year, month, day).difference(_origin).inDays;

  LocalDate addDays(int days) {
    final ordinal = _ordinal;
    // Validate before Duration multiplication, including extreme caller integers.
    if (days < -ordinal || days > _lastOrdinal - ordinal) {
      throw DomainException('DATE_OVERFLOW');
    }
    final result = _origin.add(Duration(days: ordinal + days));
    return LocalDate(result.year, result.month, result.day);
  }

  int daysUntil(LocalDate other) => other._ordinal - _ordinal;

  @override
  int compareTo(LocalDate other) {
    final years = year.compareTo(other.year);
    if (years != 0) return years;
    final months = month.compareTo(other.month);
    return months != 0 ? months : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      year == other.year &&
      month == other.month &&
      day == other.day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
}

enum IntervalUnit { day, week, month, year }

final class CareInterval {
  CareInterval(this.count, this.unit) {
    if (count < 1 || count > 9999) throw DomainException('FIELD_INVALID');
  }

  final int count;
  final IntervalUnit unit;

  @override
  bool operator ==(Object other) =>
      other is CareInterval && count == other.count && unit == other.unit;

  @override
  int get hashCode => Object.hash(count, unit);
}

int _daysInMonth(int year, int month) {
  if (month == 2) {
    return year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28;
  }
  return const {4, 6, 9, 11}.contains(month) ? 30 : 31;
}

int _remainingUnits(LocalDate anchor, IntervalUnit unit) => switch (unit) {
  IntervalUnit.day => anchor.daysUntil(LocalDate(9999, 12, 31)),
  IntervalUnit.week => anchor.daysUntil(LocalDate(9999, 12, 31)) ~/ 7,
  IntervalUnit.month => (9999 - anchor.year) * 12 + 12 - anchor.month,
  IntervalUnit.year => 9999 - anchor.year,
};

/// Adds from the ORIGINAL anchor, so February clamping cannot cause March drift.
LocalDate addInterval(
  LocalDate anchor,
  CareInterval interval, {
  int occurrences = 1,
}) {
  if (occurrences < 0) throw DomainException('FIELD_INVALID');
  if (occurrences > _remainingUnits(anchor, interval.unit) ~/ interval.count) {
    throw DomainException('DATE_OVERFLOW');
  }
  final count = interval.count * occurrences;
  switch (interval.unit) {
    case IntervalUnit.day:
      return anchor.addDays(count);
    case IntervalUnit.week:
      return anchor.addDays(count * 7);
    case IntervalUnit.month:
      final monthIndex = (anchor.year - 1) * 12 + anchor.month - 1 + count;
      final year = monthIndex ~/ 12 + 1;
      final month = monthIndex % 12 + 1;
      final lastDay = _daysInMonth(year, month);
      return LocalDate(
        year,
        month,
        anchor.day < lastDay ? anchor.day : lastDay,
      );
    case IntervalUnit.year:
      final year = anchor.year + count;
      final lastDay = _daysInMonth(year, anchor.month);
      return LocalDate(
        year,
        anchor.month,
        anchor.day < lastDay ? anchor.day : lastDay,
      );
  }
}

/// First anchored occurrence strictly after today; no override is an input.
LocalDate nextCadence(
  LocalDate anchor,
  CareInterval interval,
  LocalDate today, {
  required bool firstCheckAnchor,
}) {
  var low = firstCheckAnchor ? 0 : 1;
  var high = _remainingUnits(anchor, interval.unit) ~/ interval.count;
  if (high < low ||
      addInterval(anchor, interval, occurrences: high).compareTo(today) <= 0) {
    throw DomainException('DATE_OVERFLOW');
  }
  // At most 22 iterations over the entire 0001–9999 range; not a day-by-day loop.
  while (low < high) {
    final middle = low + (high - low) ~/ 2;
    if (addInterval(anchor, interval, occurrences: middle).compareTo(today) <=
        0) {
      low = middle + 1;
    } else {
      high = middle;
    }
  }
  return addInterval(anchor, interval, occurrences: low);
}
