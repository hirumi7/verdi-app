import 'dart:io';
import '../test/custom_care_test.dart';

void main() {
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/added-catalog-routine-v5.json',
  ).writeAsStringSync('${addedCatalogRoutineScenario().json()}\n');
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/custom-unicode-v5.json',
  ).writeAsStringSync(
    '${customScenario(delete: true, unicode: true).json()}\n',
  );
  File(
    '../verdi_native/Tests/VerdiNativeTests/Fixtures/custom-storage-v5.json',
  ).writeAsStringSync('${customScenario(delete: true).json()}\n');
}
