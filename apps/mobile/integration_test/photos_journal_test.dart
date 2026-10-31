import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/core/di/injection.dart';
import 'package:verdi_mobile/features/collection/data/repositories/collection_repository.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_mobile/features/media/presentation/widgets/photo_preview.dart';

/// Uses the actual native library picker. The operator selects the seeded
/// synthetic image in the OS UI; no mocked selection or image bytes cross Dart.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const phase = String.fromEnvironment(
    'VERDI_MEDIA_PHASE',
    defaultValue: 'seed',
  );
  testWidgets('photos and journal $phase on retained installation', (
    tester,
  ) async {
    await getIt.reset();
    final setup = await NativeCollectionRepository.open();
    var snapshot = await setup.mediaSnapshot();
    var plant = snapshot.plants.values
        .where(
          (p) =>
              p.name == 'Media UI fern' &&
              p.speciesName == 'Synthetic media fern',
        )
        .firstOrNull;
    if (phase == 'seed' && plant == null) {
      final openDraft = (await setup.editor(null)).draft;
      expect(openDraft, isNull, reason: 'Never overwrite another add draft');
      final draft = setup.newId();
      await setup.submit(
        SaveDraft(
          draftId: draft,
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(
            name: 'Media UI fern',
            speciesName: 'Synthetic media fern',
            routines: [
              RoutineInput(
                kind: StandardCareKind.water,
                count: '7',
                unit: IntervalUnit.day,
                seedKind: SeedKind.unknown,
                date: setup.today.toString(),
              ),
            ],
          ),
        ),
      );
      final result = await setup.confirm(
        await setup.prepare(SavePlant(draftId: draft, draftRevision: 1)),
      );
      plant = (await setup.detail(result.primaryId!)).plant;
    }
    expect(plant, isNotNull);
    final plantId = plant!.id;
    final retainedIds = snapshot.plants.keys
        .where((id) => id != plantId)
        .toSet();
    await setup.close();
    await tester.pumpWidget(const CoreBootstrap());
    Future<void> settle() async {
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(LinearProgressIndicator).evaluate().isEmpty &&
            find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          await tester.pumpAndSettle();
          return;
        }
      }
      throw StateError('Still loading');
    }

    Finder field(String label) => find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == label,
    );
    Future<void> press(String label) async {
      await settle();
      final finder = find.text(label);
      if (finder.evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 40,
        );
      }
      final target = finder.last;
      await Scrollable.ensureVisible(tester.element(target), alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await settle();
    }

    Future<void> enter(String label, String value) async {
      if (field(label).evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          field(label),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
          maxScrolls: 30,
        );
      }
      await tester.enterText(field(label), value);
      await tester.pump(const Duration(milliseconds: 400));
      await settle();
    }

    Future<void> chooseLibrary() async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle();
      if (find.text('Library').evaluate().isEmpty) {
        final scroll = find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first;
        tester.state<ScrollableState>(scroll).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Library'),
          200,
          scrollable: scroll,
          maxScrolls: 40,
        );
      }
      await Scrollable.ensureVisible(
        tester.element(find.text('Library').first),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library').first);
      debugPrint(
        'VERDI_MEDIA_NATIVE_PICKER_WAITING: choose the synthetic image in the OS picker',
      );
      for (var i = 0; i < 1200 && find.text('OK').evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.text('OK'),
        findsOneWidget,
        reason: 'OS selection must reach the explicit observation-date dialog',
      );
      await tester.tap(find.text('OK'));
      await settle();
      expect(find.byType(PhotoPreview), findsWidgets);
    }

    await settle();
    await press('Plants');
    await press('Media UI fern');
    final repository =
        getIt<CollectionRepository>() as NativeCollectionRepository;
    final before = await repository.detail(plantId),
        nextCheck = before.routines.single.routine.nextCheck;
    if (phase == 'seed') {
      await press('New journal entry');
      await enter('Note', 'Original photo journal note');
      await enter('Observation date', '2026-10-20');
      await chooseLibrary();
      await press('Save entry');
      await press('Confirm');
      snapshot = await repository.mediaSnapshot();
      final entry = snapshot.journalEntries.values.singleWhere(
        (e) => e.plantId == plantId,
      );
      expect(entry.entryDate, LocalDate(2026, 10, 20));
      expect(entry.photoIds.length, 1);
      expect(snapshot.photos[entry.photoIds.single]!.plantId, plantId);
      await press('New journal entry');
      await enter('Note', 'Unfinished durable journal note');
      await enter('Observation date', '2026-10-19');
      final draft = (await repository.mediaSnapshot()).journalDrafts.values
          .singleWhere((d) => d.plantId == plantId && d.entryId == null);
      expect(draft.fields.text, 'Unfinished durable journal note');
      debugPrint(
        'VERDI_MEDIA_SEED_COMPLETE plant=$plantId photo=${entry.photoIds.single} draft=${draft.id}',
      );
    } else if (phase == 'recover') {
      snapshot = await repository.mediaSnapshot();
      final entry = snapshot.journalEntries.values.singleWhere(
            (e) => e.plantId == plantId,
          ),
          photo = snapshot.photos[entry.photoIds.single]!;
      expect(entry.text, 'Original photo journal note');
      expect(photo.plantId, plantId);
      expect(
        await repository.draftPreparations(
          snapshot.journalDrafts.values
              .singleWhere((d) => d.plantId == plantId)
              .id,
        ),
        isEmpty,
      );
      await press('New journal entry');
      expect(
        tester.widget<TextField>(field('Note')).controller!.text,
        'Unfinished durable journal note',
      );
      await press('Save entry');
      await press('Confirm');
      await press('Photos');
      await press(
        DateFormat.yMMMd('en').format(
          DateTime(
            photo.observedDate.year,
            photo.observedDate.month,
            photo.observedDate.day,
          ),
        ),
      );
      await press('Set as cover');
      await press('Review and save');
      await press('Confirm');
      snapshot = await repository.mediaSnapshot();
      expect(snapshot.covers[plantId], photo.id);
      expect(snapshot.photos[photo.id]!.sha256, photo.sha256);
      debugPrint('VERDI_MEDIA_RECOVERY_COMPLETE stable_photo=${photo.id}');
    } else if (phase == 'replace') {
      snapshot = await repository.mediaSnapshot();
      final photo = snapshot.photos.values.singleWhere(
            (p) => p.plantId == plantId,
          ),
          oldId = photo.id,
          oldRevision = photo.revision;
      final oldHash = photo.sha256;
      await press('Photos');
      await press(
        DateFormat.yMMMd('en').format(
          DateTime(
            photo.observedDate.year,
            photo.observedDate.month,
            photo.observedDate.day,
          ),
        ),
      );
      await chooseLibrary();
      await press('Review replacement');
      await press('Confirm');
      snapshot = await repository.mediaSnapshot();
      expect(snapshot.photos[oldId]!.revision, oldRevision + 1);
      expect(snapshot.photos[oldId]!.sha256, isNot(oldHash));
      expect(snapshot.covers[plantId], oldId);
      expect(
        snapshot.journalEntries.values.any((e) => e.photoIds.contains(oldId)),
        isTrue,
      );
      expect(
        snapshot.mediaDrafts.values.where((d) => d.plantId == plantId),
        isEmpty,
      );
      await press('Delete photo');
      await press('Confirm');
      snapshot = await repository.mediaSnapshot();
      expect(snapshot.photos.containsKey(oldId), isFalse);
      expect(snapshot.covers[plantId], isNull);
      expect(
        snapshot.journalEntries.values
            .singleWhere((e) => e.text == 'Original photo journal note')
            .photoIds,
        isEmpty,
      );
      debugPrint('VERDI_MEDIA_REPLACE_DELETE_COMPLETE stable_photo=$oldId');
    } else if (phase == 'cover_export') {
      await tester.tap(find.byTooltip('Edit plant'));
      await settle();
      await chooseLibrary();
      await press('Review and save');
      await press('Confirm');
      snapshot = await repository.mediaSnapshot();
      final id = snapshot.covers[plantId]!;
      final photo = snapshot.photos[id]!;
      expect(photo.plantId, plantId);
      expect(photo.draftId, isNull);
      await press('Photos');
      await press(
        DateFormat.yMMMd('en').format(
          DateTime(
            photo.observedDate.year,
            photo.observedDate.month,
            photo.observedDate.day,
          ),
        ),
      );
      await press('Export original');
      await press('Share original');
      debugPrint(
        'VERDI_MEDIA_SHARE_WAITING: dismiss the OS share sheet without sharing',
      );
      for (
        var i = 0;
        i < 1200 && find.text('Sharing cancelled.').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Sharing cancelled.'), findsOneWidget);
      snapshot = await repository.mediaSnapshot();
      expect(snapshot.covers[plantId], id);
      expect(snapshot.photos[id]!.sha256, photo.sha256);
      debugPrint('VERDI_MEDIA_COVER_EXPORT_COMPLETE stable_photo=$id');
    }
    if (phase == 'verify') {
      snapshot = await repository.mediaSnapshot();
      final cover = snapshot.covers[plantId];
      expect(cover, isNotNull);
      expect(snapshot.photos[cover]!.plantId, plantId);
      expect(
        snapshot.journalEntries.values
            .where((e) => e.plantId == plantId)
            .map((e) => e.text),
        containsAll([
          'Original photo journal note',
          'Unfinished durable journal note',
        ]),
      );
      expect(
        snapshot.mediaDrafts.values.where((d) => d.plantId == plantId),
        isEmpty,
      );
      await press('Photos');
      expect(find.byType(PhotoPreview), findsWidgets);
      expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
      debugPrint('VERDI_MEDIA_FINAL_REOPEN_COMPLETE');
    }
    expect(
      (await repository.detail(plantId)).routines.single.routine.nextCheck,
      nextCheck,
    );
    snapshot = await repository.mediaSnapshot();
    expect(snapshot.plants.keys.toSet().containsAll(retainedIds), isTrue);
    expect(tester.takeException(), isNull);
    await repository.close();
  }, timeout: const Timeout(Duration(minutes: 8)));
}
