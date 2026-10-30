import 'dart:io';

import 'package:verdi_core/verdi_core.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  // Synthetic and memory-only: no persistence, StoreKit or notification adapter.
  final clock = CareClock(
    LocalDate(2026, 10, 25),
    DateTime.utc(2026, 10, 25, 2),
    'Asia/Jakarta',
  );
  var routine = RoutineCore.known(
    id: id(1),
    plantId: id(2),
    headId: id(3),
    careLabel: 'Water',
    interval: CareInterval(1, IntervalUnit.week),
    careDate: LocalDate(2026, 10, 20),
    eventId: id(10),
    commandId: id(110),
    clock: clock,
  );
  try {
    routine = routine.complete(
      careDate: LocalDate(2026, 10, 10),
      eventId: id(11),
      commandId: id(111),
      clock: clock,
    );
  } on DomainException catch (error) {
    stdout.writeln('Current completion rejected: ${error.code}');
  }
  // A separate explicit history-only choice, never silent fallback from rejection.
  routine = routine.addPast(
    careDate: LocalDate(2026, 10, 10),
    outcome: CareOutcome.actualCare,
    eventId: id(11),
    commandId: id(112),
    clock: clock,
  );
  stdout.writeln('Actual events: ${routine.actualCareCount}');
  stdout.writeln('Latest actual care: ${routine.latestActualCare}');
  stdout.writeln('Next check unchanged: ${routine.nextCheck}');
}
