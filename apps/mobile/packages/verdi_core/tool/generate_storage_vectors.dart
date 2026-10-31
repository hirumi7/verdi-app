import 'dart:io';
import '../test/support/storage_scenario.dart';

void main() {
  final scenario = StorageScenario()..allCommands();
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/core-storage-v3.json',
  ).writeAsStringSync('${scenario.json()}\n');
  stdout.writeln('Generated ${scenario.steps.length} storage transitions.');
}
