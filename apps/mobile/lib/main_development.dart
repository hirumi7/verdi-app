import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  if (kReleaseMode) {
    throw StateError('Development adapter cannot run in release mode.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const VerdiApp());
}
