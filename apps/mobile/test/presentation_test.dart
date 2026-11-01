import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/theme/app_theme.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/presentation/widgets/presentation_helpers.dart';
import 'package:verdi_mobile/l10n/app_localizations.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> press(WidgetTester tester, String text) async {
  final matches = find.text(text);
  if (matches.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      matches,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final target = matches.last;
  await Scrollable.ensureVisible(tester.element(target), alignment: .5);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> seed(CollectionRepository repository, String name) async {
  final draftId = repository.newId();
  final result = await repository.submit(
    SaveDraft(
      draftId: draftId,
      expectedRevision: null,
      mode: DraftMode.add,
      fields: CustomPlantFields(
        name: name,
        speciesName: 'Synthetic fern',
        routines: [
          RoutineInput(
            kind: StandardCareKind.water,
            count: '7',
            unit: IntervalUnit.day,
            seedKind: SeedKind.unknown,
            date: repository.today.toString(),
          ),
        ],
      ),
    ),
  );
  await repository.confirm(
    await repository.prepare(
      SavePlant(draftId: draftId, draftRevision: result.newRevisions[draftId]!),
    ),
  );
}

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(() => getIt.reset());

  testWidgets(
    'cached illustration keeps first-plant entry reachable by scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late BuildContext imageContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              imageContext = context;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/illustrations/empty-plants.png'),
          imageContext,
        ),
      );
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      expect(find.text('Add a plant'), findsNothing);
      await press(tester, 'Add a plant');
      if (field('Search species').evaluate().isNotEmpty) {
        await press(tester, 'Add a custom plant');
      }
      expect(field('Plant name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'stale bulk preview returns to selection; failed commit retries without duplicate care',
    (tester) async {
      final repository =
          getIt<CollectionRepository>() as MemoryCollectionRepository;
      await seed(repository, 'Retry sample');
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Select care');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await press(tester, 'Mark selected as watered');
      final plant = (await repository.read(
        archived: false,
        query: '',
      )).plants.page.items.single.plant;
      final routine = (await repository.detail(plant.id)).routines.single;
      await repository.confirm(
        await repository.prepare(
          SetInterval(routine.target, CareInterval(2, IntervalUnit.week)),
        ),
      );
      await press(tester, 'Confirm');
      expect(find.text('Return to review'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Retry'))
            .onPressed,
        isNull,
      );
      await press(tester, 'Return to review');
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await press(tester, 'Mark selected as watered');
      repository.store.nextFault = SimulatedFault.beforeCommit;
      await press(tester, 'Confirm');
      expect(find.text('Retry'), findsOneWidget);
      expect(
        (await repository.detail(plant.id)).routines.single.actualCareCount,
        0,
      );
      await press(tester, 'Retry');
      expect(
        (await repository.detail(plant.id)).routines.single.actualCareCount,
        1,
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'routine seed stays explicit and an unknown first date creates no care history',
    (tester) async {
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Add a plant');
      if (field('Search species').evaluate().isNotEmpty) {
        await press(tester, 'Add a custom plant');
      }
      await tester.enterText(field('Plant name'), 'Seed sample');
      await tester.pump();
      await tester.enterText(field('Custom species name'), 'Synthetic');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await press(tester, 'Watering routine');
      await tester.enterText(field('Interval'), '7');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await press(tester, 'Review and save');
      expect(
        find.text('Choose a known last-care date or Not sure.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<RadioGroup<SeedKind>>(find.byType(RadioGroup<SeedKind>))
            .groupValue,
        isNull,
      );
      expect(
        (await getIt<CollectionRepository>().read(
          archived: false,
          query: '',
        )).plants.activeCount,
        0,
      );
      await press(tester, 'Not sure');
      await press(tester, 'Choose a date');
      await press(tester, 'OK');
      await press(tester, 'Review and save');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Check watering'),
        ),
        findsOneWidget,
      );
      await press(tester, 'Confirm');
      final repository = getIt<CollectionRepository>();
      final plant = (await repository.read(
        archived: false,
        query: '',
      )).plants.page.items.single.plant;
      expect(
        (await repository.detail(plant.id)).routines.single.latestActualCare,
        isNull,
      );
      expect((await repository.timeline(plant.id)).items, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'custom save, edit, archive, restore and delete navigate to current records',
    (tester) async {
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Add a plant');
      if (field('Search species').evaluate().isNotEmpty) {
        await press(tester, 'Add a custom plant');
      }
      await tester.enterText(field('Plant name'), 'Sample fern');
      await tester.pump();
      await tester.enterText(field('Custom species name'), 'Synthetic fern');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review and save'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('plant-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await press(tester, 'Review and save');
      expect(find.byType(AlertDialog), findsOneWidget);
      await press(tester, 'Confirm');
      expect(find.text('Sample fern'), findsOneWidget);
      await tester.tap(find.byTooltip('Edit plant'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Plant name'), 'Renamed fern');
      FocusManager.instance.primaryFocus?.unfocus();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review and save'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('plant-editor-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await press(tester, 'Review and save');
      await press(tester, 'Confirm');
      expect(find.text('Renamed fern'), findsOneWidget);
      await press(tester, 'Archive plant');
      await press(tester, 'Confirm');
      expect(find.text('Search plants'), findsOneWidget);
      await press(tester, 'Archived');
      await press(tester, 'Renamed fern');
      await press(tester, 'Restore plant');
      await press(tester, 'Confirm');
      expect(find.text('Renamed fern'), findsOneWidget);
      await press(tester, 'Archive plant');
      await press(tester, 'Confirm');
      await press(tester, 'Archived');
      await press(tester, 'Renamed fern');
      await press(tester, 'Delete forever');
      expect(find.textContaining('This removes 0 routines'), findsOneWidget);
      await press(tester, 'Cancel');
      // Full names now live in scrollable content rather than a clipped toolbar.
      await tester.scrollUntilVisible(
        find.text('Renamed fern'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Renamed fern'), findsOneWidget);
      await press(tester, 'Delete forever');
      await press(tester, 'Confirm');
      expect(find.text('Search plants'), findsOneWidget);
      expect(find.text('Renamed fern'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bulk starts unselected, previews every member, commits and Undo reverses both',
    (tester) async {
      final repository = getIt<CollectionRepository>();
      await seed(repository, 'Sample A');
      await seed(repository, 'Sample B');
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Select care');
      expect(
        tester
            .widgetList<Checkbox>(find.byType(Checkbox))
            .every((w) => w.value == false),
        isTrue,
      );
      for (final check in find.byType(Checkbox).evaluate().toList()) {
        await tester.ensureVisible(find.byWidget(check.widget));
        await tester.tap(find.byWidget(check.widget));
        await tester.pump();
      }
      await press(tester, 'Mark selected as watered');
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sample A'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Sample B'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('Date care happened:'),
        ),
        findsOneWidget,
      );
      await press(tester, 'Confirm');
      await press(tester, 'Undo');
      final read = await repository.read(archived: false, query: '');
      expect(read.today[TodaySection.today]!.page.totalCount, 2);
      expect(read.today[TodaySection.doneToday]!.page.totalCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final theme in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets(
      'small portrait, 320% text, keyboard and reduced motion: $theme',
      (tester) async {
        tester.view.physicalSize = const Size(375, 667);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3.2;
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(() {
          tester.view.reset();
          tester.platformDispatcher.clearAllTestValues();
        });
        await tester.pumpWidget(VerdiApp(themeMode: theme));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Add a plant'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await press(tester, 'Add a plant');
        if (field('Search species').evaluate().isNotEmpty) {
          await press(tester, 'Add a custom plant');
        }
        await tester.enterText(field('Plant name'), 'Large text fern');
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = FakeViewPadding.zero;
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Review and save'),
          350,
          scrollable: find
              .descendant(
                of: find.byKey(const ValueKey('plant-editor-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 50,
        );
        await press(tester, 'Review and save');
        expect(
          find.text('Review the highlighted fields and date choices.'),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('US and GB format one immutable calendar date', (tester) async {
    final date = LocalDate(2026, 10, 31);
    for (final locale in [const Locale('en', 'US'), const Locale('en', 'GB')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('en', 'US'), Locale('en', 'GB')],
          localizationsDelegates: AppStrings.localizationsDelegates,
          home: Builder(builder: (context) => Text(dateLabel(context, date))),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(locale.countryCode == 'US' ? 'Oct 31, 2026' : '31 Oct 2026'),
        findsOneWidget,
      );
      expect(date.toString(), '2026-10-31');
    }
  });

  test('light/dark text and essential controls meet contrast thresholds', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05));
    }

    for (final brightness in Brightness.values) {
      final theme = AppTheme.build(brightness);
      final c = theme.colorScheme;
      for (final pair in [
        (c.onSurface, c.surface),
        (c.onSurfaceVariant, c.surface),
        (c.primary, theme.scaffoldBackgroundColor),
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.error, c.surface),
      ]) {
        expect(
          contrast(pair.$1, pair.$2),
          greaterThanOrEqualTo(4.5),
          reason: '$brightness $pair',
        );
      }
      expect(contrast(c.outline, c.surface), greaterThanOrEqualTo(3));
    }
  });
}
