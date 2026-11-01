import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';

import 'presentation_test.dart' show seed, press;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/theme/app_layout.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/help/presentation/help_pages.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(() => getIt.reset());
  testWidgets('tab headings align and settings cards never touch', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const VerdiApp());
    await tester.pumpAndSettle();
    final tops = <double>[];
    for (final label in ['Today', 'Plants', 'Settings']) {
      await tester.tap(find.widgetWithText(NavigationDestination, label));
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(AppPageHeader),
        matching: find.text(label),
      );
      final rect = tester.getRect(title);
      expect(rect.left, 16);
      tops.add(rect.top);
      expect(tester.takeException(), isNull);
    }
    expect(tops.toSet().length, 1);
    final cards = find.byType(Card);
    expect(cards.evaluate().length, greaterThan(1));
    final first = tester.getRect(cards.at(0));
    final second = tester.getRect(cards.at(1));
    expect(second.top - first.bottom, 12);
    expect(first.left, 16);
    expect(first.height, 64);
    expect(first.right, 374);
  });
  for (final brightness in Brightness.values) {
    testWidgets('large ${brightness.name} title scrolls with content', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.build(brightness),
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(3.2)),
            child: child!,
          ),
          home: const HelpPage(),
        ),
      );
      await tester.pumpAndSettle();
      final title = find.descendant(
        of: find.byType(AppScrollTitle),
        matching: find.byType(Text),
      );
      expect(title, findsOneWidget);
      expect(tester.getRect(title).width, lessThanOrEqualTo(288));
      expect(
        find.descendant(
          of: find.byWidgetPredicate((w) => w is AppBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'full long plant title and actions survive 320px at 320 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const name =
          'Long botanical name that wraps across several lines of text.';
      await seed(getIt<CollectionRepository>(), name);
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Plants'));
      await tester.pumpAndSettle();
      await press(tester, name);
      final heading = find.descendant(
        of: find.byType(AppPageHeader),
        matching: find.text(name),
      );
      expect(heading, findsOneWidget);
      expect(tester.widget<Text>(heading).maxLines, isNull);
      final scroll = find.byType(Scrollable).first;
      expect(tester.getSize(scroll).height, greaterThan(48));
      await press(tester, 'Photos');
      expect(find.byType(AppScrollTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
