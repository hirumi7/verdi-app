import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'VERDI_CATALOG_PHASE',
    defaultValue: 'seed',
  );
  testWidgets('bundled catalog main UI $phase, retained installation', (
    tester,
  ) async {
    await getIt.reset();
    if (phase == 'resumeApply') {
      final r = await NativeCollectionRepository.open();
      final action = (await r.pending()).single;
      expect(action.label, 'Catalog UI plant');
      final preview = await r.prepare(
        action.intent.command,
        commandId: action.intent.commandId,
      );
      try {
        await r.confirm(preview);
      } catch (error) {
        debugPrint('Retained apply error: $error');
        rethrow;
      }
      await r.close();
      return;
    }
    if (phase == 'seed') {
      final r = await NativeCollectionRepository.open();
      for (final action in await r.pending()) {
        if ([
          'Catalog UI plant',
          'Catalog draft recovery',
        ].contains(action.label)) {
          await r.abandon(action.intent.commandId);
        }
      }
      final draft = (await r.editor(null)).draft;
      if (draft != null &&
          [
            'Catalog UI plant',
            'Catalog draft recovery',
          ].contains(draft.fields.name)) {
        await r.submit(
          DiscardDraft(
            draftId: draft.id,
            draftRevision: draft.revision,
            confirmed: true,
          ),
        );
      }
      for (final archived in [false, true]) {
        for (final row in (await r.read(
          archived: archived,
          query: 'Catalog UI plant',
        )).plants.page.items) {
          if (row.plant.name != 'Catalog UI plant') continue;
          if (!row.plant.archived) {
            await r.confirm(
              await r.prepare(
                ArchivePlant(
                  plantId: row.plant.id,
                  plantRevision: row.plant.revision,
                ),
              ),
            );
          }
          final p = (await r.detail(row.plant.id)).plant;
          await r.confirm(
            await r.prepare(
              DeletePlant(plantId: p.id, plantRevision: p.revision),
            ),
          );
        }
      }
      await r.close();
    }
    await tester.pumpWidget(const CoreBootstrap());
    Future<void> settle() async {
      for (var i = 0; i < 150; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      throw StateError('Loading did not finish');
    }

    Future<void> press(String label) async {
      await settle();
      if (find.text(label).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          find.text(label),
          250,
          scrollable: find.byType(Scrollable).last,
          maxScrolls: 40,
        );
      }
      final target = find.text(label).last;
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await settle();
    }

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    Future<void> type(String label, String value) async {
      // Live binding caches the prior EditableText even after native unfocus.
      // Re-request the keyboard when revisiting the same search after a dialog.
      tester.binding.focusedEditable = null;
      await tester.showKeyboard(field(label));
      await tester.pumpAndSettle();
      await tester.enterText(field(label), value);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: field(label),
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        value,
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
    }

    await settle();
    final repository = getIt<CollectionRepository>();
    final catalog = await repository.catalog();
    expect(catalog.available, isTrue);
    expect(catalog.entries, hasLength(24));
    expect(catalog.popularComplete, isTrue);
    if (phase == 'upgrade') {
      expect(
        (await repository.read(
          archived: false,
          query: 'Durable UI fern',
        )).plants.page.items,
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      return;
    }
    if (phase == 'recover') {
      final plant = (await repository.read(
        archived: false,
        query: 'Catalog UI plant',
      )).plants.page.items.single.plant;
      final detail = await repository.detail(plant.id),
          routine = detail.routines.single.routine;
      expect(plant.catalogSelection!.speciesId, 'sp_goeppertia_orbifolia');
      expect(detail.suggestions, hasLength(2));
      expect(routine.originalSuggestionId, isNot(routine.appliedSuggestionId));
      expect(routine.actualCareCount, 1);
      await press('Plants');
      await press('Add a plant');
      expect(field('Search species'), findsNothing);
      expect(
        tester.widget<TextField>(field('Plant name')).controller!.text,
        'Catalog draft recovery',
      );
      expect(
        tester.widget<TextField>(field('Selected species')).controller!.text,
        'Spathiphyllum wallisii',
      );
      // Clean only the test's identified acknowledged draft.
      final draft = (await repository.editor(null)).draft!;
      expect(
        draft.fields.catalogSelection!.speciesId,
        'sp_spathiphyllum_wallisii',
      );
      await tester.tap(find.byTooltip('Cancel'));
      await settle();
      await press('Discard changes');
      expect(tester.takeException(), isNull);
      return;
    }
    await press('Plants');
    await press('Add a plant');
    expect(field('Search species'), findsOneWidget);
    await type('Search species', ' SWISS ');
    expect(find.text('Monstera'), findsOneWidget);
    await tester.tap(find.byTooltip('Species information').first);
    await settle();
    expect(find.text('Monstera deliciosa'), findsOneWidget);
    await tester.pageBack();
    await settle();
    expect(
      tester
          .widget<EditableText>(
            find.descendant(
              of: field('Search species'),
              matching: find.byType(EditableText),
            ),
          )
          .controller
          .text,
      ' SWISS ',
    );
    expect((await repository.editor(null)).draft, isNull);
    await type('Search species', 'pothos');
    await press('Golden pothos');
    expect(
      (await repository.editor(null)).draft!.fields.catalogSelection!.speciesId,
      'sp_epipremnum_aureum',
    );
    await type('Plant name', 'Catalog UI plant');
    await press('Fertilize routine');
    expect(tester.widget<TextField>(field('Interval')).controller!.text, '2');
    await press('Not sure');
    await press('Choose a date');
    await press('OK');
    await press('Review and save');
    await press('Confirm');
    final plant = (await repository.read(
      archived: false,
      query: 'Catalog UI plant',
    )).plants.page.items.single.plant;
    var detail = await repository.detail(plant.id);
    expect(detail.routines.single.actualCareCount, 0);
    expect(detail.suggestions, hasLength(1));
    await tester.tap(find.byTooltip('Edit plant'));
    await settle();
    await press('Change species');
    await type('Search species', 'orbifolia');
    await press('Calathea orbifolia');
    await press('Apply suggestion');
    await press('Review and save');
    await press('Confirm');
    detail = await repository.detail(plant.id);
    expect(detail.suggestions, hasLength(2));
    expect(detail.routines.single.routine.interval.count, 1);
    await press('Fertilized');
    await press('OK');
    await press('Confirm');
    detail = await repository.detail(plant.id);
    expect(detail.routines.single.actualCareCount, 1);
    await press('Archive plant');
    await press('Confirm');
    await press('Archived');
    await press('Catalog UI plant');
    await press('Restore plant');
    await press('Confirm');
    await tester.pageBack();
    await settle();
    await press('Add a plant');
    await type('Search species', 'peace');
    await press('Peace lily');
    await type('Plant name', 'Catalog draft recovery');
    expect(
      (await repository.editor(null)).draft!.fields.name,
      'Catalog draft recovery',
    );
    expect(tester.takeException(), isNull);
  });
}
