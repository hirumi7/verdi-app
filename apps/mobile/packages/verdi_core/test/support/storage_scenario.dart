import 'package:verdi_core/verdi_core.dart';

String fixtureId(int n) =>
    '00000000-0000-4000-8000-${n.toRadixString(16).padLeft(12, '0')}';
Map<String, Object?> asMap(Object? value) =>
    (value as Map).cast<String, Object?>();

final class StorageScenario {
  int sequence = 10;
  final rows = {
    for (final t in CoreStorageProjection.tables) t: <List<Object?>>[],
  };
  late final CoreStorageProjection projection = CoreStorageProjection(
    datasetId: fixtureId(1),
    nextId: () => fixtureId(sequence++),
    clock: CareClock(
      LocalDate(2026, 10, 31),
      DateTime.utc(2026, 10, 31, 12),
      'Etc/UTC',
    ),
  );
  final steps = <Map<String, Object?>>[];
  CoreStoragePlan run(CoreCommand command) {
    projection.clock = CareClock(
      LocalDate(2026, 10, 31),
      DateTime.utc(2026, 10, 31, 12).add(Duration(seconds: steps.length)),
      'Etc/UTC',
    );
    final intent = projection.freeze(command),
        plan = projection.plan(intent, fixtureId(2));
    apply(plan);
    for (final table in rows.values) {
      table.sort((a, b) => (a[0] as String).compareTo(b[0] as String));
    }
    steps.add({
      'intent': projection.frozenJson(intent),
      'plan': plan.body(),
      'instant': projection.clock.instant.toIso8601String(),
      'tableHashes': {
        for (final t in CoreStorageProjection.tables)
          t: canonicalValueHash(sorted(t)),
      },
    });
    projection.hydrate(rows, plan.candidate.revision, steps.length + 1);
    projection.acknowledge(plan, 8000);
    return plan;
  }

  List<List<Object?>> sorted(String table) =>
      [...rows[table]!]
        ..sort((a, b) => (a[0] as String).compareTo(b[0] as String));
  void apply(CoreStoragePlan plan) {
    for (final raw in plan.body()['statements'] as List) {
      final statement = asMap(raw),
          key = (statement['key'] as String).split('.');
      final values = (statement['values'] as List).map((v) {
        if (v is! Map) return v;
        return switch (v['native']) {
          'transaction_instant' => projection.clock.instant.toIso8601String(),
          'transaction_zone' => projection.clock.zone,
          'transaction_local_date' => projection.clock.today.toString(),
          _ => v,
        };
      }).toList();
      final table = rows[key[0]]!;
      if (key[1] == 'deleteTree') {
        final plant = values[0],
            routines = rows['routines']!
                .where((r) => r[1] == plant)
                .map((r) => r[0])
                .toSet(),
            events = rows['care_events']!
                .where((r) => r[1] == plant)
                .map((r) => r[0])
                .toSet();
        rows['plant_catalog']!.removeWhere((r) => r[0] == plant);
        rows['routine_custom_types']!.removeWhere(
          (r) => routines.contains(r[0]),
        );
        rows['routine_suggestions']!.removeWhere(
          (r) => routines.contains(r[0]),
        );
        rows['suggestion_snapshots']!.removeWhere((r) => r[2] == plant);
        rows['plants']!.removeWhere((r) => r[0] == plant);
        rows['routines']!.removeWhere((r) => r[1] == plant);
        rows['heads']!.removeWhere((r) => routines.contains(r[1]));
        rows['care_events']!.removeWhere((r) => r[1] == plant);
        rows['event_corrections']!.removeWhere((r) => events.contains(r[1]));
        rows['routine_changes']!.removeWhere((r) => r[1] == plant);
        rows['plant_drafts']!.removeWhere((r) => r[3] == plant);
        continue;
      }
      table.removeWhere((r) => r[0] == values[0]);
      if (key[1] != 'delete') table.add(values);
    }
  }

  String get plant => projection.snapshot.plants.keys.first;
  String routine(StandardCareKind kind) => projection.snapshot.careKinds.entries
      .firstWhere((e) => e.value == kind)
      .key;
  CareTarget target([StandardCareKind kind = StandardCareKind.water]) {
    final r = projection.snapshot.routines[routine(kind)]!,
        p = projection.snapshot.plants[r.plantId]!;
    return CareTarget(
      plantId: p.id,
      plantRevision: p.revision,
      routineId: r.id,
      routineRevision: r.revision,
      headId: r.headId,
      headRevision: r.headRevision,
    );
  }

  void allCommands() {
    final add = fixtureId(sequence++);
    run(
      SaveDraft(
        draftId: add,
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: 'Fern 🌿',
          speciesName: 'Synthetic fern',
          routines: [
            const RoutineInput(
              kind: StandardCareKind.water,
              count: '1',
              unit: IntervalUnit.week,
              seedKind: SeedKind.known,
              date: '2026-10-20',
            ),
            const RoutineInput(
              kind: StandardCareKind.rotate,
              count: '1',
              unit: IntervalUnit.month,
              seedKind: SeedKind.unknown,
              date: '2026-11-02',
            ),
          ],
        ),
      ),
    );
    run(SavePlant(draftId: add, draftRevision: 1));
    final edit = fixtureId(sequence++),
        bases = {
          for (final r in projection.snapshot.routines.values) r.id: r.revision,
        };
    run(
      SaveDraft(
        draftId: edit,
        expectedRevision: null,
        mode: DraftMode.edit,
        plantId: plant,
        basePlantRevision: projection.snapshot.plants[plant]!.revision,
        fields: CustomPlantFields(
          name: 'Fern edited',
          speciesName: 'Fern revised',
          light: CustomLight.brightIndirect,
          toxicity: CustomToxicity.unknown,
          notes: 'Preserve\nnotes',
          baseRoutineRevisions: bases,
          keepRoutineIds: bases.keys,
        ),
      ),
    );
    run(SavePlant(draftId: edit, draftRevision: 1));
    final complete = run(CompleteCurrent(target(), LocalDate(2026, 10, 31)));
    run(Undo(complete.intent.commandId));
    run(CompleteCurrent(target(), LocalDate(2026, 10, 31)));
    run(AddPastCare(target(), LocalDate(2026, 10, 10), CareOutcome.actualCare));
    var event = projection
        .snapshot
        .routines[routine(StandardCareKind.water)]!
        .events
        .first;
    run(
      CorrectEvent(
        target(),
        eventId: event.id,
        eventRevision: event.revision,
        careDate: LocalDate(2026, 10, 19),
        outcome: CareOutcome.actualCare,
      ),
    );
    event = projection
        .snapshot
        .routines[routine(StandardCareKind.water)]!
        .events
        .first;
    run(VoidEvent(target(), eventId: event.id, eventRevision: event.revision));
    event = projection
        .snapshot
        .routines[routine(StandardCareKind.water)]!
        .events
        .first;
    run(
      CorrectEvent(
        target(),
        eventId: event.id,
        eventRevision: event.revision,
        careDate: LocalDate(2026, 10, 18),
        outcome: CareOutcome.actualCare,
        restore: true,
      ),
    );
    run(
      CheckNotNeeded(target(), LocalDate(2026, 10, 31), LocalDate(2026, 11, 2)),
    );
    run(Snooze(target(), LocalDate(2026, 11, 3)));
    run(SetInterval(target(), CareInterval(1, IntervalUnit.month)));
    run(ClearOverride(target()));
    run(PauseRoutine(target()));
    run(ResumeRoutine(target()));
    run(Skip(target()));
    run(RetireRoutine(target(StandardCareKind.rotate)));
    run(
      ArchivePlant(
        plantId: plant,
        plantRevision: projection.snapshot.plants[plant]!.revision,
      ),
    );
    run(
      RestorePlant(
        plantId: plant,
        plantRevision: projection.snapshot.plants[plant]!.revision,
      ),
    );
    run(
      BulkComplete(
        careKind: StandardCareKind.water,
        careDate: LocalDate(2026, 10, 31),
        targets: [target()],
      ),
    );
    final draft = fixtureId(sequence++);
    run(
      SaveDraft(
        draftId: draft,
        expectedRevision: null,
        mode: DraftMode.edit,
        plantId: plant,
        basePlantRevision: projection.snapshot.plants[plant]!.revision,
        fields: CustomPlantFields(
          name: 'raw draft',
          baseRoutineRevisions: {
            routine(StandardCareKind.water): target().routineRevision,
          },
        ),
      ),
    );
    run(DiscardDraft(draftId: draft, draftRevision: 1, confirmed: true));
    run(
      ArchivePlant(
        plantId: plant,
        plantRevision: projection.snapshot.plants[plant]!.revision,
      ),
    );
    run(
      DeletePlant(
        plantId: plant,
        plantRevision: projection.snapshot.plants[plant]!.revision,
      ),
    );
    final raw = fixtureId(sequence++);
    run(
      SaveDraft(
        draftId: raw,
        expectedRevision: null,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: String.fromCharCodes([0xd800]),
          notes: 'a\u0000b',
        ),
      ),
    );
    run(
      SaveDraft(
        draftId: raw,
        expectedRevision: 1,
        mode: DraftMode.add,
        fields: CustomPlantFields(
          name: 'Recovered draft',
          routines: [
            const RoutineInput(
              kind: StandardCareKind.water,
              count: 'not a number',
              unit: IntervalUnit.day,
              seedKind: null,
              date: '',
            ),
          ],
        ),
      ),
    );
  }

  String json() => canonicalCommandJson({'version': 1, 'steps': steps});
}
