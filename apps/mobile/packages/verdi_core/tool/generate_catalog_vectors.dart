import 'dart:io';
import 'package:verdi_core/verdi_core.dart';
import '../test/catalog_test.dart';

void main() {
  final scenario = catalogScenario();
  scenario.run(
    ArchivePlant(
      plantId: scenario.plant,
      plantRevision:
          scenario.projection.snapshot.plants[scenario.plant]!.revision,
    ),
  );
  scenario.run(
    DeletePlant(
      plantId: scenario.plant,
      plantRevision:
          scenario.projection.snapshot.plants[scenario.plant]!.revision,
    ),
  );
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/catalog-storage-v2.json',
  ).writeAsStringSync('${scenario.json()}\n');
  final unknown = catalogScenario(unknownSeed: true);
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/catalog-unknown-v2.json',
  ).writeAsStringSync('${unknown.json()}\n');
  stdout.writeln('Generated ${scenario.steps.length} catalog transitions.');
}
