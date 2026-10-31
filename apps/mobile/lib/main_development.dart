import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/core_bootstrap.dart';

Future<void> main() async {
  if (kReleaseMode) {
    throw StateError('Development adapter cannot run in release mode.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'ZIPFoundation',
    ], await rootBundle.loadString('assets/licenses/zipfoundation.txt'));
  });
  runApp(const CoreBootstrap());
}
