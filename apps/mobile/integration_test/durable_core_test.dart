import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'VERDI_CORE_PHASE',
    defaultValue: 'seed',
  );
  testWidgets('main native core $phase with retained installation', (
    tester,
  ) async {
    await getIt.reset();
    if (phase == 'seed') {
      // Remove only this test's named synthetic records when repeating a failed
      // run. Other plants/drafts/pending actions are preserved.
      final cleanup = await NativeCollectionRepository.open();
      for (final action in cleanup.pendingActions) {
        if (action.label.contains('Durable UI fern') ||
            action.label.contains('Unfinished native draft')) {
          await cleanup.abandon(action.intent.commandId);
        }
      }
      final draft = (await cleanup.editor(null)).draft;
      if (draft != null &&
          [
            'Durable UI fern',
            'Unfinished native draft',
          ].contains(draft.fields.name)) {
        await cleanup.submit(
          DiscardDraft(
            draftId: draft.id,
            draftRevision: draft.revision,
            confirmed: true,
          ),
        );
      }
      for (final archived in [false, true]) {
        final plants = (await cleanup.read(
          archived: archived,
          query: 'Durable UI fern',
        )).plants.page.items;
        for (final row in plants) {
          if (row.plant.name != 'Durable UI fern' ||
              row.plant.speciesName != 'Synthetic integration fern') {
            continue;
          }
          if (!row.plant.archived) {
            await cleanup.confirm(
              await cleanup.prepare(
                ArchivePlant(
                  plantId: row.plant.id,
                  plantRevision: row.plant.revision,
                ),
              ),
            );
          }
          final current = await cleanup.detail(row.plant.id);
          await cleanup.confirm(
            await cleanup.prepare(
              DeletePlant(
                plantId: current.plant.id,
                plantRevision: current.plant.revision,
              ),
            ),
          );
        }
      }
      await cleanup.close();
    }
    await tester.pumpWidget(const CoreBootstrap());
    Future<void> settle() async {
      for (var i = 0; i < 100; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      throw StateError('UI did not leave its loading state');
    }

    Future<void> press(String label, {bool first = false}) async {
      await settle();
      if (find.text(label).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(label),
          300,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 30,
        );
        await settle();
      }
      expect(find.text(label), findsWidgets, reason: 'button: $label');
      final target = first ? find.text(label).first : find.text(label).last;
      expect(target, findsOneWidget, reason: 'button: $label');
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await settle();
    }

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    await settle();
    if (phase == 'recover') {
      expect(find.text('Recover unfinished actions'), findsOneWidget);
      await press('Retry action');
      await press('Confirm');
      final repository = getIt<CollectionRepository>();
      final page = await repository.read(
        archived: false,
        query: 'Durable UI fern',
      );
      final plant = page.plants.page.items.single.plant;
      final detail = await repository.detail(plant.id),
          history = await repository.timeline(plant.id, includeVoided: true);
      expect(
        detail.routines.single.routine.nextCheck,
        repository.today.addDays(2),
      );
      expect(history.items.whereType<CareTimelineEntry>().length, 2);
      expect(
        history.items.whereType<CareTimelineEntry>().any((e) => e.voided),
        isTrue,
      );
      expect(
        history.items
            .whereType<CareTimelineEntry>()
            .expand((e) => e.event.corrections)
            .length,
        2,
      );
      await press('Plants');
      await press('Add a plant');
      expect(
        tester.widget<TextField>(field('Plant name')).controller!.text,
        'Unfinished native draft',
      );
      expect(tester.takeException(), isNull);
      return;
    }
    await press('Add a plant');
    await tester.enterText(field('Plant name'), 'Durable UI fern');
    await tester.pump();
    await tester.enterText(
      field('Custom species name'),
      'Synthetic integration fern',
    );
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await press('Watering routine');
    await tester.enterText(field('Interval'), '7');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await press('Not sure');
    await press('Choose a date');
    await press('OK');
    await press('Review and save');
    await press('Confirm');
    expect(find.text('Durable UI fern'), findsOneWidget);
    final repository = getIt<CollectionRepository>();
    final plant = (await repository.read(
      archived: false,
      query: 'Durable UI fern',
    )).plants.page.items.single.plant;
    expect(
      (await repository.timeline(plant.id)).items
          .whereType<CareTimelineEntry>(),
      isEmpty,
    );
    await press('Watered');
    await press('OK');
    await press('Confirm');
    var detail = await repository.detail(plant.id);
    final head = detail.routines.single.routine.nextCheck;
    expect(head, repository.today.addDays(7));
    await press('Add past care');
    await press('OK');
    await press('Watered');
    await press('Confirm');
    expect(
      (await repository.detail(plant.id)).routines.single.routine.nextCheck,
      head,
    );
    await press('Correct care', first: true);
    await press('OK');
    await press('Checked — not needed');
    await press('Confirm');
    expect(
      (await repository.detail(plant.id)).routines.single.routine.nextCheck,
      head,
    );
    await press('Remove mistaken entry', first: true);
    await press('Confirm');
    expect(
      (await repository.detail(plant.id)).routines.single.routine.nextCheck,
      head,
    );
    await press('Edit interval');
    await tester.enterText(field('Interval'), '9');
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    await press('Continue');
    await press('Confirm');
    await press('Archive plant');
    await press('Confirm');
    final archived = await repository.read(
      archived: true,
      query: 'Durable UI fern',
    );
    expect(archived.plants.page.items.single.plant.id, plant.id);
    // Navigate the actual archived collection to restore through its UI.
    await press('Archived');
    await press('Durable UI fern');
    await press('Restore plant');
    await press('Confirm');
    detail = await repository.detail(plant.id);
    expect(detail.plant.archived, isFalse);
    final history = await repository.timeline(plant.id, includeVoided: true);
    expect(history.items.whereType<CareTimelineEntry>().length, 2);
    expect(
      history.items
          .whereType<CareTimelineEntry>()
          .expand((e) => e.event.corrections)
          .length,
      2,
    );
    // Retain an autosaved editor draft and an explicitly frozen, uncommitted
    // care action for the next process. Neither is synthetic memory storage.
    await tester.pageBack();
    await settle();
    await press('Add a plant');
    await tester.enterText(field('Plant name'), 'Unfinished native draft');
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await settle();
    final editor = await repository.editor(null);
    expect(editor.draft!.fields.name, 'Unfinished native draft');
    await repository.prepare(
      Snooze(detail.routines.single.target, repository.today.addDays(2)),
    );
    expect(
      (await (repository as NativeCollectionRepository).pending()).length,
      1,
    );
    expect(tester.takeException(), isNull);
  });
}
