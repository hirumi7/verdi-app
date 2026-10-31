import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'support/storage_scenario.dart';

void main() {
  test(
    'all current commands hydrate losslessly and native fixture stays current',
    () {
      final s = StorageScenario()..allCommands();
      expect(s.steps.length, 28);
      expect(s.projection.snapshot.plants, isEmpty);
      expect(
        s.projection.snapshot.drafts.values.single.fields.routines.single.count,
        'not a number',
      );
      expect(
        s
            .projection
            .snapshot
            .drafts
            .values
            .single
            .fields
            .routines
            .single
            .seedKind,
        isNull,
      );
      final fixture = File(
        '../verdi_native/Tests/VerdiNativeTests/Fixtures/core-storage-v1.json',
      ).readAsStringSync().trim();
      expect(jsonDecode(s.json()), jsonDecode(fixture));
    },
  );
  test(
    'maximum escaped raw draft insert/update remains within plan and page bounds',
    () {
      final s = StorageScenario(),
          draft = fixtureId(4),
          notes = List.filled(510000, '\\').join();
      final fields = CustomPlantFields(
        notes: notes,
        name: String.fromCharCodes([0xd800]),
      );
      for (final revision in [null, 1]) {
        final plan = s.run(
          SaveDraft(
            draftId: draft,
            expectedRevision: revision,
            mode: DraftMode.add,
            fields: fields,
          ),
        );
        expect(
          utf8.encode(canonicalCommandJson(plan.body())).length,
          lessThan(4 * 1024 * 1024),
        );
        expect(
          utf8
              .encode(canonicalCommandJson(s.rows['plant_drafts']!.single))
              .length,
          lessThan(2 * 1024 * 1024),
        );
        expect(s.projection.snapshot.drafts[draft]!.fields.notes, notes);
        expect(s.projection.snapshot.drafts[draft]!.fields.name.codeUnits, [
          0xd800,
        ]);
      }
    },
  );
  test('same-instant changed draft uses native updated-at descriptor', () {
    final s = StorageScenario(), id = fixtureId(3);
    s.run(
      SaveDraft(
        draftId: id,
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(name: 'first'),
      ),
    );
    final intent = s.projection.freeze(
      SaveDraft(
        draftId: id,
        expectedRevision: 1,
        mode: DraftMode.add,
        fields: CustomPlantFields(name: 'second'),
      ),
    );
    final plan = s.projection.plan(intent, fixtureId(2));
    final statement = asMap((plan.body()['statements'] as List).single);
    expect((statement['values'] as List)[7], {'native': 'transaction_instant'});
    expect((statement['values'] as List)[6], s.rows['plant_drafts']!.single[6]);
  });
  test(
    'hydration rejects corruption atomically and retains last valid view',
    () {
      final s = StorageScenario();
      final id = fixtureId(3);
      s.run(
        SaveDraft(
          draftId: id,
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(name: 'kept'),
        ),
      );
      final before = s.projection.snapshot;
      final broken = {
        for (final e in s.rows.entries)
          e.key: e.value.map((r) => List<Object?>.from(r)).toList(),
      };
      broken['plant_drafts']!.single[5] = '{"version":1,"fields":{}}';
      expect(
        () => s.projection.hydrate(broken, 1, 3),
        throwsA(
          isA<CommandRejected>().having(
            (e) => e.code,
            'code',
            'STORAGE_INVALID',
          ),
        ),
      );
      expect(identical(s.projection.snapshot, before), isTrue);
    },
  );
  test('frozen command roundtrip retains allocation slots and raw units', () {
    final s = StorageScenario();
    final original = s.projection.freeze(
      SaveDraft(
        draftId: fixtureId(3),
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: String.fromCharCodes([0xdc00]),
          notes: '\u0000',
        ),
      ),
    );
    final restored = s.projection.restoreFrozen(
      asMap(
        jsonDecode(canonicalCommandJson(s.projection.frozenJson(original))),
      ),
    );
    expect(restored.command.payloadHash, original.payloadHash);
    expect((restored.command as SaveDraft).fields.name.codeUnits, [0xdc00]);
    expect(restored.allocatedIds, original.allocatedIds);
  });
  test(
    'raw NUL survives draft but final text rejects it; BOM trims consistently',
    () {
      final s = StorageScenario(), id = fixtureId(3);
      s.run(
        SaveDraft(
          draftId: id,
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(
            name: '\uFEFFFern\uFEFF',
            speciesName: 'Synthetic',
            notes: 'bad\u0000note',
          ),
        ),
      );
      expect(
        () => s.projection.plan(
          s.projection.freeze(SavePlant(draftId: id, draftRevision: 1)),
          fixtureId(2),
        ),
        throwsA(isA<CommandRejected>()),
      );
      s.run(
        SaveDraft(
          draftId: id,
          expectedRevision: 1,
          mode: DraftMode.add,
          fields: CustomPlantFields(
            name: '\uFEFFFern\uFEFF',
            speciesName: 'Synthetic',
          ),
        ),
      );
      s.run(SavePlant(draftId: id, draftRevision: 2));
      expect(s.projection.snapshot.plants.values.single.name, 'Fern');
    },
  );
}
