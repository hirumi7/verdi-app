import 'dart:io';
import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'support/storage_scenario.dart';
import 'catalog_test.dart' show bundledCatalog;

StorageScenario customScenario({bool delete = false, bool unicode = false}) {
  final s = StorageScenario();
  s.projection.hydrateAccess(pro: true, revision: 1);
  final draft = fixtureId(s.sequence++);
  s.run(
    SaveDraft(
      draftId: draft,
      expectedRevision: null,
      mode: DraftMode.add,
      fields: CustomPlantFields(name: 'Fern', speciesName: 'Synthetic fern'),
    ),
  );
  s.run(SavePlant(draftId: draft, draftRevision: 1));
  s.run(
    CreateCustomCareType(unicode ? '\uFEFF\u200BFeed\uFEFF' : 'Clean leaves'),
  );
  final type = s.projection.snapshot.customCareTypes.values.single;
  s.run(
    CreateRoutine(
      plantId: s.plant,
      plantRevision: 1,
      careKind: StandardCareKind.custom,
      customTypeId: type.id,
      customTypeRevision: type.revision,
      interval: CareInterval(1, IntervalUnit.month),
      seedKind: SeedKind.known,
      seedDate: LocalDate(2026, 1, 31),
    ),
  );
  s.run(
    RenameCustomCareType(
      type.id,
      1,
      unicode ? '\uFEFF\u200BDust\uFEFF' : 'Dust leaves',
    ),
  );
  s.run(
    CompleteCurrent(s.target(StandardCareKind.custom), LocalDate(2026, 10, 31)),
  );
  s.run(
    CreateRoutine(
      plantId: s.plant,
      plantRevision: 1,
      careKind: StandardCareKind.custom,
      customTypeId: type.id,
      customTypeRevision: 2,
      interval: CareInterval(2, IntervalUnit.week),
      seedKind: SeedKind.unknown,
      seedDate: LocalDate(2026, 11, 4),
    ),
  );
  s.run(
    BulkComplete(
      careKind: StandardCareKind.custom,
      customTypeId: type.id,
      careDate: LocalDate(2026, 10, 31),
      targets: [
        for (final r in s.projection.snapshot.routines.values)
          CareTarget(
            plantId: s.plant,
            plantRevision: 1,
            routineId: r.id,
            routineRevision: r.revision,
            headId: r.headId,
            headRevision: r.headRevision,
          ),
      ],
    ),
  );
  s.run(
    Undo(
      s.steps.last['intent'] is Map
          ? (s.steps.last['intent'] as Map)['commandId'] as String
          : '',
    ),
  );
  s.run(RetireCustomCareType(type.id, 2));
  s.run(
    CreateRoutine(
      plantId: s.plant,
      plantRevision: 1,
      careKind: StandardCareKind.water,
      interval: CareInterval(1, IntervalUnit.week),
      seedKind: SeedKind.unknown,
      seedDate: LocalDate(2026, 11, 7),
    ),
  );
  if (delete) {
    s.run(ArchivePlant(plantId: s.plant, plantRevision: 1));
    s.run(DeletePlant(plantId: s.plant, plantRevision: 2));
  }
  return s;
}

StorageScenario addedCatalogRoutineScenario() {
  final s = StorageScenario(), catalog = bundledCatalog();
  s.projection.reader.catalog = catalog;
  final selection = catalog.entry('sp_epipremnum_aureum')!.selection,
      draft = fixtureId(s.sequence++);
  s.run(
    SaveDraft(
      draftId: draft,
      expectedRevision: null,
      mode: DraftMode.add,
      fields: CustomPlantFields(
        name: 'Catalog care',
        catalogSelection: selection,
      ),
    ),
  );
  s.run(SavePlant(draftId: draft, draftRevision: 1));
  final command = CreateRoutine(
    plantId: s.plant,
    plantRevision: 1,
    careKind: StandardCareKind.fertilize,
    interval: CareInterval(2, IntervalUnit.month),
    seedKind: SeedKind.known,
    seedDate: LocalDate(2026, 10, 20),
    catalogSelection: selection,
  );
  final frozen = s.projection.freeze(command);
  final json = s.projection.frozenJson(frozen);
  if (canonicalCommandJson(
        s.projection.frozenJson(s.projection.restoreFrozen(json)),
      ) !=
      canonicalCommandJson(json))
    throw StateError('Frozen catalog envelope changed');
  s.run(command);
  return s;
}

void main() {
  test(
    'new routine catalog envelope retains identity and original suggestion',
    () {
      final s = addedCatalogRoutineScenario();
      expect(
        s.projection.snapshot.suggestions.values.single.speciesId,
        'sp_epipremnum_aureum',
      );
      expect(
        s.projection.snapshot.routines.values.single.originalSuggestionId,
        isNotNull,
      );
    },
  );

  test(
    'equal-label types retain identity and cannot be bulk-completed together',
    () {
      final s = customScenario();
      s.run(const CreateCustomCareType('Dust leaves'));
      final type = s.projection.snapshot.customCareTypes.values.singleWhere(
        (t) => !t.retired,
      );
      s.run(
        CreateRoutine(
          plantId: s.plant,
          plantRevision: 1,
          careKind: StandardCareKind.custom,
          customTypeId: type.id,
          customTypeRevision: 1,
          interval: CareInterval(1, IntervalUnit.day),
          seedKind: SeedKind.unknown,
          seedDate: LocalDate(2026, 11, 1),
        ),
      );
      final targets = [
        for (final r in s.projection.snapshot.routines.values.where(
          (r) =>
              s.projection.snapshot.careKinds[r.id] == StandardCareKind.custom,
        ))
          CareTarget(
            plantId: s.plant,
            plantRevision: 1,
            routineId: r.id,
            routineRevision: r.revision,
            headId: r.headId,
            headRevision: r.headRevision,
          ),
      ];
      final intent = s.projection.freeze(
        BulkComplete(
          careKind: StandardCareKind.custom,
          customTypeId: type.id,
          careDate: LocalDate(2026, 10, 31),
          targets: targets,
        ),
      );
      expect(
        () => s.projection.plan(intent, fixtureId(2)),
        throwsA(isA<CommandRejected>()),
      );
      final retired = s.projection.snapshot.customCareTypes.values.singleWhere(
        (t) => t.retired,
      );
      final invalid = s.projection.freeze(
        CreateRoutine(
          plantId: s.plant,
          plantRevision: 1,
          careKind: StandardCareKind.custom,
          customTypeId: retired.id,
          customTypeRevision: retired.revision,
          interval: CareInterval(1, IntervalUnit.day),
          seedKind: SeedKind.unknown,
          seedDate: LocalDate(2026, 11, 1),
        ),
      );
      expect(
        () => s.projection.plan(invalid, fixtureId(2)),
        throwsA(isA<CommandRejected>()),
      );
    },
  );

  test(
    'custom lifecycle preserves old/new event labels and dates through hydration',
    () {
      final s = customScenario();
      final rows = s.rows['care_events']!
          .where((e) => e[4] == 'custom')
          .toList();
      expect(
        rows.map((e) => e[5]),
        containsAll(['Clean leaves', 'Dust leaves']),
      );
      expect(
        s.projection.snapshot.customCareTypes.values.single.retired,
        isTrue,
      );
      expect(s.projection.snapshot.customTypeIds.length, 2);
      expect(s.projection.snapshot.routines.length, 3);
      expect(s.rows['heads']!.first[3], '2026-11-30');
    },
  );
  test('custom deletion removes mappings and retains shared type', () {
    final s = customScenario(delete: true);
    expect(s.projection.snapshot.plants, isEmpty);
    expect(s.rows['routine_custom_types'], isEmpty);
    expect(s.rows['custom_care_types'], hasLength(1));
  });
  test(
    'frozen new commands roundtrip exactly and Free cannot create custom care',
    () {
      final s = customScenario();
      final type = s.projection.snapshot.customCareTypes.values.single;
      for (final command in <CoreCommand>[
        const CreateCustomCareType('Prune'),
        RenameCustomCareType(type.id, type.revision, 'Clean'),
        RetireCustomCareType(type.id, type.revision),
        CreateRoutine(
          plantId: s.plant,
          plantRevision: 1,
          careKind: StandardCareKind.mist,
          interval: CareInterval(1, IntervalUnit.day),
          seedKind: SeedKind.unknown,
          seedDate: LocalDate(2026, 11, 1),
        ),
      ]) {
        final frozen = s.projection.freeze(command);
        final json = s.projection.frozenJson(frozen);
        expect(s.projection.frozenJson(s.projection.restoreFrozen(json)), json);
      }
      s.projection.hydrateAccess(pro: false, revision: 2);
      final f = s.projection.freeze(const CreateCustomCareType('Prune'));
      expect(
        s.projection.reader
            .prepare(
              datasetId: s.projection.datasetId,
              command: f.command,
              commandId: f.commandId,
            )
            .effects
            .gate,
        PreviewGate.proRequired,
      );
    },
  );
  test('fixture remains reproducible', () {
    expect(
      File(
        '../verdi_native/Tests/VerdiNativeTests/Fixtures/custom-storage-v5.json',
      ).readAsStringSync().trim(),
      customScenario(delete: true).json(),
    );
  });
}
