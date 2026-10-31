import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/core_bootstrap.dart';

Future<void> main() async {
  if (kReleaseMode) {
    throw StateError('Development adapter cannot run in release mode.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CoreBootstrap());
}
