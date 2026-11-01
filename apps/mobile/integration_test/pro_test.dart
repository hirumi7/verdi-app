import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';

// Retained disposable Backup QA simulator only; no reset, purchase or store sync.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'main Settings and over-cap restore offer preserve existing content',
    (tester) async {
      final repo = await NativeCollectionRepository.open();
      final before = await repo.mediaSnapshot();
      final archived = before.plants.values.firstWhere((p) => p.archived);
      expect(before.activePlants.length, greaterThanOrEqualTo(5));
      await tester.pumpWidget(CoreBootstrap(openRepository: () async => repo));
      for (
        var i = 0;
        i < 150 && find.text('Settings').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      Future<void> press(String label) async {
        final matches = find.text(label);
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

      await press('Settings');
      await press('Verdi Pro');
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty) break;
      }
      expect(
        find.text('Local StoreKit test · simulated purchase, no real charge.'),
        findsOneWidget,
      );
      final state = jsonDecode(await StorePlatformHostApi().readState()) as Map;
      expect(state['access'], 'free');
      expect(
        find.textContaining('The store offer is unavailable'),
        findsOneWidget,
      );
      await press('Continue Free');
      await press('Plants');
      await press('Archived');
      await press(archived.name);
      await press('Restore plant');
      expect(find.textContaining('five active plants'), findsWidgets);
      await press('Verdi Pro');
      expect(find.text('One-time purchase'), findsOneWidget);
      await press('Continue Free');
      await press('Cancel');
      final after = await repo.mediaSnapshot();
      expect(after.plants.keys.toList(), before.plants.keys.toList());
      expect(after.plants[archived.id]!.archived, isTrue);
      expect(after.activePlants.length, before.activePlants.length);
      expect(
        after.routines.values.fold<int>(0, (n, r) => n + r.events.length),
        before.routines.values.fold<int>(0, (n, r) => n + r.events.length),
      );
      expect(after.photos.length, before.photos.length);
      expect(after.drafts.keys.toList(), before.drafts.keys.toList());
      for (final id in before.drafts.keys) {
        expect(after.drafts[id]!.fields.name, before.drafts[id]!.fields.name);
      }
      await tester.pumpWidget(const SizedBox());
      await repo.close();
    },
  );
}
