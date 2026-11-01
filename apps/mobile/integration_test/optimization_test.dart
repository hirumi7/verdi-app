import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/app/core_bootstrap.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/features/collection/data/repositories_impl/native_collection_repository.dart';
import 'package:verdi_mobile/features/optimization/presentation/optimization_page.dart';

// Dedicated simulator; creates only named synthetic QA content. Real PHPicker,
// native files/SQLite, Dart planner, ledger and main gallery are exercised.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'main optimization partial success preserves originals and identities',
    (t) async {
      final repo = await NativeCollectionRepository.open();
      final initial = await repo.mediaSnapshot();
      var plant = initial.plants.values
          .where((p) => p.name == 'Optimization QA fern')
          .firstOrNull;
      if (plant == null) {
        expect((await repo.editor(null)).draft, isNull);
        final draft = repo.newId();
        await repo.submit(
          SaveDraft(
            draftId: draft,
            expectedRevision: null,
            mode: DraftMode.add,
            fields: CustomPlantFields(
              name: 'Optimization QA fern',
              speciesName: 'Synthetic optimization fern',
            ),
          ),
        );
        final saved = await repo.confirm(
          await repo.prepare(SavePlant(draftId: draft, draftRevision: 1)),
        );
        plant = (await repo.detail(saved.primaryId!)).plant;
      }
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
      var snapshot = await repo.mediaSnapshot();
      if (snapshot.photos.values.where((p) => p.plantId == plant!.id).isEmpty) {
        for (final index in [0, 1]) {
          final draft = repo.newId();
          await repo.submit(
            SaveJournalDraft(
              draftId: draft,
              expectedRevision: null,
              plantId: plant.id,
              fields: JournalFields(
                text:
                    'Optimization synthetic ${index == 0 ? 'JPEG' : 'alpha PNG'}',
                entryDate: '2026-10-${20 + index}',
              ),
            ),
          );
          debugPrint(
            'OPTIMIZATION_PICK_${index == 0 ? 'GREEN_JPEG' : 'PURPLE_ALPHA_PNG'}',
          );
          final selectionFuture = MediaPlatformHostApi().choosePhoto('library');
          String? selection;
          bool chosen = false;
          selectionFuture.then((v) {
            selection = v;
            chosen = true;
          });
          for (var i = 0; i < 1800 && !chosen; i++) {
            await t.pump(const Duration(milliseconds: 100));
          }
          expect(selection, isNotNull);
          final prep = repo.newId();
          await repo.preparePhoto(
            draftId: draft,
            draftRevision: 1,
            preparationId: prep,
            selectionId: selection!,
            observedDate: LocalDate(2026, 10, 20 + index),
          );
          var status = await repo.photoPreparation(prep);
          for (var i = 0; i < 300 && status['kind'] == 'copying'; i++) {
            await t.pump(const Duration(milliseconds: 100));
            status = await repo.photoPreparation(prep);
          }
          expect(status['kind'], 'ready');
          await repo.confirm(
            await repo.prepare(
              SaveJournalEntry(draft, status['draftRevision'] as int),
            ),
          );
        }
      }
      snapshot = await repo.mediaSnapshot();
      final photos =
          snapshot.photos.values.where((p) => p.plantId == plant!.id).toList()
            ..sort((a, b) => a.observedDate.compareTo(b.observedDate));
      expect(photos.length, 2);
      if (photos[1].mime != 'image/png') {
        // Repair only this test's mistakenly selected synthetic second fixture.
        final old = photos[1], draft = repo.newId();
        expect(
          snapshot.mediaDrafts.values.where((d) => d.photoId == old.id),
          isEmpty,
        );
        await repo.submit(
          SaveMediaDraft(
            draftId: draft,
            expectedRevision: null,
            plantId: plant.id,
            photoId: old.id,
            basePhotoRevision: old.revision,
          ),
        );
        debugPrint('OPTIMIZATION_REPAIR_PICK_PURPLE_ALPHA_PNG');
        final choice = MediaPlatformHostApi().choosePhoto('library');
        String? selection;
        bool done = false;
        choice.then((v) {
          selection = v;
          done = true;
        });
        for (var i = 0; i < 1800 && !done; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(selection, isNotNull);
        final prep = repo.newId();
        await repo.preparePhoto(
          draftId: draft,
          draftRevision: 1,
          preparationId: prep,
          selectionId: selection!,
          observedDate: old.observedDate,
        );
        var status = await repo.photoPreparation(prep);
        for (var i = 0; i < 300 && status['kind'] == 'copying'; i++) {
          await t.pump(const Duration(milliseconds: 100));
          status = await repo.photoPreparation(prep);
        }
        expect(status['kind'], 'ready');
        await repo.confirm(
          await repo.prepare(
            ReplacePhoto(
              old.id,
              old.revision,
              preparationId: prep,
              draftId: draft,
              draftRevision: status['draftRevision'] as int,
            ),
          ),
        );
        snapshot = await repo.mediaSnapshot();
        photos[1] = snapshot.photos[old.id]!;
      }
      expect(photos[0].mime, 'image/jpeg');
      expect(photos[1].mime, 'image/png');
      // Set JPEG as cover through the existing guarded plant editor.
      if (snapshot.covers[plant.id] != photos[0].id) {
        final editor = await repo.editor(plant.id);
        expect(editor.draft, isNull);
        final draft = repo.newId();
        await repo.submit(
          SaveDraft(
            draftId: draft,
            expectedRevision: null,
            mode: DraftMode.edit,
            plantId: plant.id,
            basePlantRevision: plant.revision,
            fields: CustomPlantFields(
              name: plant.name,
              speciesName: plant.speciesName,
              coverPhotoId: photos[0].id,
            ),
          ),
        );
        await repo.confirm(
          await repo.prepare(SavePlant(draftId: draft, draftRevision: 1)),
        );
      }
      // Repeated runs discard only the prior job's failed synthetic test draft.
      final previousJob = await repo.optimization('latestOptimizationJob', {
        'plantId': plant.id,
      });
      if (previousJob?['state'] == 'complete') {
        final current = await repo.mediaSnapshot();
        for (final raw in previousJob!['results'] as List) {
          final target = (raw as Map).cast<String, Object?>();
          final draft = current.mediaDrafts[target['draftId']];
          if (target['state'] == 'failed' &&
              target['code'] == 'MEDIA_UNSUPPORTED' &&
              draft != null &&
              draft.plantId == plant.id) {
            await repo.submit(
              DiscardMediaDraft(draft.id, draft.revision, confirmed: true),
            );
          }
        }
      }
      final before = await repo.mediaSnapshot();
      Future<void> press(String label) async {
        final f = find.text(label);
        if (f.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            f,
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 80,
          );
        }
        await Scrollable.ensureVisible(t.element(f.last), alignment: .5);
        await t.pumpAndSettle();
        await t.tap(f.last);
        await t.pumpAndSettle();
      }

      await press('Plants');
      await press(plant.name);
      await press('Photos');
      await press('Optimize photos');
      expect(find.byType(OptimizationPage), findsOneWidget);
      // Select each current photo; use tile descendants rather than same-date text.
      for (final photo in photos) {
        final tile = find.byKey(ValueKey('optimize-${photo.id}'));
        if (tile.evaluate().isEmpty) {
          await t.scrollUntilVisible(
            tile,
            300,
            scrollable: find.byType(Scrollable).first,
            maxScrolls: 80,
          );
        }
        final checkbox = find.descendant(
          of: tile,
          matching: find.byType(Checkbox),
        );
        await Scrollable.ensureVisible(t.element(checkbox), alignment: .5);
        await t.pumpAndSettle();
        await t.tap(checkbox);
        await t.pumpAndSettle();
      }
      await press('Review selected photos (2)');
      await press('Cancel');
      expect((await repo.mediaSnapshot()).revision, before.revision);
      await press('Review selected photos (2)');
      await press('Replace selected originals');
      for (
        var i = 0;
        i < 600 &&
            find
                .text('Finished. Each photo’s result is shown below.')
                .evaluate()
                .isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final after = await repo.mediaSnapshot(),
          first = after.photos[photos[0].id]!,
          second = after.photos[photos[1].id]!;
      expect(first.revision, photos[0].revision + 1);
      expect(first.optimizedFromHash, photos[0].sha256);
      expect(first.width <= 1280 && first.height <= 1280, true);
      expect(first.observedDate, photos[0].observedDate);
      expect(first.createdAt, photos[0].createdAt);
      expect(second.toRow(), photos[1].toRow());
      expect(after.covers[plant.id], photos[0].id);
      for (final entry in before.journalEntries.values) {
        expect(after.journalEntries[entry.id]!.toRow(), entry.toRow());
      }
      expect(after.plants.keys.toSet(), before.plants.keys.toSet());
      expect(after.photos.keys.toSet(), before.photos.keys.toSet());
      for (final p in initial.plants.values.where((p) => p.id != plant!.id)) {
        expect(after.plants[p.id]!.revision, p.revision);
      }
      final job = await repo.optimization('latestOptimizationJob', {
        'plantId': plant.id,
      });
      expect(job!['state'], 'complete');
      expect(
        (job['results'] as List).map((r) => (r as Map)['state']).toList(),
        ['succeeded', 'failed'],
      );
      expect(
        after.mediaDrafts.values.where((d) => d.photoId == photos[1].id).length,
        1,
      );
      expect(t.takeException(), isNull);
      debugPrint('OPTIMIZATION_MAIN_PASSED');
      // Exercise the exact lost-prepare reply and terminal-cache recovery path.
      final currentPhoto = (await repo.mediaSnapshot()).photos[first.id]!;
      final preview = await repo.optimization('previewOptimization', {
        'datasetId': repo.datasetId,
        'plantId': plant.id,
        'targets': [
          {'photoId': first.id, 'photoRevision': currentPhoto.revision},
        ],
        'longEdge': 1280,
        'jpegQualityPercent': 85,
      });
      final interruptedJob = await repo.optimization('startOptimization', {
        'datasetId': repo.datasetId,
        'jobId': repo.newId(),
        'previewToken': preview!['previewToken'],
      });
      final child = ((interruptedJob!['results'] as List).single as Map)
          .cast<String, Object?>();
      await repo.submitOptimizationDraft(
        SaveMediaDraft(
          draftId: child['draftId'] as String,
          expectedRevision: null,
          plantId: plant.id,
          photoId: first.id,
          basePhotoRevision: currentPhoto.revision,
        ),
        child['draftCommandId'] as String,
      );
      var preparedPhoto = await repo.optimization('prepareOptimizationPhoto', {
        'jobId': interruptedJob['jobId'],
        'photoId': first.id,
      });
      for (var i = 0; i < 300 && preparedPhoto!['kind'] == 'copying'; i++) {
        await t.pump(const Duration(milliseconds: 100));
        preparedPhoto = await repo.photoPreparation(
          child['preparationId'] as String,
        );
      }
      expect(preparedPhoto!['kind'], 'ready');
      final replace = ReplacePhoto(
        first.id,
        currentPhoto.revision,
        preparationId: child['preparationId'] as String,
        draftId: child['draftId'] as String,
        draftRevision: preparedPhoto['draftRevision'] as int,
      );
      await repo.injectFaultForTest(CoreVerificationFault.afterFreezeReply);
      await expectLater(
        repo.prepare(replace, commandId: child['replaceCommandId'] as String),
        throwsA(isA<UnknownCommandOutcome>()),
      );
      final stopped = await repo.optimization('stopOptimization', {
        'jobId': interruptedJob['jobId'],
        'reason': 'interrupted',
      });
      expect(stopped!['state'], 'interrupted');
      final ordinary = await repo.prepare(replace);
      expect(ordinary.intent.commandId, isNot(child['replaceCommandId']));
      await repo.confirm(ordinary);
      expect(
        (await repo.mediaSnapshot()).photos[first.id]!.revision,
        currentPhoto.revision + 1,
      );
      debugPrint('OPTIMIZATION_RECOVERY_PASSED');
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
