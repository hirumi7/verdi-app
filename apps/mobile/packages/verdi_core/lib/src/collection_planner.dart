part of 'collection.dart';

void _validateShape(CoreCommand command) {
  late int bytes;
  try {
    bytes = utf8.encode(canonicalCommandJson(command._payload)).length;
  } on FormatException {
    throw CommandRejected('FIELD_INVALID');
  }
  if (bytes > _maxPayloadBytes) {
    throw CommandRejected('FIELD_INVALID', {'draft': 'PAYLOAD_TOO_LARGE'});
  }
  switch (command) {
    case SaveDraft():
      _id(command.draftId);
      if (command.expectedRevision != null)
        _revision(command.expectedRevision!);
      if (command.mode == DraftMode.add) {
        if (command.plantId != null ||
            command.basePlantRevision != null ||
            command.fields.baseRoutineRevisions.isNotEmpty ||
            command.fields.keepRoutineIds.isNotEmpty)
          throw CommandRejected('FIELD_INVALID');
      } else {
        if (command.plantId == null ||
            command.basePlantRevision == null ||
            command.fields.routines.isNotEmpty)
          throw CommandRejected('FIELD_INVALID');
        _id(command.plantId!);
        _revision(command.basePlantRevision!);
      }
      for (final entry in command.fields.baseRoutineRevisions.entries) {
        _id(entry.key);
        _revision(entry.value);
      }
      final choices = command.fields.keepRoutineIds;
      for (final id in choices) {
        _id(id);
      }
      if (choices.toSet().length != choices.length)
        throw CommandRejected('FIELD_INVALID');
    case SavePlant():
      _id(command.draftId);
      _revision(command.draftRevision);
    case DiscardDraft():
      _id(command.draftId);
      _revision(command.draftRevision);
    case PlantLifecycleCommand():
      _id(command.plantId);
      _revision(command.plantRevision);
    case Undo():
      _id(command.originalCommandId);
    case BulkComplete():
      if (command.targets.isEmpty ||
          command.targets.length > 200 ||
          command.targets.map((t) => t.routineId).toSet().length !=
              command.targets.length) {
        throw CommandRejected('FIELD_INVALID');
      }
      for (final target in command.targets) {
        _validateShape(CompleteCurrent(target, command.careDate));
      }
    case RoutineCommand():
      final target = command.target;
      for (final id in [target.plantId, target.routineId, target.headId]) {
        _id(id);
      }
      for (final revision in [
        target.plantRevision,
        target.routineRevision,
        target.headRevision,
      ]) {
        _revision(revision);
      }
      if (command is CorrectEvent) {
        _id(command.eventId);
        _revision(command.eventRevision);
      }
      if (command is VoidEvent) {
        _id(command.eventId);
        _revision(command.eventRevision);
      }
  }
}

bool _validUnicode(String value) {
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit == 0) return false;
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i == value.length) return false;
      final next = value.codeUnitAt(i);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

String _text(
  String raw,
  int max,
  String path,
  Map<String, String> errors, {
  bool required = false,
  bool trim = true,
}) {
  final value = trim ? raw.trim() : raw;
  if (!_validUnicode(value) ||
      value.characters.length > max ||
      (required && value.isEmpty))
    errors[path] = 'FIELD_INVALID';
  return value;
}

final class _Plan {
  final CollectionSnapshot next;
  final CommandEffects effects;
  final String binding;
  final String? primaryId;
  final String? primaryType;
  final Set<String> resourceIds;
  final Map<String, int> revisions;
  final List<String> notices;
  const _Plan(
    this.next,
    this.effects,
    this.binding,
    this.primaryId,
    this.primaryType,
    this.resourceIds,
    this.revisions,
    this.notices,
  );
}

extension on MemoryOperationCoordinator {
  _Plan _plan(FrozenCommand intent, CareClock clock) {
    try {
      return _calculate(intent, clock);
    } on CommandRejected {
      rethrow;
    } on DomainException catch (error) {
      throw CommandRejected(error.code);
    }
  }

  _Plan _calculate(FrozenCommand intent, CareClock clock) {
    final current = _store._state.collection;
    final plants = {...current.plants};
    final routines = {...current.routines};
    final careKinds = {...current.careKinds};
    final drafts = {...current.drafts};
    final changes = {...current.scheduleChanges};
    var collectionRevision = current.revision;
    var reminderGeneration = current.reminderGeneration;
    final resources = <String>{};
    final revisions = <String, int>{};
    final notices = <String>[];
    String? primaryId;
    String? primaryType;
    var effects = CommandEffects._([]);
    final bindings = <String, Object?>{};
    final command = intent.command;

    switch (command) {
      case Undo():
        final grant = _undoGrant(command.originalCommandId);
        var allocation = 0;
        for (final member in grant.members) {
          final old = routines[member.routineId]!;
          final correctionIds = <String, String>{
            for (final eventId in member.eventIds)
              eventId: intent.allocatedIds[allocation++],
          };
          final next = old.undoTo(
            member.before,
            expectedRevision: member.postRevision,
            originalCommandId: command.originalCommandId,
            commandId: intent.commandId,
            correctionIds: correctionIds,
            clock: clock,
          );
          routines[old.id] = next;
          final changeId = intent.allocatedIds[allocation++];
          changes[changeId] = ScheduleChange._(
            changeId,
            intent.commandId,
            ScheduleChangeKind.undo,
            old,
            next,
            clock,
          );
          resources.addAll([
            old.id,
            old.headId,
            changeId,
            ...correctionIds.keys,
            ...correctionIds.values,
          ]);
          revisions[old.id] = next.revision;
          revisions[old.headId] = next.headRevision;
          for (final event in next.events.where(
            (e) => correctionIds.containsKey(e.id),
          )) {
            revisions[event.id] = event.revision;
          }
        }
        collectionRevision = _nextRevision(collectionRevision);
        reminderGeneration++;
        effects = CommandEffects._(
          [],
          routines: grant.members.length,
          corrections: grant.members.fold(0, (n, m) => n + m.eventIds.length),
          scheduleChanges: grant.members.length,
        );

      case BulkComplete():
        final rows = <PreviewRow>[];
        for (var i = 0; i < command.targets.length; i++) {
          final target = command.targets[i];
          final old = _targetRoutine(current, target);
          if (careKinds[old.id] != command.careKind) {
            throw CommandRejected('FIELD_INVALID', {
              old.id: 'CARE_KIND_MISMATCH',
            });
          }
          late RoutineCore next;
          try {
            next = old.complete(
              careDate: command.careDate,
              eventId: intent.allocatedIds[i],
              commandId: intent.commandId,
              clock: clock,
            );
          } on DomainException catch (error) {
            throw CommandRejected(error.code, {old.id: error.code});
          }
          routines[old.id] = next;
          resources.addAll([old.id, old.headId, intent.allocatedIds[i]]);
          revisions[old.id] = next.revision;
          revisions[old.headId] = next.headRevision;
          revisions[intent.allocatedIds[i]] = 1;
          rows.add(
            PreviewRow._(
              old.plantId,
              plants[old.plantId]!.name,
              old.id,
              old.nextCheck,
              next.nextCheck,
            ),
          );
        }
        bindings['targets'] = command.targets.map((t) => t._json()).toList();
        collectionRevision = _nextRevision(collectionRevision);
        reminderGeneration++;
        effects = CommandEffects._(
          rows,
          routines: rows.length,
          events: rows.length,
        );

      case SaveDraft():
        final old = drafts[command.draftId];
        if (old?.revision != command.expectedRevision)
          throw CommandRejected('STALE_TARGET');
        if (old == null &&
            _store._state.usedDraftIds.contains(command.draftId)) {
          throw CommandRejected('NOT_ELIGIBLE');
        }
        if (old != null &&
            (old.mode != command.mode || old.plantId != command.plantId)) {
          throw CommandRejected('DRAFT_CONFLICT');
        }
        if (drafts.values.any(
          (d) => d.id != command.draftId && d.plantId == command.plantId,
        )) {
          throw CommandRejected('DRAFT_CONFLICT');
        }
        if (command.mode == DraftMode.edit &&
            !plants.containsKey(command.plantId)) {
          throw CommandRejected('NOT_FOUND');
        }
        final revision = old == null ? 1 : _nextRevision(old.revision);
        drafts[command.draftId] = PlantDraft._(
          command.draftId,
          revision,
          command.mode,
          command.plantId,
          command.basePlantRevision,
          command.fields,
          old?.createdAt ?? clock.instant,
          clock.instant,
        );
        primaryId = command.draftId;
        primaryType = 'draft';
        resources.add(primaryId);
        revisions[primaryId] = revision;

      case DiscardDraft():
        if (!command.confirmed) throw CommandRejected('NOT_ELIGIBLE');
        _draft(command.draftId, command.draftRevision);
        drafts.remove(command.draftId);
        primaryId = command.draftId;
        primaryType = 'draft';
        resources.add(primaryId);

      case SavePlant():
        final draft = _draft(command.draftId, command.draftRevision);
        final fields = draft.fields;
        final errors = <String, String>{};
        final name = _text(fields.name, 60, 'name', errors, required: true);
        final location = _text(fields.location, 40, 'location', errors);
        final notes = _text(fields.notes, 2000, 'notes', errors, trim: false);
        final species = _text(
          fields.speciesName,
          120,
          'customSpeciesName',
          errors,
          required: true,
        );
        final seeds =
            <({RoutineInput raw, CareInterval interval, LocalDate date})>[];
        final kinds = <StandardCareKind>{};
        for (var i = 0; i < fields.routines.length; i++) {
          final raw = fields.routines[i];
          if (!kinds.add(raw.kind))
            errors['routineInputs[$i].kind'] = 'FIELD_INVALID';
          CareInterval? interval;
          LocalDate? date;
          final count = RegExp(r'^[0-9]+$').hasMatch(raw.count)
              ? int.tryParse(raw.count)
              : null;
          if (count == null || count < 1 || count > 9999) {
            errors['routineInputs[$i].count'] = 'FIELD_INVALID';
          } else {
            interval = CareInterval(count, raw.unit);
          }
          try {
            date = LocalDate.parse(raw.date);
          } on DomainException {
            errors['routineInputs[$i].date'] = 'FIELD_INVALID';
          }
          if (date != null &&
              raw.seedKind == SeedKind.known &&
              date.compareTo(clock.today) > 0) {
            errors['routineInputs[$i].date'] = 'FUTURE_CARE_DATE';
          }
          if (interval != null && date != null)
            seeds.add((raw: raw, interval: interval, date: date));
        }
        if (errors.isNotEmpty) throw CommandRejected('FIELD_INVALID', errors);
        final old = draft.plantId == null ? null : plants[draft.plantId];
        final isAdd = draft.mode == DraftMode.add;
        bindings['draftRevision'] = draft.revision;
        if (!isAdd) {
          if (old == null) throw CommandRejected('NOT_FOUND');
          if (old.revision != draft.basePlantRevision)
            throw CommandRejected('STALE_TARGET');
          final currentBases = {
            for (final r in routines.values.where(
              (r) => r.plantId == old.id && r.status != RoutineStatus.retired,
            ))
              r.id: r.revision,
          };
          if (canonicalCommandJson(currentBases) !=
              canonicalCommandJson(fields.baseRoutineRevisions)) {
            throw CommandRejected('DRAFT_CONFLICT');
          }
          final changed =
              old.speciesName != species ||
              old.light != fields.light ||
              old.toxicity != fields.toxicity;
          final expected = changed ? currentBases.keys.toSet() : <String>{};
          if (fields.keepRoutineIds.toSet().length != expected.length ||
              !fields.keepRoutineIds.toSet().containsAll(expected)) {
            throw CommandRejected('FIELD_INVALID', {
              'speciesChoices': 'FIELD_INVALID',
            });
          }
          bindings['plantRevision'] = old.revision;
          bindings['routineRevisions'] = currentBases;
        } else {
          bindings['capabilityRevision'] = _store._capabilityRevision;
          bindings['activeCount'] = current.activePlants.length;
        }
        final gate = isAdd && !_store._pro && current.activePlants.length >= 5
            ? PreviewGate.activeLimit
            : PreviewGate.allowed;
        var allocation = 0;
        final plantId = old?.id ?? intent.allocatedIds[allocation++];
        final plantRevision = old == null ? 1 : _nextRevision(old.revision);
        plants[plantId] = PlantCore._(
          plantId,
          plantRevision,
          name,
          location,
          notes,
          species,
          fields.light,
          fields.toxicity,
          old?.createdAt ?? clock.instant,
          clock.instant,
          old?.archived ?? false,
        );
        final rows = <PreviewRow>[];
        var eventCount = 0;
        for (final seed in seeds) {
          final routineId = intent.allocatedIds[allocation++];
          final headId = intent.allocatedIds[allocation++];
          final label = switch (seed.raw.kind) {
            StandardCareKind.water => 'Water',
            StandardCareKind.fertilize => 'Fertilize',
            StandardCareKind.mist => 'Mist',
            StandardCareKind.repot => 'Repot',
            StandardCareKind.rotate => 'Rotate',
          };
          final routine = seed.raw.seedKind == SeedKind.unknown
              ? RoutineCore.unknown(
                  id: routineId,
                  plantId: plantId,
                  headId: headId,
                  careLabel: label,
                  interval: seed.interval,
                  firstCheck: seed.date,
                )
              : RoutineCore.known(
                  id: routineId,
                  plantId: plantId,
                  headId: headId,
                  careLabel: label,
                  interval: seed.interval,
                  careDate: seed.date,
                  eventId: intent.allocatedIds[allocation++],
                  commandId: intent.commandId,
                  clock: clock,
                );
          routines[routineId] = routine;
          careKinds[routineId] = seed.raw.kind;
          resources.addAll([routineId, headId]);
          revisions[routineId] = 1;
          revisions[headId] = 1;
          for (final event in routine.events) {
            resources.add(event.id);
            revisions[event.id] = event.revision;
            eventCount++;
          }
          rows.add(
            PreviewRow._(plantId, name, routineId, null, routine.nextCheck),
          );
        }
        if (rows.isEmpty)
          rows.add(PreviewRow._(plantId, name, null, null, null));
        drafts.remove(draft.id);
        resources.addAll([plantId, draft.id]);
        revisions[plantId] = plantRevision;
        primaryId = plantId;
        primaryType = 'plant';
        collectionRevision = _nextRevision(collectionRevision);
        reminderGeneration++;
        effects = CommandEffects._(
          rows,
          plants: 1,
          routines: seeds.length,
          events: eventCount,
          gate: gate,
        );

      case PlantLifecycleCommand():
        final plant = plants[command.plantId];
        if (plant == null) throw CommandRejected('NOT_FOUND');
        if (plant.revision != command.plantRevision)
          throw CommandRejected('STALE_TARGET');
        final owned =
            routines.values.where((r) => r.plantId == plant.id).toList()
              ..sort((a, b) => a.id.compareTo(b.id));
        bindings['plantRevision'] = plant.revision;
        bindings['routineRevisions'] = {
          for (final r in owned) r.id: r.revision,
        };
        primaryId = plant.id;
        primaryType = 'plant';
        resources.add(plant.id);
        final eventCount = owned.fold<int>(0, (n, r) => n + r.events.length);
        final correctionCount = owned.fold<int>(
          0,
          (n, r) =>
              n + r.events.fold<int>(0, (n, e) => n + e.corrections.length),
        );
        final ownedChanges = changes.values
            .where((c) => c.plantId == plant.id)
            .toList();
        final ownedDrafts = drafts.values
            .where((d) => d.plantId == plant.id)
            .toList();
        if (command is DeletePlant) {
          if (!plant.archived) throw CommandRejected('NOT_ELIGIBLE');
          bindings['collectionRevision'] = current.revision;
          // Draft-only edits do not bump collectionRevision; bind them explicitly
          // because deletion also removes those newly acknowledged personal notes.
          bindings['draftRevisions'] = {
            for (final d in ownedDrafts) d.id: d.revision,
          };
          plants.remove(plant.id);
          for (final r in owned) {
            routines.remove(r.id);
            careKinds.remove(r.id);
            resources.addAll([r.id, r.headId]);
            for (final e in r.events) {
              resources.add(e.id);
              resources.addAll(e.corrections.map((c) => c.id));
            }
          }
          for (final change in ownedChanges) {
            changes.remove(change.id);
            resources.add(change.id);
          }
          for (final draft in ownedDrafts) {
            drafts.remove(draft.id);
            resources.add(draft.id);
          }
          effects = CommandEffects._(
            [PreviewRow._(plant.id, plant.name, null, null, null)],
            plants: 1,
            routines: owned.length,
            events: eventCount,
            corrections: correctionCount,
            scheduleChanges: ownedChanges.length,
            drafts: ownedDrafts.length,
          );
        } else {
          final restoring = command is RestorePlant;
          if (plant.archived != restoring)
            throw CommandRejected('NOT_ELIGIBLE');
          if (intent.allocatedIds.length != owned.length)
            throw CommandRejected('STALE_TARGET');
          if (restoring) {
            bindings['capabilityRevision'] = _store._capabilityRevision;
            bindings['activeCount'] = current.activePlants.length;
          }
          final gate =
              restoring && !_store._pro && current.activePlants.length >= 5
              ? PreviewGate.activeLimit
              : PreviewGate.allowed;
          final nextPlant = plant._setArchived(!restoring, clock.instant);
          plants[plant.id] = nextPlant;
          revisions[plant.id] = nextPlant.revision;
          final rows = <PreviewRow>[];
          for (var i = 0; i < owned.length; i++) {
            final r = owned[i];
            final next = restoring ? r.restore(clock) : r.archive();
            routines[r.id] = next;
            final changeId = intent.allocatedIds[i];
            changes[changeId] = ScheduleChange._(
              changeId,
              intent.commandId,
              restoring
                  ? ScheduleChangeKind.restore
                  : ScheduleChangeKind.archive,
              r,
              next,
              clock,
            );
            resources.addAll([r.id, r.headId, changeId]);
            revisions[r.id] = next.revision;
            revisions[r.headId] = next.headRevision;
            rows.add(
              PreviewRow._(
                plant.id,
                plant.name,
                r.id,
                r.nextCheck,
                next.nextCheck,
              ),
            );
          }
          if (rows.isEmpty)
            rows.add(PreviewRow._(plant.id, plant.name, null, null, null));
          effects = CommandEffects._(
            rows,
            plants: 1,
            routines: owned.length,
            events: eventCount,
            corrections: correctionCount,
            scheduleChanges: owned.length,
            drafts: ownedDrafts.length,
            gate: gate,
          );
        }
        collectionRevision = _nextRevision(collectionRevision);
        reminderGeneration++;

      case RoutineCommand():
        final target = command.target;
        final plant = plants[target.plantId];
        final routine = routines[target.routineId];
        if (plant == null || routine == null)
          throw CommandRejected('NOT_FOUND');
        if (routine.plantId != plant.id || routine.headId != target.headId) {
          throw CommandRejected('FIELD_INVALID');
        }
        if (plant.revision != target.plantRevision ||
            routine.revision != target.routineRevision ||
            routine.headRevision != target.headRevision)
          throw CommandRejected('STALE_TARGET');
        final allocation = intent.allocatedIds.firstOrNull;
        final next = switch (command) {
          CompleteCurrent() => routine.complete(
            careDate: command.careDate,
            eventId: allocation!,
            commandId: intent.commandId,
            clock: clock,
          ),
          AddPastCare() => routine.addPast(
            careDate: command.careDate,
            outcome: command.outcome,
            eventId: allocation!,
            commandId: intent.commandId,
            clock: clock,
          ),
          CheckNotNeeded() => routine.checkNotNeeded(
            checkDate: command.checkDate,
            nextDate: command.nextDate,
            eventId: allocation!,
            commandId: intent.commandId,
            clock: clock,
          ),
          Snooze() => routine.snooze(command.nextDate, clock),
          Skip() => routine.skip(
            eventId: allocation!,
            commandId: intent.commandId,
            clock: clock,
          ),
          CorrectEvent() => routine.correct(
            eventId: command.eventId,
            eventRevision: command.eventRevision,
            correctionId: allocation!,
            commandId: intent.commandId,
            careDate: command.careDate,
            outcome: command.outcome,
            clock: clock,
            restore: command.restore,
          ),
          VoidEvent() => routine.voidEvent(
            eventId: command.eventId,
            eventRevision: command.eventRevision,
            correctionId: allocation!,
            commandId: intent.commandId,
            clock: clock,
          ),
          SetInterval() => routine.setInterval(
            command.interval,
            clock,
            chosenFirstCheck: command.firstCheckDate,
          ),
          ClearOverride() => routine.clearOverride(
            clock,
            chosenFirstCheck: command.firstCheckDate,
          ),
          PauseRoutine() => routine.pause(),
          ResumeRoutine() => routine.resume(clock),
          RetireRoutine() => routine.retire(),
        };
        routines[routine.id] = next;
        collectionRevision = _nextRevision(collectionRevision);
        final historyOnly =
            command is AddPastCare ||
            command is CorrectEvent ||
            command is VoidEvent;
        if (historyOnly) notices.add('HISTORY_CHANGED_CHECK_UNCHANGED');
        if (!historyOnly) reminderGeneration++;
        primaryId = switch (command) {
          CorrectEvent() => command.eventId,
          VoidEvent() => command.eventId,
          AddPastCare() => allocation!,
          _ => routine.id,
        };
        primaryType = historyOnly ? 'event' : 'routine';
        resources.add(routine.id);
        revisions[routine.id] = next.revision;
        if (next.headRevision != routine.headRevision) {
          resources.add(next.headId);
          revisions[next.headId] = next.headRevision;
        }
        final isSchedule = command is ScheduleCommand || command is Snooze;
        if (isSchedule) {
          final kind = switch (command) {
            SetInterval() => ScheduleChangeKind.interval,
            PauseRoutine() => ScheduleChangeKind.pause,
            ResumeRoutine() => ScheduleChangeKind.resume,
            RetireRoutine() => ScheduleChangeKind.retire,
            _ => ScheduleChangeKind.override,
          };
          changes[allocation!] = ScheduleChange._(
            allocation,
            intent.commandId,
            kind,
            routine,
            next,
            clock,
          );
        }
        if (allocation != null) {
          resources.add(allocation);
          // Correction rows have a sequence, not an entity revision.
          if (!isSchedule && command is! CorrectEvent && command is! VoidEvent)
            revisions[allocation] = 1;
        }
        if (command is CorrectEvent || command is VoidEvent) {
          resources.add(primaryId);
          revisions[primaryId] = next.events
              .firstWhere((e) => e.id == primaryId)
              .revision;
        }
        bindings['target'] = target._json();
        effects = CommandEffects._(
          [
            PreviewRow._(
              plant.id,
              plant.name,
              routine.id,
              routine.nextCheck,
              next.nextCheck,
            ),
          ],
          historyOnly: historyOnly,
          routines: 1,
          events: isSchedule ? 0 : 1,
          scheduleChanges: isSchedule ? 1 : 0,
        );
    }
    return _Plan(
      CollectionSnapshot._(
        current.datasetId,
        collectionRevision,
        plants,
        routines,
        careKinds,
        drafts,
        reminderGeneration,
        changes,
      ),
      effects,
      canonicalCommandJson(bindings),
      primaryId,
      primaryType,
      resources,
      revisions,
      notices,
    );
  }
}
