import 'package:test/test.dart' hide Skip;
import 'package:verdi_core/verdi_core.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';
LocalDate date(String text) => LocalDate.parse(text);
Matcher rejected(String code) => throwsA(
  isA<CommandRejected>()
      .having((error) => error.code, 'code', code)
      .having((error) => error.committed, 'committed', false),
);

CustomPlantFields fields({
  String name = ' Fern ',
  String species = ' Synthetic fern ',
  String notes = '  personal notes\n',
  String location = ' desk ',
  Iterable<RoutineInput> routines = const [],
  Map<String, int> bases = const {},
  Iterable<String> keep = const [],
  CustomLight light = CustomLight.unknown,
  CustomToxicity toxicity = CustomToxicity.unknown,
}) => CustomPlantFields(
  name: name,
  speciesName: species,
  location: location,
  notes: notes,
  routines: routines,
  baseRoutineRevisions: bases,
  keepRoutineIds: keep,
  light: light,
  toxicity: toxicity,
);

RoutineInput known({
  StandardCareKind kind = StandardCareKind.water,
  String count = '1',
  String day = '2026-10-20',
}) => RoutineInput(
  kind: kind,
  count: count,
  unit: IntervalUnit.week,
  seedKind: SeedKind.known,
  date: day,
);
RoutineInput unknown({
  StandardCareKind kind = StandardCareKind.mist,
  String day = '2026-11-01',
}) => RoutineInput(
  kind: kind,
  count: '2',
  unit: IntervalUnit.day,
  seedKind: SeedKind.unknown,
  date: day,
);

final class Harness {
  int serial = 100;
  int draftSerial = 100000;
  LocalDate today = date('2026-10-25');
  DateTime instant = DateTime.utc(2026, 10, 25, 12);
  Duration elapsed = Duration.zero;
  late final store = MemoryCoreStore(
    datasetId: id(1),
    nextId: () => id(serial++),
  );
  late var core = MemoryOperationCoordinator(store, clock: reading);
  ClockReading reading() =>
      ClockReading(CareClock(today, instant, 'Etc/UTC'), elapsed);
  CollectionSnapshot get snapshot => core.readCollection(datasetId: id(1));
  void restart() {
    core = MemoryOperationCoordinator(store, clock: reading);
  }

  CommandSuccess submit(CoreCommand command) {
    final intent = core.freeze(datasetId: id(1), command: command);
    return core.execute(
      datasetId: id(1),
      commandId: intent.commandId,
      command: command,
    );
  }

  PlantDraft draft(
    CustomPlantFields fields, {
    PlantDraft? old,
    PlantCore? plant,
  }) {
    final command = SaveDraft(
      draftId: old?.id ?? id(draftSerial++),
      expectedRevision: old?.revision,
      mode: plant == null ? DraftMode.add : DraftMode.edit,
      plantId: plant?.id,
      basePlantRevision: plant?.revision,
      fields: fields,
    );
    final saved = submit(command);
    return snapshot.drafts[saved.primaryId]!;
  }

  PreparedCommand preview(CoreCommand command, {String? commandId}) =>
      core.prepare(datasetId: id(1), command: command, commandId: commandId);
  PreparedCommand previewDraft(PlantDraft draft, {String? commandId}) =>
      preview(
        SavePlant(draftId: draft.id, draftRevision: draft.revision),
        commandId: commandId,
      );
  CommandSuccess confirm(PreparedCommand preview) => core.execute(
    datasetId: id(1),
    commandId: preview.intent.commandId,
    command: preview.intent.command,
    previewToken: preview.previewToken,
  );
  PlantCore add({Iterable<RoutineInput> routines = const []}) {
    final saved = confirm(previewDraft(draft(fields(routines: routines))));
    return snapshot.plants[saved.primaryId]!;
  }

  CareTarget target([RoutineCore? routine]) {
    final r = routine ?? snapshot.routines.values.first;
    return CareTarget(
      plantId: r.plantId,
      plantRevision: snapshot.plants[r.plantId]!.revision,
      routineId: r.id,
      routineRevision: r.revision,
      headId: r.headId,
      headRevision: r.headRevision,
    );
  }
}

void main() {
  test('multi-routine plant preview identifies each routine and date', () {
    final h = Harness();
    final preview = h.previewDraft(
      h.draft(fields(routines: [known(), unknown()])),
    );
    expect(preview.effects.rows.map((r) => r.careKind), [
      StandardCareKind.water,
      StandardCareKind.mist,
    ]);
    expect(
      preview.effects.rows.every(
        (r) => r.careLabel != null && r.careLabel!.isNotEmpty,
      ),
      isTrue,
    );
    expect(preview.effects.rows.map((r) => r.newNextCheck), [
      date('2026-10-27'),
      date('2026-11-01'),
    ]);
  });
  test(
    'unselected seed rejects an unhashable hidden date before persistence',
    () {
      final h = Harness();
      for (final hiddenDate in ['2026-10-25', 'x' * (1024 * 1024 + 1)]) {
        final before = h.snapshot;
        expect(
          () => h.draft(
            fields(
              routines: [
                RoutineInput(
                  kind: StandardCareKind.water,
                  count: '7',
                  unit: IntervalUnit.day,
                  seedKind: null,
                  date: hiddenDate,
                ),
              ],
            ),
          ),
          rejected('FIELD_INVALID'),
        );
        expect(h.snapshot, same(before));
        expect(h.snapshot.drafts, isEmpty);
      }
      final draft = h.draft(
        fields(
          routines: [
            const RoutineInput(
              kind: StandardCareKind.water,
              count: '7',
              unit: IntervalUnit.day,
              seedKind: null,
              date: '',
            ),
          ],
        ),
      );
      expect(draft.fields.routines.single.date, isEmpty);
    },
  );
  test(
    'unselected raw seed survives recovery but cannot produce saved care',
    () {
      final h = Harness();
      final draft = h.draft(
        fields(
          routines: [
            const RoutineInput(
              kind: StandardCareKind.water,
              count: '7',
              unit: IntervalUnit.day,
              seedKind: null,
              date: '',
            ),
          ],
        ),
      );
      h.restart();
      final recovered = h.core.getPlantEditor(datasetId: id(1)).draft!;
      expect(recovered.fields.routines.single.seedKind, isNull);
      final before = h.snapshot;
      expect(
        () => h.previewDraft(draft),
        throwsA(
          isA<CommandRejected>().having(
            (e) => e.fields['routineInputs[0].seed'],
            'exact seed path',
            'FIELD_INVALID',
          ),
        ),
      );
      expect(h.snapshot, same(before));
      expect(h.snapshot.plants, isEmpty);
      expect(h.snapshot.routines, isEmpty);
    },
  );
  test('invalid revision bounds are typed rejections with no state change', () {
    final h = Harness();
    final draft = h.draft(fields());
    final before = h.snapshot;
    for (final revision in [0, -1, 9007199254740992, -9223372036854775808]) {
      expect(
        () => h.preview(SavePlant(draftId: draft.id, draftRevision: revision)),
        rejected('FIELD_INVALID'),
      );
    }
    expect(h.snapshot, same(before));
  });

  test(
    'invalid preview leaves no new pending intent; a valid frozen intent survives re-review failure',
    () {
      final h = Harness();
      final invalid = h.draft(fields(name: ''));
      expect(() => h.previewDraft(invalid), rejected('FIELD_INVALID'));
      expect(h.core.listPendingCommands(datasetId: id(1)), isEmpty);
      final valid = h.draft(fields(), old: invalid);
      final preview = h.previewDraft(valid);
      h.draft(fields(name: 'Changed later'), old: valid);
      expect(
        () => h.preview(
          preview.intent.command,
          commandId: preview.intent.commandId,
        ),
        rejected('STALE_TARGET'),
      );
      expect(
        h.core.listPendingCommands(datasetId: id(1)).single.commandId,
        preview.intent.commandId,
      );
    },
  );

  test(
    'two coordinators share revision and receipt authority, not preview sessions',
    () {
      final h = Harness();
      final draft = h.draft(fields());
      final preview = h.previewDraft(draft);
      final other = MemoryOperationCoordinator(h.store, clock: h.reading);
      expect(
        () => other.execute(
          datasetId: id(1),
          commandId: preview.intent.commandId,
          command: preview.intent.command,
          previewToken: preview.previewToken,
        ),
        rejected('PREVIEW_STALE'),
      );
      final result = h.confirm(preview);
      final replay = other.execute(
        datasetId: id(1),
        commandId: preview.intent.commandId,
        command: preview.intent.command,
      );
      expect(replay.primaryId, result.primaryId);
      expect(replay.replayed, true);
      expect(other.readCollection(datasetId: id(1)).plants.length, 1);
    },
  );

  test(
    'draft cannot occupy a plant ID; generated ID collisions cannot commit',
    () {
      final h = Harness();
      final plant = h.add();
      expect(
        () => h.submit(
          SaveDraft(
            draftId: plant.id,
            expectedRevision: null,
            mode: DraftMode.add,
            fields: fields(),
          ),
        ),
        rejected('FIELD_INVALID'),
      );
      final badStore = MemoryCoreStore(datasetId: id(1), nextId: () => id(1));
      final badCore = MemoryOperationCoordinator(badStore, clock: h.reading);
      expect(
        () => badCore.freeze(
          datasetId: id(1),
          command: SaveDraft(
            draftId: id(2),
            expectedRevision: null,
            mode: DraftMode.add,
            fields: fields(),
          ),
        ),
        rejected('FIELD_INVALID'),
      );
      expect(badCore.readCollection(datasetId: id(1)).drafts, isEmpty);
    },
  );

  test(
    'seed overflow fails atomically and retains the acknowledged editor',
    () {
      final h = Harness();
      h.today = date('9999-12-31');
      final draft = h.draft(fields(routines: [known(day: '9999-12-31')]));
      final before = h.snapshot;
      expect(() => h.previewDraft(draft), rejected('DATE_OVERFLOW'));
      expect(h.snapshot, same(before));
    },
  );

  test(
    'preview remains valid just before expiry despite a wall-clock jump',
    () {
      final h = Harness();
      final preview = h.previewDraft(h.draft(fields()));
      h.elapsed = const Duration(minutes: 9, seconds: 59, milliseconds: 999);
      h.instant = h.instant.add(const Duration(hours: 6));
      h.confirm(preview);
      expect(h.snapshot.plants.length, 1);
    },
  );

  test(
    'raw draft recovers on coordinator restart without touching collection',
    () {
      final h = Harness();
      final raw = fields(
        name: '',
        notes: 'x' * 2001,
        routines: [known(count: 'not a number', day: 'tomorrow')],
      );
      final draft = h.draft(raw);
      expect(h.snapshot.revision, 1);
      expect(h.snapshot.reminderGeneration, 0);
      h.restart();
      final editor = h.core.getPlantEditor(datasetId: id(1));
      expect(editor.draft, same(draft));
      expect(editor.initialFields.notes, 'x' * 2001);
      expect(editor.initialFields.routines.single.count, 'not a number');
      expect(() => h.previewDraft(draft), rejected('FIELD_INVALID'));
      expect(h.snapshot.drafts[draft.id], same(draft));
    },
  );

  test(
    'known and unknown seeds integrate with collection and exact preview IDs',
    () {
      final h = Harness();
      final draft = h.draft(
        fields(
          routines: [known(), unknown()],
          light: CustomLight.brightIndirect,
          toxicity: CustomToxicity.toxic,
        ),
      );
      final preview = h.previewDraft(draft);
      expect(h.snapshot.plants, isEmpty);
      expect(preview.effects.plants, 1);
      expect(preview.effects.routines, 2);
      expect(preview.effects.events, 1);
      expect(preview.effects.rows.map((r) => r.newNextCheck.toString()), [
        '2026-10-27',
        '2026-11-01',
      ]);
      final result = h.confirm(preview);
      final plant = h.snapshot.plants[result.primaryId]!;
      expect(plant.id, preview.intent.allocatedIds.first);
      expect(plant.name, 'Fern');
      expect(plant.location, 'desk');
      expect(plant.notes, '  personal notes\n');
      expect(plant.light, CustomLight.brightIndirect);
      expect(plant.toxicity, CustomToxicity.toxic);
      expect(h.snapshot.revision, 2);
      expect(h.snapshot.drafts, isEmpty);
      final water = h.snapshot.routines.values.firstWhere(
        (r) => r.careLabel == 'Water',
      );
      final mist = h.snapshot.routines.values.firstWhere(
        (r) => r.careLabel == 'Mist',
      );
      expect(water.events.single.commandId, result.commandId);
      expect(water.events.single.recordedAt, h.instant);
      expect(mist.events, isEmpty);
      expect(mist.latestActualCare, isNull);
      expect(h.snapshot.careKinds[water.id], StandardCareKind.water);
      h.restart();
      expect(
        h.core
            .getPlantEditor(datasetId: id(1), plantId: plant.id)
            .initialFields
            .toxicity,
        CustomToxicity.toxic,
      );
    },
  );

  test(
    'all invalid field paths reported; grapheme bounds and notes preserved',
    () {
      final h = Harness();
      const family = '👩‍👩‍👧‍👦';
      final draft = h.draft(
        fields(
          name: family * 61,
          location: 'é' * 41,
          notes: 'x' * 2001,
          species: ' ',
        ),
      );
      expect(
        () => h.previewDraft(draft),
        throwsA(
          isA<CommandRejected>().having(
            (e) => e.fields.keys.toSet(),
            'fields',
            {'name', 'location', 'notes', 'customSpeciesName'},
          ),
        ),
      );
      final corrected = h.draft(
        fields(name: family * 60, location: 'e\u0301' * 40, notes: 'n' * 2000),
        old: draft,
      );
      final result = h.confirm(h.previewDraft(corrected));
      expect(h.snapshot.plants[result.primaryId]!.name, family * 60);
      expect(h.snapshot.plants[result.primaryId]!.notes.length, 2000);
    },
  );

  test(
    'NUL and unpaired surrogates retained as draft but never final text',
    () {
      final h = Harness();
      final draft = h.draft(fields(name: 'a\u0000', notes: '\ud800'));
      expect(
        () => h.previewDraft(draft),
        throwsA(
          isA<CommandRejected>().having(
            (e) => e.fields.keys.toSet(),
            'fields',
            {'name', 'notes'},
          ),
        ),
      );
      expect(h.snapshot.drafts[draft.id]!.fields.notes.codeUnits, [0xd800]);
    },
  );

  test('oversize write retains previous acknowledged complete draft', () {
    final h = Harness();
    final draft = h.draft(fields());
    expect(
      () => h.draft(fields(notes: '🙂' * 300000), old: draft),
      rejected('FIELD_INVALID'),
    );
    expect(h.snapshot.drafts[draft.id], same(draft));
  });

  test(
    'new duplicate standard kinds and future known seed reject as a whole',
    () {
      final h = Harness();
      final draft = h.draft(
        fields(
          routines: [
            known(),
            known(day: '2026-11-01'),
          ],
        ),
      );
      expect(
        () => h.previewDraft(draft),
        throwsA(
          isA<CommandRejected>().having(
            (e) => e.fields,
            'fields',
            containsPair('routineInputs[1].date', 'FUTURE_CARE_DATE'),
          ),
        ),
      );
      expect(h.snapshot.plants, isEmpty);
      expect(h.snapshot.routines, isEmpty);
      expect(h.snapshot.drafts[draft.id], same(draft));
    },
  );

  test(
    'failed atomic save leaves no plant, event, head, receipt or draft deletion',
    () {
      final h = Harness();
      final draft = h.draft(fields(routines: [known(), unknown()]));
      final preview = h.previewDraft(draft);
      final before = h.snapshot;
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(preview), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      expect(
        h.core
            .getCommandResult(
              datasetId: id(1),
              commandId: preview.intent.commandId,
            )
            .committed,
        false,
      );
      final result = h.confirm(preview);
      expect(result.primaryId, preview.intent.allocatedIds.first);
      expect(h.snapshot.plants.length, 1);
      expect(h.snapshot.routines.length, 2);
      expect(h.snapshot.drafts, isEmpty);
      expect(h.confirm(preview).replayed, true);
      expect(h.snapshot.revision, 2);
    },
  );

  test(
    'lost save reply resolves after coordinator restart and retry returns original result',
    () {
      final h = Harness();
      final preview = h.previewDraft(h.draft(fields(routines: [known()])));
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(preview), throwsA(isA<UnknownCommandOutcome>()));
      h.restart();
      final pending = h.core.listPendingCommands(datasetId: id(1)).single;
      expect(pending.commandId, preview.intent.commandId);
      final result = h.core
          .resolvePendingCommand(datasetId: id(1), commandId: pending.commandId)
          .result!;
      expect(result.primaryId, preview.intent.allocatedIds.first);
      expect(result.replayed, true);
      expect(h.core.listPendingCommands(datasetId: id(1)), isEmpty);
      // Receipt wins even without the expired session's confirmation or draft.
      final replay = h.core.execute(
        datasetId: id(1),
        commandId: pending.commandId,
        command: pending.command,
      );
      expect(replay.collectionRevision, result.collectionRevision);
      expect(h.snapshot.plants.length, 1);
      expect(h.snapshot.routines.values.single.events.length, 1);
      expect(h.snapshot.drafts, isEmpty);
    },
  );

  test(
    'reprepare after uncommitted restart reuses allocated IDs and needs fresh token',
    () {
      final h = Harness();
      final preview = h.previewDraft(h.draft(fields(routines: [known()])));
      h.restart();
      expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
      expect(
        h.core
            .resolvePendingCommand(
              datasetId: id(1),
              commandId: preview.intent.commandId,
            )
            .committed,
        false,
      );
      final again = h.preview(
        preview.intent.command,
        commandId: preview.intent.commandId,
      );
      expect(again.intent.allocatedIds, preview.intent.allocatedIds);
      expect(h.confirm(again).primaryId, preview.intent.allocatedIds.first);
    },
  );

  test('cannot reuse intent with different body before or after commit', () {
    final h = Harness();
    final draft = h.draft(fields());
    final preview = h.previewDraft(draft);
    final changed = SavePlant(
      draftId: draft.id,
      draftRevision: draft.revision + 1,
    );
    expect(
      () => h.preview(changed, commandId: preview.intent.commandId),
      rejected('COMMAND_ID_REUSED'),
    );
    h.confirm(preview);
    expect(
      () => h.core.execute(
        datasetId: id(1),
        commandId: preview.intent.commandId,
        command: changed,
      ),
      rejected('COMMAND_ID_REUSED'),
    );
  });

  test('edited draft invalidates confirmation and preserves latest inputs', () {
    final h = Harness();
    final draft = h.draft(fields());
    final preview = h.previewDraft(draft);
    final latest = h.draft(fields(name: 'Revised'), old: draft);
    expect(() => h.confirm(preview), rejected('STALE_TARGET'));
    expect(h.snapshot.drafts[latest.id]!.fields.name, 'Revised');
    expect(h.snapshot.plants, isEmpty);
  });

  test('preview expires by monotonic time and rejects local day change', () {
    final h = Harness();
    final preview = h.previewDraft(h.draft(fields()));
    h.elapsed = const Duration(minutes: 10);
    h.instant = h.instant.subtract(const Duration(days: 1));
    expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
    final again = h.preview(
      preview.intent.command,
      commandId: preview.intent.commandId,
    );
    h.today = date('2026-10-26');
    expect(() => h.confirm(again), rejected('PREVIEW_STALE'));
    expect(h.snapshot.plants, isEmpty);
  });

  test(
    'token from a different identical intent does not confirm a command',
    () {
      final h = Harness();
      final draft = h.draft(fields());
      final a = h.previewDraft(draft);
      final b = h.previewDraft(draft);
      expect(
        () => h.core.execute(
          datasetId: id(1),
          commandId: a.intent.commandId,
          command: a.intent.command,
          previewToken: b.previewToken,
        ),
        rejected('PREVIEW_STALE'),
      );
      h.confirm(a);
      expect(() => h.confirm(b), rejected('NOT_FOUND'));
      expect(h.snapshot.plants.length, 1);
    },
  );

  test(
    'fifth Free plant allowed, sixth gated; cancel and upgrade retain intent/draft',
    () {
      final h = Harness();
      for (var i = 0; i < 5; i++) {
        h.add();
      }
      final draft = h.draft(fields());
      final preview = h.previewDraft(draft);
      expect(preview.effects.gate, PreviewGate.activeLimit);
      expect(() => h.confirm(preview), rejected('ACTIVE_LIMIT'));
      expect(h.snapshot.drafts[draft.id], same(draft));
      h.store.setProForTest(true);
      expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
      final upgraded = h.preview(
        preview.intent.command,
        commandId: preview.intent.commandId,
      );
      expect(upgraded.intent.allocatedIds, preview.intent.allocatedIds);
      h.confirm(upgraded);
      expect(h.snapshot.plants.length, 6);
      h.store.setProForTest(false);
      expect(h.snapshot.plants.length, 6);
      final plant = h.snapshot.plants.values.first;
      final edit = h.draft(fields(name: 'Renamed above cap'), plant: plant);
      h.confirm(h.previewDraft(edit));
      expect(h.snapshot.plants[plant.id]!.name, 'Renamed above cap');
    },
  );

  test(
    'downgrade after allowed preview requires new review and preserves draft',
    () {
      final h = Harness();
      h.store.setProForTest(true);
      for (var i = 0; i < 5; i++) {
        h.add();
      }
      final draft = h.draft(fields());
      final preview = h.previewDraft(draft);
      h.store.setProForTest(false);
      expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
      final gated = h.preview(
        preview.intent.command,
        commandId: preview.intent.commandId,
      );
      expect(gated.effects.gate, PreviewGate.activeLimit);
      expect(() => h.confirm(gated), rejected('ACTIVE_LIMIT'));
      expect(h.snapshot.drafts[draft.id], same(draft));
    },
  );

  test(
    'metadata edit keeps plant identity, routines, history and custom labels',
    () {
      final h = Harness();
      final plant = h.add(routines: [known(), unknown()]);
      final before = h.snapshot;
      final editor = h.core.getPlantEditor(datasetId: id(1), plantId: plant.id);
      final draft = h.draft(
        fields(
          name: 'New nickname',
          bases: editor.initialFields.baseRoutineRevisions,
        ),
        plant: plant,
      );
      h.confirm(h.previewDraft(draft));
      expect(h.snapshot.plants[plant.id]!.revision, 2);
      expect(h.snapshot.plants[plant.id]!.createdAt, plant.createdAt);
      expect(h.snapshot.plants[plant.id]!.toxicity, CustomToxicity.unknown);
      for (final routine in before.routines.values) {
        expect(h.snapshot.routines[routine.id], same(routine));
      }
    },
  );

  test(
    'custom species change requires every explicit keep choice; never overwrites schedules',
    () {
      final h = Harness();
      final plant = h.add(routines: [known(), unknown()]);
      final before = h.snapshot.routines;
      final bases = h.core
          .getPlantEditor(datasetId: id(1), plantId: plant.id)
          .initialFields
          .baseRoutineRevisions;
      final draft = h.draft(
        fields(species: 'Another custom plant', bases: bases),
        plant: plant,
      );
      expect(() => h.previewDraft(draft), rejected('FIELD_INVALID'));
      final revised = h.draft(
        fields(
          species: 'Another custom plant',
          bases: bases,
          keep: bases.keys,
          light: CustomLight.low,
          toxicity: CustomToxicity.nonToxic,
        ),
        plant: plant,
        old: draft,
      );
      h.confirm(h.previewDraft(revised));
      expect(h.snapshot.plants[plant.id]!.speciesName, 'Another custom plant');
      expect(h.snapshot.routines, before);
    },
  );

  test(
    'care while editing makes base stale and cannot be overwritten by draft save',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      final editor = h.core.getPlantEditor(datasetId: id(1), plantId: plant.id);
      final draft = h.draft(
        fields(
          name: 'Keep my text',
          bases: editor.initialFields.baseRoutineRevisions,
        ),
        plant: plant,
      );
      final save = h.previewDraft(draft);
      h.confirm(
        h.preview(
          AddPastCare(h.target(), date('2026-10-10'), CareOutcome.actualCare),
        ),
      );
      expect(() => h.confirm(save), rejected('DRAFT_CONFLICT'));
      expect(h.snapshot.routines.values.single.events.length, 2);
      expect(h.snapshot.plants[plant.id]!.name, 'Fern');
      expect(h.snapshot.drafts[draft.id]!.fields.name, 'Keep my text');
      final reopened = h.core.getPlantEditor(
        datasetId: id(1),
        plantId: plant.id,
      );
      expect(
        reopened.initialFields.baseRoutineRevisions,
        editor.initialFields.baseRoutineRevisions,
      );
      // Explicitly acknowledge current bases only after reviewing the conflict.
      final currentRoutine = h.snapshot.routines.values.single;
      final reviewed = h.draft(
        fields(
          name: 'Keep my text',
          bases: {currentRoutine.id: currentRoutine.revision},
        ),
        old: draft,
        plant: plant,
      );
      h.confirm(h.previewDraft(reviewed));
      expect(h.snapshot.plants[plant.id]!.name, 'Keep my text');
      expect(h.snapshot.routines[currentRoutine.id], same(currentRoutine));
      expect(h.snapshot.drafts, isEmpty);
    },
  );

  test(
    'one draft per editor; stale writes and silent mode/plant changes reject',
    () {
      final h = Harness();
      final draft = h.draft(fields());
      expect(() => h.draft(fields(name: 'Second')), rejected('DRAFT_CONFLICT'));
      final newer = h.draft(fields(name: 'Newer'), old: draft);
      expect(
        () => h.draft(fields(name: 'Stale'), old: draft),
        rejected('STALE_TARGET'),
      );
      expect(h.snapshot.drafts.values.single, same(newer));
      expect(
        () => h.submit(
          SaveDraft(
            draftId: draft.id,
            expectedRevision: newer.revision,
            mode: DraftMode.edit,
            plantId: id(999),
            basePlantRevision: 1,
            fields: fields(),
          ),
        ),
        rejected('DRAFT_CONFLICT'),
      );
    },
  );

  test('draft writes recover lost replies before stale revision guards', () {
    final h = Harness();
    final command = SaveDraft(
      draftId: id(9999),
      expectedRevision: null,
      mode: DraftMode.add,
      fields: fields(),
    );
    final frozen = h.core.freeze(datasetId: id(1), command: command);
    h.store.nextFault = SimulatedFault.afterCommitReplyLost;
    expect(
      () => h.core.execute(
        datasetId: id(1),
        commandId: frozen.commandId,
        command: command,
      ),
      throwsA(isA<UnknownCommandOutcome>()),
    );
    h.restart();
    final replay = h.core.execute(
      datasetId: id(1),
      commandId: frozen.commandId,
      command: command,
    );
    expect(replay.replayed, true);
    expect(h.snapshot.drafts.values.single.revision, 1);
    expect(h.snapshot.revision, 1);
  });

  test(
    'cancel resolves receipt first and keeps draft; discard is separately confirmed',
    () {
      final h = Harness();
      final draft = h.draft(fields());
      final preview = h.previewDraft(draft);
      h.store.nextFault = SimulatedFault.receiptRead;
      expect(
        () => h.core.abandonPendingCommand(
          datasetId: id(1),
          commandId: preview.intent.commandId,
        ),
        throwsA(isA<RecoveryUnavailable>()),
      );
      expect(h.core.listPendingCommands(datasetId: id(1)), hasLength(1));
      final resolved = h.core.abandonPendingCommand(
        datasetId: id(1),
        commandId: preview.intent.commandId,
      );
      expect(resolved.committed, false);
      expect(h.snapshot.drafts[draft.id], same(draft));
      expect(() => h.confirm(preview), rejected('NOT_FOUND'));
      expect(
        () => h.submit(
          DiscardDraft(
            draftId: draft.id,
            draftRevision: draft.revision,
            confirmed: false,
          ),
        ),
        rejected('NOT_ELIGIBLE'),
      );
      h.submit(
        DiscardDraft(
          draftId: draft.id,
          draftRevision: draft.revision,
          confirmed: true,
        ),
      );
      expect(h.snapshot.drafts, isEmpty);
      expect(h.snapshot.revision, 1);
      expect(
        () => h.submit(
          SaveDraft(
            draftId: draft.id,
            expectedRevision: null,
            mode: DraftMode.add,
            fields: fields(),
          ),
        ),
        rejected('NOT_ELIGIBLE'),
      );
    },
  );

  test(
    'cancelling after lost committed response resolves saved plant, never undoes it',
    () {
      final h = Harness();
      final preview = h.previewDraft(h.draft(fields()));
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(preview), throwsA(isA<UnknownCommandOutcome>()));
      final result = h.core.abandonPendingCommand(
        datasetId: id(1),
        commandId: preview.intent.commandId,
      );
      expect(result.committed, true);
      expect(h.snapshot.plants.containsKey(result.result!.primaryId), true);
    },
  );

  test(
    'care commit and retry preserve a single head/event and original result revisions',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      final originalHead = h.target().headId;
      final preview = h.preview(
        CompleteCurrent(h.target(), date('2026-10-25')),
      );
      expect(preview.effects.rows.single.newNextCheck, date('2026-11-01'));
      final before = h.snapshot;
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(preview), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(preview), throwsA(isA<UnknownCommandOutcome>()));
      final committed = h.core
          .getCommandResult(
            datasetId: id(1),
            commandId: preview.intent.commandId,
          )
          .result!;
      h.confirm(h.preview(Snooze(h.target(), date('2026-11-03'))));
      final replay = h.confirm(preview);
      expect(replay.collectionRevision, committed.collectionRevision);
      expect(replay.newRevisions, committed.newRevisions);
      expect(h.snapshot.routines.values.single.events.length, 2);
      expect(h.snapshot.routines.values.single.headId, originalHead);
      expect(h.snapshot.routines.values.single.nextCheck, date('2026-11-03'));
    },
  );

  test(
    'required October history path and correction audit preserve schedule across retries',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      expect(
        () => h.preview(CompleteCurrent(h.target(), date('2026-10-10'))),
        rejected('CARE_PRECEDES_LATEST'),
      );
      final preview = h.preview(
        AddPastCare(h.target(), date('2026-10-10'), CareOutcome.actualCare),
      );
      expect(preview.effects.historyOnly, true);
      expect(preview.effects.rows.single.newNextCheck, date('2026-10-27'));
      final saved = h.confirm(preview);
      expect(saved.notices, ['HISTORY_CHANGED_CHECK_UNCHANGED']);
      var routine = h.snapshot.routines.values.single;
      expect(routine.latestActualCare, date('2026-10-20'));
      final event = routine.events.last;
      final correction = h.preview(
        CorrectEvent(
          h.target(),
          eventId: event.id,
          eventRevision: event.revision,
          careDate: date('2026-10-24'),
          outcome: CareOutcome.actualCare,
        ),
      );
      h.confirm(correction);
      h.confirm(correction);
      routine = h.snapshot.routines.values.single;
      expect(routine.latestActualCare, date('2026-10-24'));
      expect(routine.events.last.id, event.id);
      expect(routine.events.last.corrections.length, 1);
      expect(routine.events.last.recordedAt, event.recordedAt);
      expect(routine.nextCheck, date('2026-10-27'));
      expect(h.snapshot.reminderGeneration, 1);
      h.confirm(
        h.preview(VoidEvent(h.target(), eventId: event.id, eventRevision: 2)),
      );
      expect(
        h.snapshot.routines.values.single.latestActualCare,
        date('2026-10-20'),
      );
      h.confirm(
        h.preview(
          CorrectEvent(
            h.target(),
            eventId: event.id,
            eventRevision: 3,
            careDate: date('2026-10-24'),
            outcome: CareOutcome.actualCare,
            restore: true,
          ),
        ),
      );
      expect(h.snapshot.routines.values.single.nextCheck, date('2026-10-27'));
      expect(
        h.snapshot.routines.values.single.events.last.corrections.length,
        3,
      );
    },
  );

  test('check, snooze, skip integrate without inventing actual care', () {
    final h = Harness();
    h.add(routines: [unknown(kind: StandardCareKind.water)]);
    h.confirm(
      h.preview(CheckNotNeeded(h.target(), h.today, date('2026-10-24'))),
    );
    expect(h.snapshot.routines.values.single.nextCheck, date('2026-10-24'));
    h.confirm(h.preview(Snooze(h.target(), date('2026-11-08'))));
    h.confirm(h.preview(Skip(h.target())));
    final routine = h.snapshot.routines.values.single;
    expect(routine.actualCareCount, 0);
    expect(routine.nextCheck, date('2026-11-01'));
    expect(routine.overrideDate, isNull);
    expect(routine.events.map((e) => e.effective.outcome), [
      CareOutcome.checkedNotNeeded,
      CareOutcome.skipped,
    ]);
  });

  test(
    'intervening command rejects stale target; ownership cannot be forged',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      final target = h.target();
      final earlier = h.preview(CompleteCurrent(target, h.today));
      h.confirm(h.preview(Snooze(target, date('2026-11-09'))));
      expect(() => h.confirm(earlier), rejected('STALE_TARGET'));
      final other = h.add();
      final current = h.target();
      final wrong = CareTarget(
        plantId: other.id,
        plantRevision: other.revision,
        routineId: current.routineId,
        routineRevision: current.routineRevision,
        headId: current.headId,
        headRevision: current.headRevision,
      );
      expect(
        () => h.preview(CompleteCurrent(wrong, h.today)),
        rejected('FIELD_INVALID'),
      );
      expect(h.snapshot.routines.values.single.events.length, 1);
    },
  );

  test(
    'generation mismatch rejects old previews, receipts and pending bodies',
    () {
      final h = Harness();
      final preview = h.previewDraft(h.draft(fields()));
      h.confirm(preview);
      h.store.replaceWithEmptyDatasetForTest(id(2));
      expect(() => h.confirm(preview), rejected('DATASET_CHANGED'));
      expect(
        () => h.core.getCommandResult(
          datasetId: id(1),
          commandId: preview.intent.commandId,
        ),
        rejected('DATASET_CHANGED'),
      );
      expect(
        () => h.core.execute(
          datasetId: id(2),
          commandId: preview.intent.commandId,
          command: preview.intent.command,
          previewToken: preview.previewToken,
        ),
        rejected('DATASET_CHANGED'),
      );
      expect(h.core.listPendingCommands(datasetId: id(2)), isEmpty);
      expect(h.core.readCollection(datasetId: id(2)).plants, isEmpty);
    },
  );

  test(
    'snapshot, draft collections and receipt lists cannot be mutated by callers',
    () {
      final h = Harness();
      final inputs = [known()];
      final raw = fields(routines: inputs);
      final draft = h.draft(raw);
      inputs.clear();
      expect(draft.fields.routines.length, 1);
      expect(() => h.snapshot.drafts.clear(), throwsUnsupportedError);
      expect(() => draft.fields.routines.clear(), throwsUnsupportedError);
      final preview = h.previewDraft(draft);
      expect(() => preview.intent.allocatedIds.clear(), throwsUnsupportedError);
      final result = h.confirm(preview);
      expect(() => result.newRevisions.clear(), throwsUnsupportedError);
      expect(() => result.resourceIds.clear(), throwsUnsupportedError);
    },
  );
}
