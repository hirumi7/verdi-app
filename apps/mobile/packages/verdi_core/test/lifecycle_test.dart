import 'package:test/test.dart' hide Skip;
import 'package:verdi_core/verdi_core.dart';

// Reuse the existing synthetic fixture; importing it does not invoke its main.
import 'collection_test.dart'
    show Harness, id, date, fields, known, unknown, rejected;

void main() {
  test(
    'explicit interval edit uses effective latest care after history-only addition',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      h.confirm(
        h.preview(
          AddPastCare(h.target(), date('2026-10-24'), CareOutcome.actualCare),
        ),
      );
      final before = h.snapshot.routines.values.single;
      final preview = h.preview(
        SetInterval(h.target(), CareInterval(2, IntervalUnit.week)),
      );
      expect(preview.effects.rows.single.oldNextCheck, date('2026-10-27'));
      expect(preview.effects.rows.single.newNextCheck, date('2026-11-07'));
      h.confirm(preview);
      final after = h.snapshot.routines[before.id]!;
      expect(after.anchor, date('2026-10-24'));
      expect(after.events, before.events);
      expect(after.headId, before.headId);
      expect(after.headRevision, before.headRevision + 1);
      final change = h.snapshot.scheduleChanges.values.single;
      expect(change.kind, ScheduleChangeKind.interval);
      expect(change.before.interval, CareInterval(1, IntervalUnit.week));
      expect(change.after.interval, CareInterval(2, IntervalUnit.week));
      expect(change.before.headId, before.headId);
      expect(change.after.headId, before.headId);
      expect(change.before.originalSuggestionId, isNull);
      expect(change.after.appliedSuggestionId, isNull);
      expect(change.before.nextCheck, date('2026-10-27'));
      expect(change.after.nextCheck, date('2026-11-07'));
      expect(change.changeDate, h.today);
      expect(change.changedAt, h.instant);
      expect(change.recordedZone, 'Etc/UTC');
      expect(
        h.core.getScheduleChange(datasetId: id(1), changeId: change.id),
        same(change),
      );
    },
  );

  test(
    'interval preserves override; clearing explicitly recalculates from care and clamps today',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      h.confirm(h.preview(Snooze(h.target(), date('2026-11-20'))));
      final before = h.snapshot.routines.values.single;
      h.confirm(
        h.preview(SetInterval(h.target(), CareInterval(1, IntervalUnit.day))),
      );
      var after = h.snapshot.routines.values.single;
      expect(after.nextCheck, before.nextCheck);
      expect(after.overrideDate, before.overrideDate);
      expect(after.anchor, before.anchor);
      expect(after.headRevision, before.headRevision);
      h.confirm(h.preview(ClearOverride(h.target())));
      after = h.snapshot.routines.values.single;
      expect(after.nextCheck, h.today);
      expect(after.overrideDate, isNull);
      expect(after.actualCareCount, 1);
      expect(h.snapshot.scheduleChanges.values.map((c) => c.kind), [
        ScheduleChangeKind.override,
        ScheduleChangeKind.interval,
        ScheduleChangeKind.override,
      ]);
    },
  );

  test(
    'unknown interval retains first date; clearing requires an explicit new choice',
    () {
      final h = Harness();
      h.add(routines: [unknown()]);
      h.confirm(
        h.preview(
          SetInterval(
            h.target(),
            CareInterval(1, IntervalUnit.month),
            firstCheckDate: date('2026-12-12'),
          ),
        ),
      );
      expect(h.snapshot.routines.values.single.nextCheck, date('2026-11-01'));
      h.confirm(h.preview(Snooze(h.target(), date('2026-11-12'))));
      expect(
        () => h.preview(ClearOverride(h.target())),
        rejected('FIRST_CHECK_REQUIRED'),
      );
      h.confirm(
        h.preview(
          ClearOverride(h.target(), firstCheckDate: date('2026-10-22')),
        ),
      );
      final r = h.snapshot.routines.values.single;
      expect(r.firstCheckDate, date('2026-10-22'));
      expect(r.nextCheck, date('2026-10-22'));
      expect(r.anchor, date('2026-10-22'));
      expect(r.firstCheckAnchor, true);
      expect(r.events, isEmpty);
    },
  );

  test(
    'voiding all known care requires chosen first check instead of invented history',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      final event = h.snapshot.routines.values.single.events.single;
      h.confirm(
        h.preview(
          VoidEvent(
            h.target(),
            eventId: event.id,
            eventRevision: event.revision,
          ),
        ),
      );
      final before = h.snapshot;
      expect(
        () => h.preview(
          SetInterval(h.target(), CareInterval(2, IntervalUnit.day)),
        ),
        rejected('FIRST_CHECK_REQUIRED'),
      );
      expect(h.snapshot, same(before));
      h.confirm(
        h.preview(
          SetInterval(
            h.target(),
            CareInterval(2, IntervalUnit.day),
            firstCheckDate: date('2026-11-04'),
          ),
        ),
      );
      final r = h.snapshot.routines.values.single;
      expect(r.events.single.effective.voided, true);
      expect(r.actualCareCount, 0);
      expect(r.nextCheck, date('2026-11-04'));
      expect(r.firstCheckAnchor, true);
    },
  );

  test(
    'interval overflow rolls back; override precedence avoids unused date overflow',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      final before = h.snapshot;
      expect(
        () => h.preview(
          SetInterval(h.target(), CareInterval(9999, IntervalUnit.year)),
        ),
        rejected('DATE_OVERFLOW'),
      );
      expect(h.snapshot, same(before));
      h.confirm(h.preview(Snooze(h.target(), date('2026-12-01'))));
      h.confirm(
        h.preview(
          SetInterval(h.target(), CareInterval(9999, IntervalUnit.year)),
        ),
      );
      final overridden = h.snapshot;
      expect(
        () => h.preview(ClearOverride(h.target())),
        rejected('DATE_OVERFLOW'),
      );
      expect(h.snapshot, same(overridden));
    },
  );

  test(
    'pause and resume preserve history and clamp head plus override with audit',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      h.confirm(h.preview(Snooze(h.target(), date('2026-10-28'))));
      final before = h.snapshot.routines.values.single;
      h.confirm(h.preview(PauseRoutine(h.target())));
      var r = h.snapshot.routines.values.single;
      expect(r.status, RoutineStatus.paused);
      expect(r.nextCheck, before.nextCheck);
      expect(r.headRevision, before.headRevision + 1);
      expect(h.snapshot.eligibleRoutines, isEmpty);
      expect(
        () => h.preview(CompleteCurrent(h.target(), h.today)),
        rejected('NOT_ELIGIBLE'),
      );
      expect(
        () => h.preview(PauseRoutine(h.target())),
        rejected('NOT_ELIGIBLE'),
      );
      h.today = date('2026-11-02');
      final preview = h.preview(ResumeRoutine(h.target()));
      expect(preview.effects.rows.single.newNextCheck, h.today);
      h.confirm(preview);
      r = h.snapshot.routines.values.single;
      expect(r.status, RoutineStatus.active);
      expect(r.nextCheck, h.today);
      expect(r.overrideDate, h.today);
      expect(r.anchor, before.anchor);
      expect(r.events, before.events);
      expect(h.snapshot.eligibleRoutines.single.id, r.id);
      final audit = h.snapshot.scheduleChanges.values.last;
      expect(audit.before.status, RoutineStatus.paused);
      expect(audit.before.overrideDate, date('2026-10-28'));
      expect(audit.after.overrideDate, h.today);
    },
  );

  test(
    'paused and archived interval edits stay ineligible; retired is history-only',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      h.confirm(h.preview(PauseRoutine(h.target())));
      h.confirm(
        h.preview(SetInterval(h.target(), CareInterval(2, IntervalUnit.week))),
      );
      expect(h.snapshot.eligibleRoutines, isEmpty);
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      h.confirm(
        h.preview(SetInterval(h.target(), CareInterval(3, IntervalUnit.week))),
      );
      expect(h.snapshot.eligibleRoutines, isEmpty);
      expect(
        () => h.preview(ResumeRoutine(h.target())),
        rejected('NOT_ELIGIBLE'),
      );
      h.confirm(h.preview(RetireRoutine(h.target())));
      expect(
        () => h.preview(
          SetInterval(h.target(), CareInterval(1, IntervalUnit.week)),
        ),
        rejected('NOT_ELIGIBLE'),
      );
      expect(
        () => h.preview(ClearOverride(h.target())),
        rejected('NOT_ELIGIBLE'),
      );
      expect(
        () => h.preview(ResumeRoutine(h.target())),
        rejected('NOT_ELIGIBLE'),
      );
      final r = h.snapshot.routines.values.single;
      h.confirm(
        h.preview(
          CorrectEvent(
            h.target(),
            eventId: r.events.single.id,
            eventRevision: 1,
            careDate: date('2026-10-19'),
            outcome: CareOutcome.actualCare,
          ),
        ),
      );
      expect(h.snapshot.routines[r.id]!.careLabel, 'Water');
      expect(h.snapshot.routines[r.id]!.events.single.id, r.events.single.id);
      expect(h.snapshot.routines[r.id]!.nextCheck, r.nextCheck);
    },
  );

  test(
    'schedule fault and lost reply cannot duplicate audit or change history',
    () {
      final h = Harness();
      h.add(routines: [known()]);
      final preview = h.preview(
        SetInterval(h.target(), CareInterval(2, IntervalUnit.week)),
      );
      final before = h.snapshot;
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(preview), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(preview), throwsA(isA<UnknownCommandOutcome>()));
      h.restart();
      expect(
        h.core
            .resolvePendingCommand(
              datasetId: id(1),
              commandId: preview.intent.commandId,
            )
            .committed,
        true,
      );
      expect(h.confirm(preview).replayed, true);
      expect(h.snapshot.scheduleChanges.length, 1);
      expect(h.snapshot.routines.values.single.events.length, 1);
    },
  );

  test(
    'archive is atomic for all routines and preserves paused state and records',
    () {
      final h = Harness();
      final plant = h.add(routines: [known(), unknown()]);
      final paused = h.snapshot.routines.values.last;
      h.confirm(h.preview(PauseRoutine(h.target(paused))));
      final before = h.snapshot;
      final preview = h.preview(
        ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
      );
      expect(preview.effects.events, 1);
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(preview), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      h.confirm(preview);
      expect(h.snapshot.activePlants, isEmpty);
      expect(h.snapshot.archivedPlants.single.id, plant.id);
      expect(h.snapshot.eligibleRoutines, isEmpty);
      for (final r in before.routines.values) {
        final after = h.snapshot.routines[r.id]!;
        expect(after.archived, true);
        expect(after.events, r.events);
        expect(after.nextCheck, r.nextCheck);
        expect(after.status, r.status);
        expect(after.headRevision, r.headRevision + 1);
      }
      expect(
        h.snapshot.scheduleChanges.length,
        before.scheduleChanges.length + 2,
      );
      expect(h.confirm(preview).replayed, true);
      final archived = h.snapshot.plants[plant.id]!;
      expect(
        () => h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: archived.revision),
        ),
        rejected('NOT_ELIGIBLE'),
      );
    },
  );

  test(
    'restore clamps active and paused overrides but never revives retired routines',
    () {
      final h = Harness();
      final plant = h.add(
        routines: [
          known(),
          unknown(),
          unknown(kind: StandardCareKind.rotate),
        ],
      );
      final originals = h.snapshot.routines.values.toList();
      for (final original in originals) {
        h.confirm(
          h.preview(
            Snooze(
              h.target(h.snapshot.routines[original.id]),
              date('2026-10-26'),
            ),
          ),
        );
      }
      h.confirm(
        h.preview(PauseRoutine(h.target(h.snapshot.routines[originals[1].id]))),
      );
      h.confirm(
        h.preview(
          RetireRoutine(h.target(h.snapshot.routines[originals[2].id])),
        ),
      );
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      final before = h.snapshot;
      h.today = date('2026-11-10');
      final archived = h.snapshot.plants[plant.id]!;
      final preview = h.preview(
        RestorePlant(plantId: plant.id, plantRevision: archived.revision),
      );
      h.confirm(preview);
      for (var i = 0; i < originals.length; i++) {
        final r = h.snapshot.routines[originals[i].id]!;
        expect(r.nextCheck, i == 2 ? date('2026-10-26') : h.today);
        expect(r.overrideDate, i == 2 ? date('2026-10-26') : h.today);
        expect(r.events, before.routines[r.id]!.events);
        expect(r.anchor, before.routines[r.id]!.anchor);
      }
      expect(
        h.snapshot.routines[originals[1].id]!.status,
        RoutineStatus.paused,
      );
      expect(
        h.snapshot.routines[originals[2].id]!.status,
        RoutineStatus.retired,
      );
      expect(h.snapshot.eligibleRoutines.single.id, originals[0].id);
      expect(h.snapshot.plants[plant.id]!.createdAt, plant.createdAt);
    },
  );

  test(
    'archived metadata edits retain archive; editor excludes retired routine choices',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      h.confirm(h.preview(RetireRoutine(h.target())));
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      final archived = h.snapshot.plants[plant.id]!;
      final editor = h.core.getPlantEditor(datasetId: id(1), plantId: plant.id);
      expect(editor.initialFields.baseRoutineRevisions, isEmpty);
      final draft = h.draft(
        fields(name: 'Archived nickname', species: 'Another custom species'),
        plant: archived,
      );
      h.confirm(h.previewDraft(draft));
      expect(h.snapshot.plants[plant.id]!.archived, true);
      expect(h.snapshot.plants[plant.id]!.name, 'Archived nickname');
      expect(h.snapshot.routines.values.single.careLabel, 'Water');
      expect(h.snapshot.routines.values.single.events.length, 1);
    },
  );

  test(
    'archive frees a slot; restore gates against active count and reuses IDs after upgrade',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      for (var i = 0; i < 4; i++) {
        h.add();
      }
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      expect(h.core.getPlantEditor(datasetId: id(1)).activeCount, 4);
      h.add();
      expect(h.snapshot.plants.length, 6);
      final archived = h.snapshot.plants[plant.id]!;
      final preview = h.preview(
        RestorePlant(plantId: plant.id, plantRevision: archived.revision),
      );
      expect(preview.effects.gate, PreviewGate.activeLimit);
      expect(() => h.confirm(preview), rejected('ACTIVE_LIMIT'));
      expect(h.snapshot.plants[plant.id]!.archived, true);
      h.store.setProForTest(true);
      expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
      final again = h.preview(
        preview.intent.command,
        commandId: preview.intent.commandId,
      );
      expect(again.intent.allocatedIds, preview.intent.allocatedIds);
      h.confirm(again);
      h.store.setProForTest(false);
      expect(h.confirm(again).replayed, true);
      expect(h.snapshot.activePlants.length, 6);
      expect(h.snapshot.routines.values.single.events.length, 1);
    },
  );

  test(
    'archive confirmation rejects care changes and keeps an existing draft',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      final bases = h.core
          .getPlantEditor(datasetId: id(1), plantId: plant.id)
          .initialFields
          .baseRoutineRevisions;
      final draft = h.draft(
        fields(name: 'Unsaved nickname', bases: bases),
        plant: plant,
      );
      final preview = h.preview(
        ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
      );
      h.confirm(
        h.preview(
          AddPastCare(h.target(), date('2026-10-19'), CareOutcome.actualCare),
        ),
      );
      expect(() => h.confirm(preview), rejected('PREVIEW_STALE'));
      expect(h.snapshot.plants[plant.id]!.archived, false);
      final fresh = h.preview(
        preview.intent.command,
        commandId: preview.intent.commandId,
      );
      h.confirm(fresh);
      expect(h.snapshot.drafts[draft.id], same(draft));
      expect(() => h.previewDraft(draft), rejected('STALE_TARGET'));
      expect(h.snapshot.routines.values.single.events.length, 2);
    },
  );

  test(
    'deletion requires archived state and its own distinct confirmation',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      expect(
        () => h.preview(
          DeletePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
        rejected('NOT_ELIGIBLE'),
      );
      final archive = h.preview(
        ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
      );
      h.confirm(archive);
      final archived = h.snapshot.plants[plant.id]!;
      final deletion = h.preview(
        DeletePlant(plantId: plant.id, plantRevision: archived.revision),
      );
      expect(deletion.confirmationKey, 'confirm.DeletePlant.permanent');
      expect(deletion.confirmationKey, isNot(archive.confirmationKey));
      expect(deletion.effects.plants, 1);
      expect(deletion.effects.routines, 1);
      expect(deletion.effects.events, 1);
      expect(
        () => h.core.execute(
          datasetId: id(1),
          commandId: deletion.intent.commandId,
          command: deletion.intent.command,
          previewToken: archive.previewToken,
        ),
        rejected('PREVIEW_STALE'),
      );
      final before = h.snapshot;
      h.core.abandonPendingCommand(
        datasetId: id(1),
        commandId: deletion.intent.commandId,
      );
      expect(h.snapshot, same(before));
    },
  );

  test('deletion preview binds all saved content and draft-only revisions', () {
    final h = Harness();
    final plant = h.add(routines: [known()]);
    final other = h.add();
    h.confirm(
      h.preview(ArchivePlant(plantId: plant.id, plantRevision: plant.revision)),
    );
    final archived = h.snapshot.plants[plant.id]!;
    final draft = h.draft(
      fields(bases: {h.target().routineId: h.target().routineRevision}),
      plant: archived,
    );
    final deletion = h.preview(
      DeletePlant(plantId: plant.id, plantRevision: archived.revision),
    );
    // Saved content of another plant must invalidate this destructive preview.
    final editOther = h.draft(fields(name: 'Other changed'), plant: other);
    h.confirm(h.previewDraft(editOther));
    expect(() => h.confirm(deletion), rejected('PREVIEW_STALE'));
    final reviewed = h.preview(
      deletion.intent.command,
      commandId: deletion.intent.commandId,
    );
    final revision = h.snapshot.revision;
    h.draft(
      fields(name: 'New draft notes', bases: draft.fields.baseRoutineRevisions),
      old: draft,
      plant: archived,
    );
    expect(h.snapshot.revision, revision);
    expect(() => h.confirm(reviewed), rejected('PREVIEW_STALE'));
    expect(h.snapshot.plants.containsKey(plant.id), true);
  });

  test(
    'deletion rollback then lost reply removes owned data only and keeps minimal receipts',
    () {
      final h = Harness();
      final firstDraft = h.draft(fields(routines: [known()]));
      final originalSave = h.previewDraft(firstDraft);
      final saved = h.confirm(originalSave);
      final plant = h.snapshot.plants[saved.primaryId]!;
      final other = h.add(routines: [unknown()]);
      final originalRoutine = h.snapshot.routines.values.first;
      h.confirm(
        h.preview(
          CorrectEvent(
            h.target(originalRoutine),
            eventId: originalRoutine.events.single.id,
            eventRevision: 1,
            careDate: date('2026-10-19'),
            outcome: CareOutcome.actualCare,
          ),
        ),
      );
      h.confirm(
        h.preview(
          Snooze(
            h.target(h.snapshot.routines[originalRoutine.id]),
            date('2026-11-03'),
          ),
        ),
      );
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      final archived = h.snapshot.plants[plant.id]!;
      final draft = h.draft(
        fields(
          name: 'Private editor text',
          bases: {
            originalRoutine.id:
                h.snapshot.routines[originalRoutine.id]!.revision,
          },
        ),
        plant: archived,
      );
      final pendingEdit = h.previewDraft(draft);
      final unrelatedDraft = h.draft(fields(name: 'Unrelated add draft'));
      final deletion = h.preview(
        DeletePlant(plantId: plant.id, plantRevision: archived.revision),
      );
      expect(deletion.effects.corrections, 1);
      expect(deletion.effects.scheduleChanges, 2);
      expect(deletion.effects.drafts, 1);
      final before = h.snapshot;
      final changeId = before.scheduleChanges.keys.first;
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(deletion), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      expect(
        h.core.getPendingCommand(
          datasetId: id(1),
          commandId: pendingEdit.intent.commandId,
        ),
        same(pendingEdit.intent),
      );
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(deletion), throwsA(isA<UnknownCommandOutcome>()));
      h.restart();
      final resolved = h.core.resolvePendingCommand(
        datasetId: id(1),
        commandId: deletion.intent.commandId,
      );
      expect(resolved.committed, true);
      expect(resolved.result!.primaryId, plant.id);
      expect(resolved.result!.newRevisions, isEmpty);
      expect(h.confirm(deletion).replayed, true);
      expect(h.snapshot.plants.keys, [other.id]);
      expect(h.snapshot.routines.values.single.plantId, other.id);
      expect(h.snapshot.careKinds.length, 1);
      expect(h.snapshot.scheduleChanges, isEmpty);
      expect(h.snapshot.drafts.values.single, same(unrelatedDraft));
      expect(
        () => h.core.getScheduleChange(datasetId: id(1), changeId: changeId),
        rejected('NOT_FOUND'),
      );
      expect(
        () => h.core.getPendingCommand(
          datasetId: id(1),
          commandId: pendingEdit.intent.commandId,
        ),
        rejected('NOT_FOUND'),
      );
      expect(
        h.core
            .resolvePendingCommand(
              datasetId: id(1),
              commandId: originalSave.intent.commandId,
            )
            .result!
            .primaryId,
        plant.id,
      );
      // Original result remains recoverable but never resurrects the deleted plant.
      expect(h.confirm(originalSave).replayed, true);
      expect(h.snapshot.plants.containsKey(plant.id), false);
      expect(h.core.listPendingCommands(datasetId: id(1)), isEmpty);
    },
  );

  test(
    'retiring a routine invalidates an edit base, then explicit rereview can omit it',
    () {
      final h = Harness();
      final plant = h.add(routines: [known()]);
      final editor = h.core.getPlantEditor(datasetId: id(1), plantId: plant.id);
      final draft = h.draft(
        fields(
          name: 'My new name',
          bases: editor.initialFields.baseRoutineRevisions,
        ),
        plant: plant,
      );
      final pending = h.previewDraft(draft);
      h.confirm(h.preview(RetireRoutine(h.target())));
      expect(() => h.confirm(pending), rejected('DRAFT_CONFLICT'));
      final reviewed = h.draft(
        fields(name: 'My new name'),
        old: draft,
        plant: plant,
      );
      h.confirm(h.previewDraft(reviewed));
      expect(h.snapshot.plants[plant.id]!.name, 'My new name');
      expect(h.snapshot.routines.values.single.events.length, 1);
      expect(h.snapshot.eligibleRoutines, isEmpty);
    },
  );
}
