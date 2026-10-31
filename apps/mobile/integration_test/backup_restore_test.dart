import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/features/backup/data/backup_service.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';

/// Run only on the named disposable Backup QA simulator. Never replaces the
/// retained development simulator's collection. OS picker/share need a driver.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('backup UI retained native collection and restore reopen', (
    tester,
  ) async {
    const phase = String.fromEnvironment(
      'VERDI_BACKUP_PHASE',
      defaultValue: 'seed',
    );
    final repository = await NativeCollectionRepository.open();
    if (phase == 'seed') {
      final snapshot = await repository.mediaSnapshot();
      if (snapshot.plants.isEmpty) {
        final draft = repository.newId();
        await repository.submit(
          SaveDraft(
            draftId: draft,
            expectedRevision: null,
            mode: DraftMode.add,
            fields: CustomPlantFields(
              name: 'Backup QA fern',
              speciesName: 'Synthetic fern',
              notes: 'Backup QA note',
              routines: [
                RoutineInput(
                  kind: StandardCareKind.water,
                  count: '7',
                  unit: IntervalUnit.day,
                  seedKind: SeedKind.known,
                  date: '2026-10-20',
                ),
              ],
            ),
          ),
        );
        final saved = await repository.mediaSnapshot();
        final preview = await repository.prepare(
          SavePlant(
            draftId: draft,
            draftRevision: saved.drafts[draft]!.revision,
          ),
        );
        await repository.confirm(preview);
      }
    }
    final snapshot = await repository.mediaSnapshot();
    if (phase == 'rich') {
      expect(snapshot.plants.length, 7);
      expect(snapshot.plants.values.where((p) => p.archived).length, 1);
      expect(snapshot.photos.length, 3);
      expect(snapshot.journalEntries.length, 1);
      expect(snapshot.journalDrafts.length, 1);
      expect(snapshot.mediaDrafts.length, 1);
      expect(snapshot.drafts.length, 1);
      expect(repository.settings['theme'], 'dark');
      expect(repository.settings['localeOverride'], 'en-GB');
    } else {
      expect(
        snapshot.plants.values.any((p) => p.name == 'Backup QA fern'),
        isTrue,
      );
    }
    await repository.close();
    await tester.pumpWidget(const CoreBootstrap());
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Settings').evaluate().isNotEmpty) break;
    }
    if (phase == 'rich') {
      await tester.tap(find.text('Plants').last);
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 && find.text('6 active plants').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.scrollUntilVisible(
        find.text('Fern edited'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.text('Fern edited').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Photos').first);
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 100 && find.text('20 Oct 2026').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('20 Oct 2026').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review replacement'),
        300,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      expect(find.text('Review replacement'), findsOneWidget);
      await tester.tap(find.text('Review replacement'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Cancel'), findsWidgets);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      return;
    }
    await NativeBackupService().call('latestBackupOperation', {});
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backup & restore'));
    await tester.pumpAndSettle();
    if (phase == 'seed') {
      await tester.tap(find.text('Create backup'));
      for (var i = 0; i < 300; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.text('File created').evaluate().isNotEmpty) break;
      }
      expect(find.text('File created'), findsOneWidget);
    }
    // Leave the actual screen visible for the OS interaction driver.
    await tester.pump(const Duration(seconds: 1));
  });
}
