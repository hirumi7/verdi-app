import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';

import 'presentation_test.dart' show seed, press;

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'grouped edit fields survive species round trip in ${mode.name}',
      (t) async {
        await getIt.reset();
        await configureDependencies(environment: 'memory');
        addTearDown(getIt.reset);
        t.view.physicalSize = const Size(390, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        const fontPath = String.fromEnvironment('VERDI_TEST_FONT');
        if (const bool.fromEnvironment('VERDI_CAPTURE_SECONDARY') &&
            fontPath.isNotEmpty) {
          final loader = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(File(fontPath).readAsBytesSync()),
              ),
            );
          await loader.load();
        }
        final repository = getIt<CollectionRepository>();
        await seed(repository, 'Monty');
        final boundary = GlobalKey();
        await t.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: VerdiApp(themeMode: mode),
          ),
        );
        await t.pumpAndSettle();
        await press(t, 'Plants');
        await press(t, 'Monty');
        await t.tap(find.byTooltip('Edit plant'));
        await t.pumpAndSettle();
        Finder field(String label) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == label,
        );
        await t.enterText(field('Plant name'), 'Monty by the window');
        await t.ensureVisible(field('Notes (optional)'));
        await t.enterText(
          field('Notes (optional)'),
          'A new leaf unfurled. Keep this draft.',
        );
        await t.pump(const Duration(milliseconds: 450));
        FocusManager.instance.primaryFocus?.unfocus();
        await press(t, 'Change species');
        await press(t, 'Add a custom plant');
        await t.pumpAndSettle();
        expect(
          t.widget<TextField>(field('Plant name')).controller!.text,
          'Monty by the window',
        );
        expect(
          t.widget<TextField>(field('Notes (optional)')).controller!.text,
          'A new leaf unfurled. Keep this draft.',
        );
        final drafts = (await repository.mediaSnapshot()).drafts.values;
        expect(drafts.any((d) => d.fields.name == 'Monty by the window'), true);
        Scrollable.of(t.element(field('Plant name'))).position.jumpTo(0);
        FocusManager.instance.primaryFocus?.unfocus();
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (const bool.fromEnvironment('VERDI_CAPTURE_SECONDARY')) {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          await t.runAsync(() async {
            final image = await render.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('/tmp/verdi-secondary-form-${mode.name}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await t.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets('dirty plant discard stays safe at 320 percent with keyboard', (
    t,
  ) async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
    addTearDown(getIt.reset);
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    t.platformDispatcher.textScaleFactorTestValue = 3.2;
    addTearDown(() {
      t.view.reset();
      t.platformDispatcher.clearAllTestValues();
    });
    await t.pumpWidget(const VerdiApp());
    await t.pumpAndSettle();
    await press(t, 'Add a plant');
    await press(t, 'Add a custom plant');
    final name = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Plant name',
    );
    await t.ensureVisible(name);
    await t.enterText(name, 'Keep this draft');
    t.view.viewInsets = const FakeViewPadding(bottom: 260);
    await t.pump();
    await t.tap(find.byTooltip('Cancel'));
    await t.pumpAndSettle();
    expect(find.text('Keep editing'), findsOneWidget);
    expect(t.takeException(), isNull);
    await press(t, 'Keep editing');
    expect(t.widget<TextField>(name).controller!.text, 'Keep this draft');
    await t.pumpWidget(const SizedBox());
  });
}
