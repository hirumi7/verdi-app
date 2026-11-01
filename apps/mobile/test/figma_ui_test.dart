import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/app.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/core/theme/figma_components.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/mock/memory_collection_repository.dart';

import 'catalog_editor_test.dart' show bundle;
import 'presentation_test.dart' show seed, press;

class CountingCatalog extends MemoryCollectionRepository {
  final requests = <Completer<CatalogState>>[];
  @override
  Future<CatalogState> catalog({bool retry = false}) {
    final pending = Completer<CatalogState>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: 'memory');
  });
  tearDown(() => getIt.reset());

  testWidgets(
    'artwork coalesces in-flight reads, refreshes packages, skips custom IDs',
    (tester) async {
      final repository = CountingCatalog();
      await getIt.unregister<CollectionRepository>();
      getIt.registerSingleton<CollectionRepository>(repository);
      Widget art() => const MaterialApp(
        home: Column(
          children: [
            CatalogArtwork(speciesId: 'sp_monstera_deliciosa'),
            CatalogArtwork(speciesId: 'sp_ficus_lyrata'),
            CatalogArtwork(),
          ],
        ),
      );
      await tester.pumpWidget(art());
      expect(repository.requests, hasLength(1));
      repository.requests.single.complete(bundle());
      await tester.pumpAndSettle();
      expect(
        find.image(
          const AssetImage('assets/catalog_art/art_monstera_deliciosa.png'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(art());
      expect(repository.requests, hasLength(2));
      repository.requests.last.complete(CatalogState());
      await tester.pumpAndSettle();
      expect(
        find.image(
          const AssetImage('assets/catalog_art/art_monstera_deliciosa.png'),
        ),
        findsNothing,
      );
      expect(
        find.image(const AssetImage('assets/illustrations/empty-plants.png')),
        findsNWidgets(2),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Figma collection and detail tabs remain reachable at 320 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3.2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await seed(getIt<CollectionRepository>(), 'Large fern');
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Plants'));
      await tester.pumpAndSettle();
      await press(tester, 'Large fern');
      await press(tester, 'Stats');
      await tester.scrollUntilVisible(
        find.text('Actual care recorded'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Actual care recorded'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, 1200));
      await tester.pumpAndSettle();
      await press(tester, 'History');
      await tester.scrollUntilVisible(
        find.text('Include removed entries'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Include removed entries'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'grid/list retains search, archive filter and detail identity; care menu does not write',
    (tester) async {
      final r = getIt<CollectionRepository>();
      await seed(r, 'Fern Alpha');
      await seed(r, 'Fern Beta');
      final before = await r.mediaSnapshot();
      await tester.pumpWidget(const VerdiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More actions').first);
      await tester.pumpAndSettle();
      expect(find.text('Watered'), findsOneWidget);
      expect((await r.mediaSnapshot()).revision, before.revision);
      await tester.tap(find.text('Watered'));
      await tester.pumpAndSettle();
      await press(tester, 'Cancel');
      expect((await r.mediaSnapshot()).revision, before.revision);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Plants'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alpha');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();
      expect(find.text('Fern Alpha'), findsOneWidget);
      expect(find.text('Fern Beta'), findsNothing);
      await press(tester, 'Archived');
      await tester.tap(find.byTooltip('Grid view'));
      await tester.pumpAndSettle();
      expect(find.text('Fern Alpha'), findsNothing);
      await press(tester, 'Active');
      await press(tester, 'Fern Alpha');
      await press(tester, 'Stats');
      expect(find.text('Actual care recorded'), findsOneWidget);
      await press(tester, 'History');
      expect(find.text('Include removed entries'), findsOneWidget);
      await press(tester, 'Care');
      expect(find.text('Every 7 days'), findsOneWidget);
      expect((await r.mediaSnapshot()).revision, before.revision);
      expect(tester.takeException(), isNull);
    },
  );
}
