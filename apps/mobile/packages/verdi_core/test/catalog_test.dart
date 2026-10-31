import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:verdi_core/verdi_core.dart';
import 'support/storage_scenario.dart';

CatalogState bundledCatalog() {
  final manifest =
      (jsonDecode(File('../../assets/catalog/manifest.json').readAsStringSync())
              as Map)
          .cast<String, Object?>();
  final version = manifest['catalogVersion'] as String;
  return CatalogState(
    version: version,
    manifest: manifest,
    entries:
        (jsonDecode(
                  File('../../assets/catalog/entries.json').readAsStringSync(),
                )
                as List)
            .map((e) => CatalogEntry(version, (e as Map).cast())),
    popularIds: (manifest['popularIds'] as List).cast(),
  );
}

CatalogEntry entry(
  String id,
  String name, {
  String? scientific,
  List<String> aliases = const [],
}) => CatalogEntry('test', {
  'id': id,
  'lifecycle': 'active',
  'commonName': name,
  'scientificName': scientific ?? name,
  'altNames': aliases,
  'suggestions': <Object?>[],
});
void main() {
  test('reviewed bundle has exact 24 Popular and only supported proposals', () {
    final c = bundledCatalog();
    expect(c.entries, hasLength(24));
    expect(c.popularComplete, isTrue);
    expect(c.search('  ').map((e) => e.id), c.popularIds);
    expect(
      c.search(' SWISS ').map((e) => e.id),
      contains('sp_monstera_deliciosa'),
    );
    expect(
      c.search('cheese   pl').map((e) => e.id),
      contains('sp_monstera_deliciosa'),
    );
    expect(c.search('plant Swiss'), isEmpty);
    expect(c.search('monstrea'), isEmpty);
    expect(c.entries.expand((e) => e.selection.suggestions), hasLength(4));
    expect(
      c.entries
          .expand((e) => e.selection.suggestions)
          .every((s) => s.careKind == StandardCareKind.fertilize),
      isTrue,
    );
    expect(c.entries.where((e) => e.toxicity['value'] == 'non-toxic'), isEmpty);
  });
  test('full Unicode folding, whitespace, literal accents and composition', () {
    expect(
      normalizeCatalogName(' \u0085Straße\u2003Σς  İ '),
      'strasse σσ i\u0307',
    );
    final c = CatalogState(
      version: 'test',
      entries: [entry('a', 'café'), entry('b', 'cafe\u0301')],
    );
    expect(c.search('café').single.id, 'a');
    expect(c.search('cafe\u0301').single.id, 'b');
    expect(c.search('cafe').map((e) => e.id), ['b']);
  });
  test('best alias rank, uniqueness and scalar ties across full inventory', () {
    final c = CatalogState(
      version: 'test',
      entries: [
        for (var i = 0; i < 300; i++) entry('id$i', 'entry $i'),
        entry('c', 'eggplant'),
        entry('b', 'alpha plant'),
        entry('a', 'plant alpha', aliases: ['plant other']),
        entry('d', 'z plant plant', aliases: ['plant beta']),
        entry('x', 'same', scientific: '\u{10000}'),
        entry('y', 'same', scientific: '\uE000'),
      ],
    );
    expect(c.search('plant').map((e) => e.id), ['a', 'd', 'b', 'c']);
    expect(c.search('same').map((e) => e.id), ['y', 'x']);
    expect(c.search('entry 299').single.id, 'id299');
  });
  test('invalid Popular does not silently substitute or partially display', () {
    final c = CatalogState(
      version: 'test',
      entries: [entry('a', 'A')],
      popularIds: ['a', 'missing'],
    );
    expect(c.popularComplete, isFalse);
    expect(c.search(''), isEmpty);
    expect(c.search('a'), hasLength(1));
  });
  test(
    'catalog160 succeeds, catalog161 and custom121 keep their raw drafts',
    () {
      for (final length in [160, 161]) {
        final s = StorageScenario(),
            e = entry('sp_long', 'Long', scientific: 'a' * length);
        s.projection.reader.catalog = CatalogState(
          version: 'test',
          entries: [e],
        );
        final id = fixtureId(s.sequence++);
        s.run(
          SaveDraft(
            draftId: id,
            expectedRevision: null,
            mode: DraftMode.add,
            fields: CustomPlantFields(
              name: 'Long',
              catalogSelection: e.selection,
            ),
          ),
        );
        if (length == 160) {
          s.run(SavePlant(draftId: id, draftRevision: 1));
          expect(
            s.projection.snapshot.plants.values.single.speciesName.length,
            160,
          );
        } else {
          expect(
            () => s.run(SavePlant(draftId: id, draftRevision: 1)),
            throwsA(isA<CommandRejected>()),
          );
          expect(
            s
                .projection
                .snapshot
                .drafts[id]!
                .fields
                .catalogSelection!
                .speciesNameSnapshot
                .length,
            161,
          );
        }
      }
      final s = StorageScenario(), id = fixtureId(900);
      s.run(
        SaveDraft(
          draftId: id,
          expectedRevision: null,
          mode: DraftMode.add,
          fields: CustomPlantFields(name: 'Custom', speciesName: 'a' * 121),
        ),
      );
      expect(
        () => s.run(SavePlant(draftId: id, draftRevision: 1)),
        throwsA(isA<CommandRejected>()),
      );
      expect(s.projection.snapshot.drafts[id]!.fields.speciesName.length, 121);
    },
  );
  test(
    'persistence, original snapshots, explicit keep/apply and later care retain links',
    () {
      final s = catalogScenario();
      expect(s.steps.length, greaterThan(10));
      final routine = s.projection.snapshot.routines.values.single;
      expect(routine.originalSuggestionId, isNotNull);
      expect(routine.appliedSuggestionId, isNot(routine.originalSuggestionId));
      expect(s.projection.snapshot.suggestions, hasLength(2));
      expect(
        s.projection.snapshot.plants.values.single.catalogSelection,
        isNull,
      );
      expect(routine.actualCareCount, 2);
    },
  );
}

StorageScenario catalogScenario({bool unknownSeed = false}) {
  final s = StorageScenario(), c = bundledCatalog();
  s.projection.reader.catalog = c;
  void save(
    CatalogSelection? selected, {
    bool apply = false,
    bool add = false,
  }) {
    final draft = fixtureId(s.sequence++);
    final p = add ? null : s.projection.snapshot.plants.values.single;
    final bases = {
      for (final r in s.projection.snapshot.routines.values) r.id: r.revision,
    };
    s.run(
      SaveDraft(
        draftId: draft,
        expectedRevision: null,
        mode: add ? DraftMode.add : DraftMode.edit,
        plantId: p?.id,
        basePlantRevision: p?.revision,
        fields: CustomPlantFields(
          name: 'Catalog plant',
          speciesName: selected?.speciesNameSnapshot ?? 'Custom again',
          catalogSelection: selected,
          baseRoutineRevisions: bases,
          keepRoutineIds: apply ? [] : bases.keys,
          applyRoutineIntervals: apply
              ? {
                  for (final id in bases.keys)
                    id: CareInterval(3, IntervalUnit.month),
                }
              : {},
          routines: add
              ? [
                  RoutineInput(
                    kind: StandardCareKind.fertilize,
                    count: '2',
                    unit: IntervalUnit.month,
                    seedKind: unknownSeed ? SeedKind.unknown : SeedKind.known,
                    date: unknownSeed ? '2026-10-31' : '2026-10-20',
                  ),
                ]
              : [],
        ),
      ),
    );
    s.run(SavePlant(draftId: draft, draftRevision: 1));
  }

  save(c.entry('sp_epipremnum_aureum')!.selection, add: true);
  save(c.entry('sp_goeppertia_orbifolia')!.selection, apply: true);
  final complete = s.run(
    CompleteCurrent(
      s.target(StandardCareKind.fertilize),
      LocalDate(2026, 10, 31),
    ),
  );
  s.run(Undo(complete.intent.commandId));
  s.run(
    CompleteCurrent(
      s.target(StandardCareKind.fertilize),
      LocalDate(2026, 10, 31),
    ),
  );
  save(c.entry('sp_spathiphyllum_wallisii')!.selection);
  save(null);
  s.run(
    ArchivePlant(
      plantId: s.plant,
      plantRevision: s.projection.snapshot.plants[s.plant]!.revision,
    ),
  );
  s.run(
    RestorePlant(
      plantId: s.plant,
      plantRevision: s.projection.snapshot.plants[s.plant]!.revision,
    ),
  );
  return s;
}
