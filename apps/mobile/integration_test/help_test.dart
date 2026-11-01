import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'main local privacy/help and native metadata feedback copy preserve collection',
    (t) async {
      final repo = await NativeCollectionRepository.open();
      final before = await repo.mediaSnapshot();
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
        final target = find.text(text);
        if (target.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            target,
            300,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await Scrollable.ensureVisible(t.element(target.last), alignment: .5);
        await t.pumpAndSettle();
        await t.tap(target.last);
        await t.pumpAndSettle();
      }

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await press('Settings');
      await press('Privacy & local data');
      expect(find.text('Your collection on this device'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Deletion and copies'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Deleting local content cannot delete copies'),
        findsOneWidget,
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await press('Help & feedback');
      await press('Prepare feedback');
      for (
        var i = 0;
        i < 100 &&
            (field('Message').evaluate().isEmpty ||
                !t.widget<TextField>(field('Message')).enabled!);
        i++
      ) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final nativeBody = t.widget<TextField>(field('Message')).controller!.text;
      expect(nativeBody, contains('Verdi Preview 0.1.0 (build 1)'));
      expect(nativeBody, contains('iOS 18.3'));
      for (final plant in before.plants.values) {
        expect(nativeBody, isNot(contains(plant.id)));
      }
      await t.enterText(field('Subject'), 'Simulator feedback');
      await t.enterText(field('Message'), 'Local QA message only.');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await press('Copy feedback');
      expect(find.text('Feedback copied. Nothing was sent.'), findsOneWidget);
      expect(
        (await Clipboard.getData(Clipboard.kTextPlain))?.text,
        'Simulator feedback\n\nLocal QA message only.',
      );
      await t.pageBack();
      await t.pumpAndSettle();
      expect(find.text('Discard this feedback draft?'), findsOneWidget);
      await press('Cancel');
      expect(
        t.widget<TextField>(field('Message')).controller!.text,
        'Local QA message only.',
      );
      await t.pageBack();
      await t.pumpAndSettle();
      await press('Discard changes');
      final after = await repo.mediaSnapshot();
      expect(after.revision, before.revision);
      expect(after.plants.keys.toSet(), before.plants.keys.toSet());
      expect(after.photos.keys.toSet(), before.photos.keys.toSet());
      expect(after.drafts.keys.toSet(), before.drafts.keys.toSet());
      expect(after.covers, before.covers);
      expect(t.takeException(), isNull);
    },
  );
}
