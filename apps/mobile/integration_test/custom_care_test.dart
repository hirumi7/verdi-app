import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_core/verdi_core.dart';

// Retained QA installation: preserve every existing plant, draft and media file.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native main custom gate preserves input; Free adds standard care and persists after reopen',
    (tester) async {
      final repository = await NativeCollectionRepository.open();
      final before = await repository.mediaSnapshot();
      await tester.pumpWidget(
        CoreBootstrap(openRepository: () async => repository),
      );
      for (
        var i = 0;
        i < 150 && find.text('Settings').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      Future<void> press(String text) async {
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

      Finder field(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );
      await press('Settings');
      await press('Care types');
      await press('Add custom care type');
      await tester.enterText(field('Care type name'), 'Simulator custom care');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await repository.injectFaultForTest(CoreVerificationFault.beforeFreeze);
      await press('Continue');
      expect(await repository.pending(), isEmpty);
      await repository.injectFaultForTest(CoreVerificationFault.receiptRead);
      await press('Cancel');
      expect(
        find.text('Retry'),
        findsOneWidget,
      ); // An unavailable receipt is not absence.
      await press('Cancel');
      expect(tester.widget<TextField>(field('Care type name')).enabled, true);
      await repository.injectFaultForTest(
        CoreVerificationFault.afterFreezeReply,
      );
      await press('Continue');
      final pending = (await repository.pending()).single;
      expect(pending.intent.command, isA<CreateCustomCareType>());
      expect(
        tester
            .widget<TextField>(
              field('Care type name').hitTestable().evaluate().isEmpty
                  ? find.byWidgetPredicate(
                      (w) =>
                          w is TextField &&
                          w.decoration?.labelText == 'Care type name',
                      skipOffstage: false,
                    )
                  : field('Care type name'),
            )
            .enabled,
        false,
      );
      await press('Retry');
      expect(
        (await repository.pending()).single.intent.commandId,
        pending.intent.commandId,
      );
      expect(find.textContaining('Creating custom care'), findsOneWidget);
      await press('Verdi Pro');
      await press('Continue Free');
      await press('Cancel');
      expect(find.text('Simulator custom care'), findsOneWidget);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      await press('Discard changes');
      await tester.pageBack();
      await tester.pumpAndSettle();
      final state = await repository.mediaSnapshot();
      expect(state.customCareTypes.length, before.customCareTypes.length);
      expect(state.plants.length, before.plants.length);
      expect(state.photos.length, before.photos.length);
      final plant = state.activePlants.firstWhere(
        (p) => standardCareKinds.any(
          (kind) => !state.routines.values.any(
            (r) =>
                r.plantId == p.id &&
                r.status != RoutineStatus.retired &&
                state.careKinds[r.id] == kind,
          ),
        ),
      );
      final kind = standardCareKinds.firstWhere(
        (kind) => !state.routines.values.any(
          (r) =>
              r.plantId == plant.id &&
              r.status != RoutineStatus.retired &&
              state.careKinds[r.id] == kind,
        ),
      );
      await press('Plants');
      await press(plant.name);
      await press('Add care');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      final label = switch (kind) {
        StandardCareKind.water => 'Check watering',
        StandardCareKind.fertilize => 'Fertilize',
        StandardCareKind.mist => 'Mist',
        StandardCareKind.repot => 'Repot',
        StandardCareKind.rotate => 'Rotate',
        StandardCareKind.custom => throw StateError('standard'),
      };
      await press(label);
      await tester.enterText(field('Interval'), '2');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await press('Not sure');
      await press('Choose a date');
      await press('OK');
      await press('Continue');
      await press('Confirm');
      final after = await repository.mediaSnapshot();
      expect(after.routines.length, before.routines.length + 1);
      expect(after.photos.length, before.photos.length);
      expect(after.drafts.keys.toSet(), before.drafts.keys.toSet());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await repository.close();
      final reopened = await NativeCollectionRepository.open();
      final persisted = await reopened.mediaSnapshot();
      expect(persisted.routines.keys.toSet(), after.routines.keys.toSet());
      await reopened.close();
      expect(tester.takeException(), isNull);
    },
  );
}
