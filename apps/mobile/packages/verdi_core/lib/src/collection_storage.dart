part of 'collection.dart';

/// Normalized storage bridge. The in-memory model here is a working projection,
/// never the durable commit/receipt/clock authority. Only native acknowledgement
/// can publish a save or enable an Undo credential.
final class CoreStorageProjection {
  static const tables = [
    'plants',
    'routines',
    'heads',
    'care_events',
    'event_corrections',
    'routine_changes',
    'plant_drafts',
  ];
  final MemoryCoreStore _store;
  late final MemoryOperationCoordinator reader;
  late CareClock clock;
  final Stopwatch _elapsed = Stopwatch()..start();
  Map<String, List<List<Object?>>> _rows = {for (final t in tables) t: []};
  int storageRevision = 1;
  CoreStorageProjection({
    required String datasetId,
    required String Function() nextId,
    required this.clock,
  }) : _store = MemoryCoreStore(datasetId: datasetId, nextId: nextId) {
    reader = MemoryOperationCoordinator(
      _store,
      clock: () => ClockReading(clock, _elapsed.elapsed),
    );
  }
  String get datasetId => _store._state.collection.datasetId;
  CollectionSnapshot get snapshot => _store._state.collection;

  /// Reject inconsistent/unknown rows as a whole. No corrupt row is dropped.
  void hydrate(
    Map<String, List<List<Object?>>> rows,
    int revision,
    int storageRevision,
  ) {
    try {
      if (rows.keys.toSet().difference(tables.toSet()).isNotEmpty ||
          !tables.every(rows.containsKey))
        throw CommandRejected('STORAGE_INVALID');
      _revision(revision);
      _revision(storageRevision);
      final ids = <String>{};
      final lengths = [11, 13, 5, 11, 12, 10, 8];
      for (var t = 0; t < tables.length; t++) {
        for (final row in rows[tables[t]]!) {
          if (row.length != lengths[t])
            throw CommandRejected('STORAGE_INVALID');
          _id(row[0] as String);
          if (!ids.add(row[0] as String))
            throw CommandRejected('STORAGE_INVALID');
        }
      }
      final plants = <String, PlantCore>{};
      for (final r in rows['plants']!) {
        _revision(r[1] as int);
        plants[r[0] as String] = PlantCore._(
          r[0] as String,
          r[1] as int,
          r[2] as String,
          r[3] as String,
          r[4] as String,
          r[5] as String,
          CustomLight.values.byName(r[6] as String),
          CustomToxicity.values.byName(r[7] as String),
          CareStorage.instant(r[9]),
          CareStorage.instant(r[10]),
          CareStorage.flag(r[8]),
        );
      }
      final routines = <String, RoutineCore>{};
      final kinds = <String, StandardCareKind>{};
      final eventIds = rows['care_events']!.map((e) => e[0]).toSet();
      if (rows['event_corrections']!.any((c) => !eventIds.contains(c[1])))
        throw CommandRejected('STORAGE_INVALID');
      for (final r in rows['routines']!) {
        final parent = plants[r[1]];
        final heads = rows['heads']!.where((h) => h[1] == r[0]).toList();
        if (parent == null || heads.length != 1)
          throw CommandRejected('STORAGE_INVALID');
        CareStorage.instant(r[11]);
        CareStorage.instant(r[12]);
        final kind = StandardCareKind.values.byName(r[3] as String);
        final routine = CareStorage.hydrate(
          routine: r,
          head: heads.single,
          archived: parent.archived,
          events: rows['care_events']!.where((e) => e[2] == r[0]).toList(),
          corrections: rows['event_corrections']!,
        );
        if (routines.values.any(
          (x) =>
              x.plantId == routine.plantId &&
              x.status != RoutineStatus.retired &&
              routine.status != RoutineStatus.retired &&
              kinds[x.id] == kind,
        ))
          throw CommandRejected('STORAGE_INVALID');
        routines[routine.id] = routine;
        kinds[routine.id] = kind;
      }
      if (rows['heads']!.any((h) => !routines.containsKey(h[1])) ||
          rows['care_events']!.any((e) => !routines.containsKey(e[2])))
        throw CommandRejected('STORAGE_INVALID');
      final drafts = <String, PlantDraft>{};
      for (final r in rows['plant_drafts']!) {
        _revision(r[1] as int);
        final mode = DraftMode.values.byName(r[2] as String);
        final fieldsEnvelope = _map(jsonDecode(r[5] as String));
        if (fieldsEnvelope['version'] != 1 || fieldsEnvelope.keys.length != 2)
          throw CommandRejected('STORAGE_INVALID');
        final fields = _storedFields(fieldsEnvelope['fields']);
        final command = SaveDraft(
          draftId: r[0] as String,
          expectedRevision: r[1] as int,
          mode: mode,
          plantId: r[3] as String?,
          basePlantRevision: r[4] as int?,
          fields: fields,
        );
        _validateShape(command);
        if ((mode == DraftMode.edit && !plants.containsKey(r[3])) ||
            drafts.values.any((d) => d.plantId == r[3]))
          throw CommandRejected('STORAGE_INVALID');
        drafts[r[0] as String] = PlantDraft._(
          r[0] as String,
          r[1] as int,
          mode,
          r[3] as String?,
          r[4] as int?,
          fields,
          CareStorage.instant(r[6]),
          CareStorage.instant(r[7]),
        );
      }
      final changes = <String, ScheduleChange>{};
      for (final r in rows['routine_changes']!) {
        final routine = routines[r[2]];
        if (routine == null || routine.plantId != r[1])
          throw CommandRejected('STORAGE_INVALID');
        _id(r[3] as String);
        changes[r[0] as String] = ScheduleChange._stored(
          r[0] as String,
          r[3] as String,
          r[1] as String,
          r[2] as String,
          routine.careLabel,
          ScheduleChangeKind.values.byName(r[4] as String),
          LocalDate.parse(r[5] as String),
          CareStorage.instant(r[6]),
          r[7] as String,
          _storedHead(jsonDecode(r[8] as String)),
          _storedHead(jsonDecode(r[9] as String)),
        );
      }
      final prior = _store._state;
      _store._state = _State(
        CollectionSnapshot._(
          datasetId,
          revision,
          plants,
          routines,
          kinds,
          drafts,
          revision - 1,
          changes,
        ),
        prior.receipts,
        prior.usedDraftIds,
        prior.undoneCommands,
      );
      _store._reservedIds.addAll(ids);
      _store._draftIds.addAll(drafts.keys);
      _rows = {
        for (final entry in rows.entries)
          entry.key: entry.value
              .map((r) => List<Object?>.unmodifiable(r))
              .toList(growable: false),
      };
      this.storageRevision = storageRevision;
    } catch (_) {
      throw CommandRejected('STORAGE_INVALID');
    }
  }

  FrozenCommand freeze(
    CoreCommand command, {
    String? existingCommandId,
    String? newCommandId,
  }) {
    if (existingCommandId != null)
      return reader.freeze(
        datasetId: datasetId,
        command: command,
        commandId: existingCommandId,
      );
    final allocated = reader.freeze(datasetId: datasetId, command: command);
    if (newCommandId == null) return allocated;
    _id(newCommandId);
    if (!_store._reservedIds.add(newCommandId))
      throw CommandRejected('COMMAND_ID_REUSED');
    _store._intents.remove(allocated.commandId);
    final frozen = FrozenCommand._(
      datasetId,
      newCommandId,
      command,
      command.payloadHash,
      allocated.allocatedIds,
    );
    _store._intents[newCommandId] = frozen;
    return frozen;
  }

  Map<String, Object?> frozenJson(FrozenCommand c) => {
    'commandId': c.commandId,
    'datasetId': c.datasetId,
    'commandType': c.command.type,
    'normalisedPayload': c.command._payload,
    'payloadHash': c.payloadHash,
    'allocatedIds': c.allocatedIds,
  };
  FrozenCommand restoreFrozen(Map<String, Object?> m) {
    if (m['datasetId'] != datasetId) throw CommandRejected('DATASET_CHANGED');
    final command = _storedCommand(
      m['commandType'] as String,
      _map(m['normalisedPayload']),
    );
    final id = m['commandId'] as String;
    _id(id);
    final allocated = _list(m['allocatedIds']).cast<String>();
    for (final id in allocated) {
      _id(id);
    }
    if (allocated.toSet().length != allocated.length ||
        m['payloadHash'] != command.payloadHash)
      throw CommandRejected('STORAGE_INVALID');
    final c = FrozenCommand._(
      datasetId,
      id,
      command,
      command.payloadHash,
      allocated,
    );
    _store._intents[id] = c;
    _store._reservedIds.addAll([id, ...allocated]);
    if (command is SaveDraft) _store._draftIds.add(command.draftId);
    return c;
  }

  void forget(String id) {
    _store._intents.remove(id);
  }

  void invalidateUndo() => reader.invalidateUndoOffers();

  CoreStoragePlan plan(FrozenCommand intent, String sessionId) {
    final p = reader._plan(intent, clock);
    final command = intent.command;
    final next = _encode(p.next);
    final statements = <Map<String, Object?>>[];
    if (command is DeletePlant) {
      final owned =
          _rows['plant_drafts']!.where((r) => r[3] == command.plantId).toList()
            ..sort((a, b) => (a[0] as String).compareTo(b[0] as String));
      statements.add({
        'key': 'plants.deleteTree',
        'beforeHash': canonicalValueHash(
          _rows['plants']!.singleWhere((r) => r[0] == command.plantId),
        ),
        'values': [
          command.plantId,
          command.plantRevision,
          p.effects.routines,
          p.effects.events,
          p.effects.corrections,
          p.effects.scheduleChanges,
          [
            for (final r in owned) {'draftId': r[0], 'revision': r[1]},
          ],
        ],
      });
    } else {
      for (final table in tables) {
        final old = {for (final r in _rows[table]!) r[0] as String: r};
        final newer = {for (final r in next[table]!) r[0] as String: r};
        for (final r in newer.values) {
          final before = old[r[0]];
          if (canonicalCommandJson(before) == canonicalCommandJson(r)) continue;
          final values = List<Object?>.from(r);
          for (final index in _instantColumns[table] ?? <int>[]) {
            if (before == null ||
                (table == 'plants' && index == 10) ||
                (table == 'routines' && index == 12) ||
                (table == 'plant_drafts' && index == 7))
              values[index] = {'native': 'transaction_instant'};
          }
          if (before == null && table == 'care_events') {
            values[9] = {'native': 'transaction_zone'};
            if (command is Skip)
              values[6] = {'native': 'transaction_local_date'};
          }
          if (before == null && table == 'routine_changes') {
            values[5] = {'native': 'transaction_local_date'};
            values[7] = {'native': 'transaction_zone'};
          }
          statements.add({
            'key': '$table.${before == null ? 'insert' : 'update'}',
            'beforeHash': before == null ? null : canonicalValueHash(before),
            'values': values,
          });
        }
        for (final r in old.values.where((r) => !newer.containsKey(r[0]))) {
          statements.add({
            'key': '$table.delete',
            'beforeHash': canonicalValueHash(r),
            'values': [r[0]],
          });
        }
      }
    }
    final result = CommandSuccess._(
      intent.commandId,
      datasetId,
      p.next.revision,
      p.primaryId,
      p.primaryType,
      false,
      command is DeletePlant ? [command.plantId] : p.resourceIds,
      p.revisions,
      p.notices,
    );
    final draftGuards = <Map<String, Object?>>[];
    if (command is SaveDraft)
      draftGuards.add({
        'draftId': command.draftId,
        'revision': command.expectedRevision,
      });
    if (command is SavePlant)
      draftGuards.add({
        'draftId': command.draftId,
        'revision': command.draftRevision,
      });
    if (command is DiscardDraft)
      draftGuards.add({
        'draftId': command.draftId,
        'revision': command.draftRevision,
      });
    if (command is DeletePlant) {
      draftGuards.addAll(
        snapshot.drafts.values
            .where((d) => d.plantId == command.plantId)
            .map((d) => {'draftId': d.id, 'revision': d.revision}),
      );
      draftGuards.sort(
        (a, b) => (a['draftId'] as String).compareTo(b['draftId'] as String),
      );
    }
    final effects = {
      'rows': [
        for (final r in p.effects.rows)
          {
            'plantId': r.plantId,
            'plantName': r.plantName,
            'routineId': r.routineId,
            'oldNextCheck': r.oldNextCheck?.toString(),
            'newNextCheck': r.newNextCheck?.toString(),
            'careKind': r.careKind?.name,
            'careLabel': r.careLabel,
          },
      ],
      'historyOnly': p.effects.historyOnly,
      'plants': p.effects.plants,
      'routines': p.effects.routines,
      'events': p.effects.events,
      'corrections': p.effects.corrections,
      'scheduleChanges': p.effects.scheduleChanges,
      'drafts': p.effects.drafts,
      'gate': p.effects.gate.name,
    };
    final map = <String, Object?>{
      'sessionId': sessionId,
      'datasetId': datasetId,
      'commandId': intent.commandId,
      'commandType': command.type,
      'normalisedPayload': command._payload,
      'payloadHash': intent.payloadHash,
      'expectedCollectionRevision': snapshot.revision,
      'draftGuards': draftGuards,
      'accessRevision':
          command is RestorePlant ||
              (command is SavePlant &&
                  snapshot.drafts[command.draftId]?.mode == DraftMode.add)
          ? 1
          : null,
      'expectedToday': command is SaveDraft || command is DiscardDraft
          ? null
          : clock.today.toString(),
      'effectsHash': command._needsPreview ? canonicalValueHash(effects) : null,
      'statements': statements,
      'result': _successJson(result),
      'changeKind': command is SaveDraft || command is DiscardDraft
          ? 'draft'
          : 'collection',
    };
    final hash = canonicalValueHash(map);
    map['previewToken'] = null;
    map['planHash'] = hash;
    return CoreStoragePlan._(
      intent,
      p.effects,
      map,
      _captureUndo(command, snapshot, p.next),
      p.next,
    );
  }

  Map<String, List<List<Object?>>> _encode(CollectionSnapshot s) {
    final result = {for (final t in tables) t: <List<Object?>>[]};
    for (final p in s.plants.values) {
      result['plants']!.add([
        p.id,
        p.revision,
        p.name,
        p.location,
        p.notes,
        p.speciesName,
        p.light.name,
        p.toxicity.name,
        p.archived ? 1 : 0,
        p.createdAt.toIso8601String(),
        p.updatedAt.toIso8601String(),
      ]);
    }
    for (final r in s.routines.values) {
      final old = _rows['routines']!.where((x) => x[0] == r.id).firstOrNull;
      result['routines']!.add([
        r.id,
        r.plantId,
        r.revision,
        s.careKinds[r.id]!.name,
        r.careLabel,
        r.status.name,
        r.interval.count,
        r.interval.unit.name,
        r.anchor.toString(),
        r.firstCheckAnchor ? 1 : 0,
        r.firstCheckDate?.toString(),
        old?[11] ?? clock.instant.toIso8601String(),
        old != null && old[2] == r.revision
            ? old[12]
            : clock.instant.toIso8601String(),
      ]);
      result['heads']!.add([
        r.headId,
        r.id,
        r.headRevision,
        r.nextCheck.toString(),
        r.overrideDate?.toString(),
      ]);
      for (final e in r.events) {
        result['care_events']!.add([
          e.id,
          r.plantId,
          r.id,
          e.revision,
          s.careKinds[r.id]!.name,
          r.careLabel,
          e.original.careDate.toString(),
          _outcomeName(e.original.outcome),
          e.recordedAt.toIso8601String(),
          e.recordedZone,
          e.commandId,
        ]);
        for (var i = 0; i < e.corrections.length; i++) {
          final c = e.corrections[i];
          result['event_corrections']!.add([
            c.id,
            e.id,
            i + 1,
            c.before.careDate.toString(),
            _outcomeName(c.before.outcome),
            c.before.voided ? 1 : 0,
            c.after.careDate.toString(),
            _outcomeName(c.after.outcome),
            c.after.voided ? 1 : 0,
            c.correctedAt.toIso8601String(),
            c.commandId,
            c.reason,
          ]);
        }
      }
    }
    for (final c in s.scheduleChanges.values) {
      result['routine_changes']!.add([
        c.id,
        c.plantId,
        c.routineId,
        c.commandId,
        c.kind.name,
        c.changeDate.toString(),
        c.changedAt.toIso8601String(),
        c.recordedZone,
        canonicalCommandJson(_headJson(c.before)),
        canonicalCommandJson(_headJson(c.after)),
      ]);
    }
    for (final d in s.drafts.values) {
      result['plant_drafts']!.add([
        d.id,
        d.revision,
        d.mode.name,
        d.plantId,
        d.basePlantRevision,
        canonicalCommandJson({'version': 1, 'fields': d.fields._json()}),
        d.createdAt.toIso8601String(),
        d.updatedAt.toIso8601String(),
      ]);
    }
    // Preserve exact native timestamp spellings on unchanged rows.
    for (final t in tables) {
      final old = {for (final r in _rows[t]!) r[0]: r};
      for (final r in result[t]!) {
        final prior = old[r[0]];
        if (prior == null) continue;
        for (final i in _instantColumns[t] ?? <int>[]) {
          if (CareStorage.instant(prior[i]) == CareStorage.instant(r[i]))
            r[i] = prior[i];
        }
      }
    }
    return result;
  }

  static const _instantColumns = <String, List<int>>{
    'plants': [9, 10],
    'routines': [11, 12],
    'care_events': [8],
    'event_corrections': [9],
    'routine_changes': [6],
    'plant_drafts': [6, 7],
  };

  PreparedCommand prepared(
    CoreStoragePlan plan,
    String token,
    String expiresAt,
  ) => PreparedCommand._(
    plan.intent,
    token,
    clock.today,
    1,
    plan.effects,
    DateTime.parse(expiresAt),
  );
  CommandSuccess success(Map<String, Object?> m, {int? undoMilliseconds}) =>
      CommandSuccess._(
        m['commandId'] as String,
        m['datasetId'] as String,
        m['collectionRevision'] as int,
        m['primaryId'] as String?,
        m['primaryType'] as String?,
        m['replayed'] as bool,
        _list(m['resourceIds']).cast<String>(),
        _map(m['newRevisions']).cast<String, int>(),
        _list(m['notices']).cast<String>(),
        undoMilliseconds == null
            ? null
            : UndoOffer._(m['commandId'] as String, undoMilliseconds),
      );
  CommandResolution resolution(Map<String, Object?>? m) =>
      CommandResolution._(m == null ? null : success(m));
  void acknowledge(CoreStoragePlan plan, int remainingMilliseconds) {
    if (plan._undo.isEmpty || remainingMilliseconds <= 0) return;
    reader._undoGrants[plan.intent.commandId] = _UndoGrant(
      datasetId,
      _elapsed.elapsed - Duration(milliseconds: 8000 - remainingMilliseconds),
      plan._undo,
    );
  }
}

final class CoreStoragePlan {
  final FrozenCommand intent;
  final CommandEffects effects;
  final Map<String, Object?> _body;
  final List<_UndoMember> _undo;

  /// Candidate is test evidence only; native rows must be reloaded after commit.
  final CollectionSnapshot candidate;
  CoreStoragePlan._(
    this.intent,
    this.effects,
    this._body,
    this._undo,
    this.candidate,
  );
  Map<String, Object?> body({String? previewToken}) => {
    ..._body,
    'previewToken': previewToken,
  };
  bool get needsPreview => intent.command._needsPreview;
}
