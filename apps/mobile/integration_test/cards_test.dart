import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_mobile/features/cards/presentation/card_page.dart';

// Uses a retained QA plant. No collection mutation, restore or uninstall.
// Operator cancels the OS share sheet and answers the add-only Photos prompt.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'main plant card native preview, share cancellation and Photos save preserve collection',
    (t) async {
      final repo = await NativeCollectionRepository.open();
      final before = await repo.mediaSnapshot();
      final plant = before.plants.values.firstWhere(
        (p) => !p.archived && before.covers.containsKey(p.id),
      );
      await t.pumpWidget(
        CoreBootstrap(openRepository: () => Future.value(repo)),
      );
      for (
        var i = 0;
        i < 150 && find.text('Settings').evaluate().isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 100));
      }
      Future<void> press(String text) async {
        final found = find.text(text);
        if (found.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            found,
            250,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await Scrollable.ensureVisible(t.element(found.last), alignment: .5);
        await t.pumpAndSettle();
        await t.tap(found.last);
        await t.pumpAndSettle();
      }

      await press('Plants');
      await press(plant.name);
      await press('Share plant card');
      expect(find.byType(CardPage), findsOneWidget);
      await press('Preview card');
      for (
        var i = 0;
        i < 200 && find.text('Refresh preview').evaluate().isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Refresh preview'), findsOneWidget);
      const denied = bool.fromEnvironment('VERDI_CARD_DENIED');
      if (denied) {
        await press('Save image');
        for (
          var i = 0;
          i < 200 &&
              find
                  .textContaining('Photos access was denied')
                  .evaluate()
                  .isEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(find.textContaining('Photos access was denied'), findsOneWidget);
        expect(find.text('Refresh preview'), findsOneWidget);
      } else {
        await press('Share');
        debugPrint('CARD_QA_CANCEL_NATIVE_SHARE');
        for (
          var i = 0;
          i < 1800 &&
              find.textContaining('Sharing cancelled').evaluate().isEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(find.textContaining('Sharing cancelled'), findsOneWidget);
        await press('Save image');
        debugPrint('CARD_QA_ALLOW_ADD_ONLY_SAVE');
        for (
          var i = 0;
          i < 1800 && find.text('Image saved.').evaluate().isEmpty;
          i++
        ) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(find.text('Image saved.'), findsOneWidget);
      }
      final after = await repo.mediaSnapshot();
      expect(after.revision, before.revision);
      expect(after.plants.keys.toSet(), before.plants.keys.toSet());
      expect(after.photos.keys.toSet(), before.photos.keys.toSet());
      expect(after.covers, before.covers);
      expect(after.drafts.keys.toSet(), before.drafts.keys.toSet());
      expect(t.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
