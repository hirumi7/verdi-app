import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native simulator custom draft, save, edit and archive', (
    tester,
  ) async {
    await getIt.reset();
    await configureDependencies();
    await tester.pumpWidget(const VerdiApp());
    await tester.pumpAndSettle();
    Future<void> press(String label) async {
      final target = find.text(label).last;
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await press('Add a plant');
    await tester.enterText(field('Plant name'), 'Simulator fern');
    await tester.pump();
    await tester.enterText(field('Custom species name'), 'Synthetic fern');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await press('Review and save');
    await press('Confirm');
    expect(find.text('Simulator fern'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit plant'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Plant name'), 'Simulator fern edited');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await press('Review and save');
    await press('Confirm');
    expect(find.text('Simulator fern edited'), findsOneWidget);
    await press('Archive plant');
    await press('Confirm');
    expect(find.text('Search plants'), findsOneWidget);
    final repository = getIt<CollectionRepository>();
    expect(
      (await repository.read(archived: false, query: '')).plants.activeCount,
      0,
    );
    expect(
      (await repository.read(
        archived: true,
        query: '',
      )).plants.page.items.single.plant.name,
      'Simulator fern edited',
    );
    expect(tester.takeException(), isNull);
  });
}
