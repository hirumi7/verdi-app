import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

import 'presentation_test.dart' show press, field, seed;

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(() => getIt.reset());
  testWidgets('care manager and keyboard remain usable at 320 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 3.2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(const VerdiApp());
    await tester.pumpAndSettle();
    await press(tester, 'Settings');
    await press(tester, 'Care types');
    await press(tester, 'Add custom care type');
    await tester.enterText(field('Care type name'), 'Clean leaves');
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = FakeViewPadding.zero;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await press(tester, 'Continue');
    expect(find.textContaining('Creating custom care'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await press(tester, 'Cancel');
  });
  testWidgets(
    'care type validation, cancel, guarded save and Free retained rename',
    (tester) async {
      final repo = getIt<CollectionRepository>() as MemoryCollectionRepository;
      repo.store.setProForTest(true);
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Settings');
      await press(tester, 'Care types');
      await press(tester, 'Add custom care type');
      await tester.enterText(field('Care type name'), 'x' * 25);
      await press(tester, 'Continue');
      expect(find.text('Enter 1–24 characters.'), findsOneWidget);
      await tester.enterText(field('Care type name'), 'Clean leaves');
      await press(tester, 'Continue');
      expect(find.text('Affected routines: 0'), findsOneWidget);
      await press(tester, 'Cancel');
      expect((await repo.mediaSnapshot()).customCareTypes, isEmpty);
      expect(find.text('Clean leaves'), findsOneWidget);
      await press(tester, 'Continue');
      await press(tester, 'Confirm');
      expect(
        (await repo.mediaSnapshot()).customCareTypes.values.single.label,
        'Clean leaves',
      );
      repo.store.setProForTest(false);
      await press(tester, 'Rename care type');
      await tester.enterText(field('Care type name'), 'Dust leaves');
      await press(tester, 'Continue');
      await press(tester, 'Confirm');
      expect(
        (await repo.mediaSnapshot()).customCareTypes.values.single.label,
        'Dust leaves',
      );
      await press(tester, 'Retire care type');
      await press(tester, 'Confirm');
      expect(
        (await repo.mediaSnapshot()).customCareTypes.values.single.retired,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'custom Add care form requires explicit seed and date; changed form confirms discard',
    (tester) async {
      final repo = getIt<CollectionRepository>() as MemoryCollectionRepository;
      repo.store.setProForTest(true);
      await seed(repo, 'Care fern');
      await repo.confirm(
        await repo.prepare(const CreateCustomCareType('Clean leaves')),
      );
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await press(tester, 'Plants');
      await press(tester, 'Care fern');
      await press(tester, 'Add care');
      await tester.enterText(field('Interval'), '2');
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard this unsaved care form?'), findsOneWidget);
      await press(tester, 'Cancel');
      expect(find.text('2'), findsOneWidget);
      await press(tester, 'Continue');
      expect(
        find.text('Review the highlighted fields and date choices.'),
        findsOneWidget,
      ); // Validation must retain the typed interval.
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await press(tester, 'Clean leaves');
      await press(tester, 'Not sure');
      await press(tester, 'Choose a date');
      await press(tester, 'OK');
      await press(tester, 'Continue');
      await press(tester, 'Confirm');
      expect((await repo.mediaSnapshot()).routines.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
