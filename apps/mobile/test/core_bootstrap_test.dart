import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';

void main() {
  testWidgets(
    'unavailable native startup retains recovery and never opens empty workspace',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var attempts = 0;
      await tester.pumpWidget(
        CoreBootstrap(
          openRepository: () async {
            attempts++;
            throw const RecoveryUnavailable();
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add a plant'), findsNothing);
      final retained = find.text(
        'Your saved files are retained. Storage could not complete this action.',
      );
      await tester.scrollUntilVisible(retained, 160);
      expect(retained, findsOneWidget);
      final retry = find.text('Retry opening');
      await tester.scrollUntilVisible(retry, 160);
      await tester.pumpAndSettle();
      await tester.ensureVisible(retry);
      await tester.pumpAndSettle();
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.text('Add a plant'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
