import 'dart:io';
import '../test/support/journal_scenario.dart';

void main() {
  final s = journalScenario();
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/journal-storage-v3.json',
  ).writeAsStringSync('${s.json()}\n');
  stdout.writeln('Generated ${s.steps.length} journal transitions.');
}
