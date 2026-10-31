import 'package:test/test.dart' hide Skip;
import 'package:verdi_core/verdi_core.dart';
import 'collection_test.dart'
    show Harness, date, id, known, unknown, rejected, fields;

BulkComplete group(Harness h, [Iterable<RoutineCore>? routines]) =>
    BulkComplete(
      careKind: StandardCareKind.water,
      careDate: h.today,
      targets:
          (routines ??
                  h.snapshot.routines.values.where(
                    (r) => h.snapshot.careKinds[r.id] == StandardCareKind.water,
                  ))
              .map(h.target),
    );

Harness pair() => Harness()
  ..add(routines: [known()])
  ..add(routines: [known()]);

void main() {
  test('an observed expiry cannot be revived by a later clock rewind', () {
    final h = pair();
    final saved = h.confirm(h.preview(group(h)));
    h.elapsed = const Duration(milliseconds: 8000);
    expect(() => h.submit(Undo(saved.commandId)), rejected('UNDO_EXPIRED'));
    h.elapsed = const Duration(milliseconds: 7999);
    expect(() => h.submit(Undo(saved.commandId)), rejected('UNDO_UNAVAILABLE'));
  });

  test('Undo rechecks expiry at the publication boundary', () {
    final h = pair();
    var crossing = false;
    var samples = 0;
    h.core = MemoryOperationCoordinator(
      h.store,
      clock: () {
        final reading = h.reading();
        if (!crossing) return reading;
        samples++;
        return ClockReading(
          reading.care,
          Duration(milliseconds: samples < 3 ? 7999 : 8000),
        );
      },
    );
    final saved = h.confirm(h.preview(group(h)));
    final command = Undo(saved.commandId);
    final frozen = h.core.freeze(datasetId: id(1), command: command);
    final before = h.snapshot;
    // Execution clock/plan observe 7,999ms; publication observes 8,000ms.
    crossing = true;
    expect(
      () => h.core.execute(
        datasetId: id(1),
        commandId: frozen.commandId,
        command: command,
      ),
      rejected('UNDO_EXPIRED'),
    );
    expect(h.snapshot, same(before));
    expect(samples, 3);
    expect(
      h.core
          .getCommandResult(datasetId: id(1), commandId: frozen.commandId)
          .committed,
      isFalse,
    );
  });

  test(
    'invalid care date identifies its member without partial group changes',
    () {
      final h = Harness()
        ..add(routines: [known(day: '2026-10-01')])
        ..add(routines: [known(day: '2026-10-20')]);
      final before = h.snapshot;
      final lastId = before.routines.values.last.id;
      expect(
        () => h.preview(
          BulkComplete(
            careKind: StandardCareKind.water,
            careDate: date('2026-10-10'),
            targets: before.routines.values.map(h.target),
          ),
        ),
        throwsA(
          isA<CommandRejected>()
              .having((e) => e.code, 'code', 'CARE_PRECEDES_LATEST')
              .having((e) => e.fields, 'affected member', {
                lastId: 'CARE_PRECEDES_LATEST',
              }),
        ),
      );
      expect(h.snapshot, same(before));
    },
  );
  test(
    'explicit group previews both dates and leaves unselected care unchanged',
    () {
      final h = pair()..add(routines: [known(kind: StandardCareKind.mist)]);
      final untouched = h.snapshot.routines.values.last;
      final before = h.snapshot;
      final preview = h.preview(group(h));
      expect(preview.effects.rows.length, 2);
      expect(
        preview.effects.rows.map((r) => r.newNextCheck),
        everyElement(date('2026-11-01')),
      );
      expect(h.snapshot, same(before));
      final result = h.confirm(preview);
      expect(result.primaryId, isNull);
      expect(result.primaryType, isNull);
      expect(result.undo?.expiresInMilliseconds, 8000);
      expect(h.snapshot.revision, before.revision + 1);
      expect(h.snapshot.reminderGeneration, before.reminderGeneration + 1);
      expect(h.snapshot.routines[untouched.id], same(untouched));
      expect(h.snapshot.routines.values.take(2).map((r) => r.actualCareCount), [
        2,
        2,
      ]);
    },
  );

  test('selection order has the same canonical hash and receipt identity', () {
    final h = pair();
    final command = group(h);
    final reversed = BulkComplete(
      careKind: command.careKind,
      careDate: command.careDate,
      targets: command.targets.reversed,
    );
    expect(command.payloadHash, reversed.payloadHash);
    final p = h.preview(command);
    h.confirm(p);
    final before = h.snapshot;
    final retry = h.core.execute(
      datasetId: id(1),
      commandId: p.intent.commandId,
      command: reversed,
    );
    expect(retry.replayed, isTrue);
    expect(retry.undo, isNull);
    expect(h.snapshot, same(before));
  });

  test('empty, duplicate, oversized and mixed selections do not mutate', () {
    final h = pair()..add(routines: [known(kind: StandardCareKind.mist)]);
    final target = h.target();
    final before = h.snapshot;
    for (final targets in [
      <CareTarget>[],
      [target, target],
      List.filled(201, target),
      h.snapshot.routines.values.map(h.target).toList(),
    ]) {
      expect(
        () => h.preview(
          BulkComplete(
            careKind: StandardCareKind.water,
            careDate: h.today,
            targets: targets,
          ),
        ),
        rejected('FIELD_INVALID'),
      );
    }
    expect(h.snapshot, same(before));
  });

  test('changed last member rejects whole group and preserves selection', () {
    final h = pair();
    final p = h.preview(group(h));
    h.confirm(
      h.preview(
        Snooze(h.target(h.snapshot.routines.values.last), date('2026-11-03')),
      ),
    );
    final before = h.snapshot;
    expect(() => h.confirm(p), rejected('STALE_TARGET'));
    expect(h.snapshot, same(before));
    expect(
      h.core
          .getPendingCommand(datasetId: id(1), commandId: p.intent.commandId)
          .command,
      same(p.intent.command),
    );
  });

  test(
    'before commit fault rolls back all members; lost reply recovers one receipt',
    () {
      final h = pair();
      final p = h.preview(group(h));
      final before = h.snapshot;
      h.store.nextFault = SimulatedFault.beforeCommit;
      expect(() => h.confirm(p), rejected('STORAGE_UNAVAILABLE'));
      expect(h.snapshot, same(before));
      h.store.nextFault = SimulatedFault.afterCommitReplyLost;
      expect(() => h.confirm(p), throwsA(isA<UnknownCommandOutcome>()));
      h.restart();
      final recovered = h.core.resolvePendingCommand(
        datasetId: id(1),
        commandId: p.intent.commandId,
      );
      expect(recovered.committed, isTrue);
      expect(recovered.result!.undo, isNull);
      expect(h.confirm(p).replayed, isTrue);
      expect(h.snapshot.routines.values.map((r) => r.actualCareCount), [2, 2]);
      expect(
        () => h.submit(Undo(p.intent.commandId)),
        rejected('UNDO_UNAVAILABLE'),
      );
    },
  );

  test(
    'group Undo at 7999ms restores values with newer revisions and retained audit',
    () {
      final h = pair();
      final before = h.snapshot;
      final saved = h.confirm(h.preview(group(h)));
      final completed = h.snapshot;
      h.elapsed = const Duration(milliseconds: 7999);
      final undone = h.submit(Undo(saved.commandId));
      expect(undone.primaryId, isNull);
      expect(undone.undo, isNull);
      for (final r in h.snapshot.routines.values) {
        expect(r.nextCheck, before.routines[r.id]!.nextCheck);
        expect(r.anchor, before.routines[r.id]!.anchor);
        expect(r.headId, before.routines[r.id]!.headId);
        expect(r.revision, completed.routines[r.id]!.revision + 1);
        expect(r.headRevision, completed.routines[r.id]!.headRevision + 1);
        expect(r.actualCareCount, 1);
        expect(r.events.length, 2);
        expect(r.events.last.effective.voided, isTrue);
        expect(r.events.last.corrections.single.reason, 'undo');
      }
      expect(
        h.snapshot.scheduleChanges.values.map((c) => c.kind),
        everyElement(ScheduleChangeKind.undo),
      );
      expect(
        () => h.submit(Undo(saved.commandId)),
        rejected('UNDO_UNAVAILABLE'),
      );
    },
  );

  test('8000ms expiry and wall clock rewind cannot extend the offer', () {
    final h = pair();
    final saved = h.confirm(h.preview(group(h)));
    final before = h.snapshot;
    h.elapsed = const Duration(milliseconds: 8000);
    h.instant = DateTime.utc(2020);
    expect(() => h.submit(Undo(saved.commandId)), rejected('UNDO_EXPIRED'));
    expect(h.snapshot, same(before));
  });

  test('history-only change to one member blocks whole Undo', () {
    final h = pair();
    final saved = h.confirm(h.preview(group(h)));
    h.confirm(
      h.preview(
        AddPastCare(
          h.target(h.snapshot.routines.values.last),
          date('2026-10-01'),
          CareOutcome.actualCare,
        ),
      ),
    );
    final before = h.snapshot;
    expect(() => h.submit(Undo(saved.commandId)), rejected('UNDO_CHANGED'));
    expect(h.snapshot, same(before));
  });

  test('metadata-only edit does not invalidate a routine Undo', () {
    final h = Harness()..add(routines: [known()]);
    final saved = h.confirm(h.preview(CompleteCurrent(h.target(), h.today)));
    final plant = h.snapshot.plants.values.single;
    final bases = {
      for (final r in h.snapshot.routines.values) r.id: r.revision,
    };
    h.confirm(
      h.previewDraft(
        h.draft(
          fields(name: 'Renamed', bases: bases),
          plant: plant,
        ),
      ),
    );
    h.submit(Undo(saved.commandId));
    expect(h.snapshot.plants.values.single.name, 'Renamed');
    expect(h.snapshot.routines.values.single.actualCareCount, 1);
  });

  test('Undo fault rolls back; retry after lost reply does not undo twice', () {
    final h = pair();
    final saved = h.confirm(h.preview(group(h)));
    final command = Undo(saved.commandId);
    final frozen = h.core.freeze(datasetId: id(1), command: command);
    CommandSuccess execute() => h.core.execute(
      datasetId: id(1),
      commandId: frozen.commandId,
      command: command,
    );
    final before = h.snapshot;
    h.store.nextFault = SimulatedFault.beforeCommit;
    expect(execute, rejected('STORAGE_UNAVAILABLE'));
    expect(h.snapshot, same(before));
    h.store.nextFault = SimulatedFault.afterCommitReplyLost;
    expect(execute, throwsA(isA<UnknownCommandOutcome>()));
    final committed = h.snapshot;
    h.restart();
    expect(execute().replayed, isTrue);
    expect(h.snapshot, same(committed));
  });

  test(
    'restart, foreground invalidation and monotonic rewind revoke grants',
    () {
      for (final mode in ['restart', 'invalidate', 'rewind']) {
        final h = pair()..elapsed = const Duration(seconds: 2);
        final saved = h.confirm(h.preview(group(h)));
        if (mode == 'restart') h.restart();
        if (mode == 'invalidate') h.core.invalidateUndoOffers();
        if (mode == 'rewind') h.elapsed = Duration.zero;
        final before = h.snapshot;
        expect(
          () => h.submit(Undo(saved.commandId)),
          rejected('UNDO_UNAVAILABLE'),
        );
        expect(h.snapshot, same(before));
      }
    },
  );

  test(
    'single check, skip, snooze and unknown completion all restore exact head',
    () {
      for (final mode in ['check', 'skip', 'snooze', 'complete']) {
        final h = Harness()
          ..add(routines: [unknown(kind: StandardCareKind.water)]);
        final old = h.snapshot.routines.values.single;
        final CoreCommand command = switch (mode) {
          'check' => CheckNotNeeded(h.target(), h.today, date('2026-11-04')),
          'skip' => Skip(h.target()),
          'snooze' => Snooze(h.target(), date('2026-11-04')),
          _ => CompleteCurrent(h.target(), h.today),
        };
        final saved = h.confirm(h.preview(command));
        h.submit(Undo(saved.commandId));
        final next = h.snapshot.routines.values.single;
        expect(next.nextCheck, old.nextCheck);
        expect(next.overrideDate, old.overrideDate);
        expect(next.firstCheckAnchor, isTrue);
        expect(next.firstCheckDate, old.firstCheckDate);
        expect(next.actualCareCount, 0);
        expect(next.latestActualCare, isNull);
      }
    },
  );

  test(
    'deleting one member scrubs whole group grant but retains result recovery',
    () {
      final h = pair();
      final saved = h.confirm(h.preview(group(h)));
      var plant = h.snapshot.plants.values.first;
      h.confirm(
        h.preview(
          ArchivePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      plant = h.snapshot.plants[plant.id]!;
      h.confirm(
        h.preview(
          DeletePlant(plantId: plant.id, plantRevision: plant.revision),
        ),
      );
      expect(
        () => h.submit(Undo(saved.commandId)),
        rejected('UNDO_UNAVAILABLE'),
      );
      expect(
        h.core
            .getCommandResult(datasetId: id(1), commandId: saved.commandId)
            .committed,
        isTrue,
      );
      expect(h.snapshot.routines.values.single.actualCareCount, 2);
    },
  );
}
