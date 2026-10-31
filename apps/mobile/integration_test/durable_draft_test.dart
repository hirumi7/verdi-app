import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'package:verdi_mobile/core/native/draft_bridge.g.dart';
import 'package:verdi_mobile/core/native/draft_repository_service.dart';

String newId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'actual native draft bridge, isolate restart, raw text and receipt recovery',
    (tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        var service = await DraftRepositoryService.open();
        const phase = String.fromEnvironment(
          'DRAFT_RECOVERY_PHASE',
          defaultValue: 'full',
        );
        if (phase != 'freeze') {
          addTearDown(() async => service.close());
        }
        expect(service.session.fileProtectionVerified, isFalse);
        final prior = await service.read();
        if (phase == 'recover') {
          final page = await service.pending();
          expect(page.items, hasLength(1));
          final pending = page.items.single;
          final frozen = await service.body(
            pending.commandId,
            pending.payloadHash,
          );
          expect(frozen.expectedRevision, prior?.revision);
          expect(
            await service.resolve(pending.commandId, pending.payloadHash),
            isNull,
          );
          final result = await service.commit(
            pending.commandId,
            pending.payloadHash,
          );
          expect(result.draftRevision, (prior?.revision ?? 0) + 1);
          final saved = (await service.read())!;
          expect(saved.rawFieldsCanonicalJson, frozen.rawFieldsCanonicalJson);
          expect(
            (jsonDecode(saved.rawFieldsCanonicalJson)['notes'] as String)
                .codeUnits,
            [0, 0xd800, 0x61, 0xd83c, 0xdf3f, 0xdc00],
          );
          final replay = await service.commit(
            pending.commandId,
            pending.payloadHash,
          );
          expect(replay.replayed, isTrue);
          expect(replay.draftRevision, result.draftRevision);
          return;
        }
        final draftId = prior?.draftId ?? newId();
        final raw = String.fromCharCodes([
          0,
          0xd800,
          0x61,
          0xd83c,
          0xdf3f,
          0xdc00,
        ]);
        final fields = <String, Object?>{
          'name': 'Native draft fern',
          'location': '',
          'notes': raw,
          'identityKind': 'custom',
          'coverPhotoId': null,
          'speciesId': null,
          'catalogSelection': null,
          'customSpeciesName': '',
          'customLight': 'unknown',
          'customToxicity': 'unknown',
          'routineInputs': [
            {'kind': 'water', 'count': '', 'unit': 'week', 'seed': null},
            {
              'kind': 'water',
              'count': 'bad raw number',
              'unit': 'month',
              'seed': {'kind': 'unknown', 'firstCheckDate': raw},
            },
          ],
          'baseRoutineRevisions': [],
          'speciesChoices': [],
        };
        final payload = <String, Object?>{
          'draftId': draftId,
          'expectedRevision': prior?.revision,
          'mode': 'add',
          'plantId': null,
          'basePlantRevision': null,
          'rawFields': fields,
          'photoIds': [],
        };
        final write = DraftWriteMessage(
          commandId: newId(),
          draftId: draftId,
          expectedRevision: prior?.revision,
          rawFieldsCanonicalJson: canonicalCommandJson(fields),
          payloadHash: commandHash('SaveDraft', payload),
        );
        expect(
          write.payloadHash,
          SaveDraft(
            draftId: draftId,
            expectedRevision: prior?.revision,
            mode: DraftMode.add,
            fields: CustomPlantFields(
              name: 'Native draft fern',
              notes: raw,
              routines: [
                const RoutineInput(
                  kind: StandardCareKind.water,
                  count: '',
                  unit: IntervalUnit.week,
                  seedKind: null,
                  date: '',
                ),
                RoutineInput(
                  kind: StandardCareKind.water,
                  count: 'bad raw number',
                  unit: IntervalUnit.month,
                  seedKind: SeedKind.unknown,
                  date: raw,
                ),
              ],
            ),
          ).payloadHash,
        );
        final dataset = service.session.datasetId;
        final sessionId = service.session.sessionId;
        await service.freeze(write);
        if (phase == 'freeze') {
          // Leave native SQLite and service open. The external runner terminates
          // this app before a separately launched recover phase.
          return;
        }
        await service.close();
        service = await DraftRepositoryService.open();
        expect(service.session.datasetId, dataset);
        expect(service.session.sessionId, isNot(sessionId));
        expect(
          await service.resolve(write.commandId, write.payloadHash),
          isNull,
        );
        final restored = await service.body(write.commandId, write.payloadHash);
        expect(restored.rawFieldsCanonicalJson, write.rawFieldsCanonicalJson);
        expect(
          (await service.pending()).items.any(
            (p) => p.commandId == write.commandId,
          ),
          isTrue,
        );
        // Discard the fresh result, then recover the original durable receipt.
        await service.commit(write.commandId, write.payloadHash);
        await service.close();
        service = await DraftRepositoryService.open();
        final receipt = await service.resolve(
          write.commandId,
          write.payloadHash,
        );
        expect(receipt, isNotNull);
        expect(receipt!.replayed, isTrue);
        expect(receipt.draftRevision, (prior?.revision ?? 0) + 1);
        final replay = await service.commit(write.commandId, write.payloadHash);
        expect(replay.draftRevision, receipt.draftRevision);
        expect(replay.replayed, isTrue);
        final saved = (await service.read())!;
        expect(saved.revision, receipt.draftRevision);
        expect(saved.rawFieldsCanonicalJson, write.rawFieldsCanonicalJson);
        final decoded =
            jsonDecode(saved.rawFieldsCanonicalJson) as Map<String, dynamic>;
        expect((decoded['notes'] as String).codeUnits, raw.codeUnits);
        expect(decoded['routineInputs'][0]['seed'], isNull);
        expect(
          (decoded['routineInputs'][1]['seed']['firstCheckDate'] as String)
              .codeUnits,
          raw.codeUnits,
        );
        final stale = DraftWriteMessage(
          commandId: newId(),
          draftId: draftId,
          expectedRevision: write.expectedRevision,
          rawFieldsCanonicalJson: write.rawFieldsCanonicalJson,
          payloadHash: write.payloadHash,
        );
        await service.freeze(stale);
        await expectLater(
          service.commit(stale.commandId, stale.payloadHash),
          throwsA(
            isA<DraftStorageFailure>().having(
              (e) => e.code,
              'code',
              'STALE_TARGET',
            ),
          ),
        );
        await service.abandon(stale.commandId, stale.payloadHash);
        expect((await service.read())!.revision, saved.revision);
      });
    },
  );
}
