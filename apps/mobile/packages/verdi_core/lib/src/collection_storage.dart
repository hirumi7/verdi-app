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
    'plant_catalog',
    'suggestion_snapshots',
    'routine_suggestions',
    'journal_entries',
    'journal_drafts',
    'media_drafts',
    'photos',
    'plant_covers',
    'custom_care_types',
    'routine_custom_types',
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

  /// Read-only native summary for preview planning; native rechecks at commit.
  void hydrateAccess({required bool pro, required int revision}) {
    _revision(revision);
    _store._pro = pro;
    _store._capabilityRevision = revision;
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
      final lengths = [
        11,
        13,
        5,
        11,
        12,
        10,
        8,
        4,
        11,
        3,
        8,
        9,
        8,
        14,
        2,
        4,
        2,
      ];
      for (var t = 0; t < tables.length; t++) {
        final tableIds = <String>{};
        for (final row in rows[tables[t]]!) {
          if (row.length != lengths[t])
            throw CommandRejected('STORAGE_INVALID');
          _id(row[0] as String);
          if (!tableIds.add(row[0] as String))
            throw CommandRejected('STORAGE_INVALID');
          if (![
                'plant_catalog',
                'routine_suggestions',
                'plant_covers',
                'routine_custom_types',
              ].contains(tables[t]) &&
              !ids.add(row[0] as String))
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
          rows['plant_catalog']!
              .where((c) => c[0] == r[0])
              .map(
                (c) => CatalogSelection.fromJson(
                  c[1] as String,
                  jsonDecode(c[3] as String),
                ),
              )
              .firstOrNull,
        );
      }
      for (final row in rows['plant_catalog']!) {
        final plant = plants[row[0]],
            selection = plants[row[0]]?.catalogSelection;
        if (plant == null ||
            selection == null ||
            row[2] != selection.catalogVersion ||
            plant.speciesName != selection.speciesNameSnapshot ||
            plant.light != CustomLight.unknown ||
            plant.toxicity != CustomToxicity.unknown) {
          throw CommandRejected('STORAGE_INVALID');
        }
      }
      final types = <String, CustomCareType>{};
      for (final row in rows['custom_care_types']!) {
        _revision(row[1] as int);
        final errors = <String, String>{};
        final label = _text(
          row[2] as String,
          24,
          'label',
          errors,
          required: true,
        );
        if (errors.isNotEmpty || label != row[2])
          throw CommandRejected('STORAGE_INVALID');
        types[row[0] as String] = CustomCareType(
          row[0] as String,
          row[1] as int,
          label,
          CareStorage.flag(row[3]),
        );
      }
      final links = <String, String>{};
      for (final row in rows['routine_custom_types']!) {
        _id(row[1] as String);
        if (!types.containsKey(row[1]))
          throw CommandRejected('STORAGE_INVALID');
        links[row[0] as String] = row[1] as String;
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
        if ((kind == StandardCareKind.custom) != links.containsKey(r[0]))
          throw CommandRejected('STORAGE_INVALID');
        if (kind == StandardCareKind.custom) {
          if (r[5] != 'retired' && r[4] != types[links[r[0]]]!.label)
            throw CommandRejected('STORAGE_INVALID');
          for (final e in rows['care_events']!.where((e) => e[2] == r[0])) {
            final errors = <String, String>{};
            _text(e[5] as String, 24, 'label', errors, required: true);
            if (errors.isNotEmpty) throw CommandRejected('STORAGE_INVALID');
          }
        }
        var routine = CareStorage.hydrate(
          routine: r,
          head: heads.single,
          archived: parent.archived,
          events: rows['care_events']!.where((e) => e[2] == r[0]).toList(),
          corrections: rows['event_corrections']!,
        );
        if (kind != StandardCareKind.custom &&
            routines.values.any(
              (x) =>
                  x.plantId == routine.plantId &&
                  x.status != RoutineStatus.retired &&
                  routine.status != RoutineStatus.retired &&
                  kinds[x.id] == kind,
            ))
          throw CommandRejected('STORAGE_INVALID');
        final link = rows['routine_suggestions']!
            .where((c) => c[0] == r[0])
            .firstOrNull;
        if (link != null)
          routine = routine.withSuggestions(
            link[1] as String?,
            link[2] as String,
          );
        routines[routine.id] = routine;
        kinds[routine.id] = kind;
      }
      if (links.keys.any((id) => !routines.containsKey(id)))
        throw CommandRejected('STORAGE_INVALID');
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
        final fields = _storedFields(
          fieldsEnvelope['fields'],
          rows['photos']!.where((p) => p[2] == r[0]).map((p) => p[0] as String),
        );
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
      final suggestions = <String, SuggestionSnapshot>{};
      for (final row in rows['suggestion_snapshots']!) {
        final routine = routines[row[1]];
        if (routine == null ||
            routine.plantId != row[2] ||
            kinds[routine.id]!.name != row[5])
          throw CommandRejected('STORAGE_INVALID');
        suggestions[row[0] as String] = SuggestionSnapshot(
          row[0] as String,
          row[1] as String,
          row[2] as String,
          row[3] as String,
          row[4] as String,
          CatalogSuggestion(
            kinds[routine.id]!,
            CareInterval(
              row[6] as int,
              IntervalUnit.values.byName(row[7] as String),
            ),
            row[9] as String,
            row[8] as String,
          ),
          CareStorage.instant(row[10]),
        );
      }
      for (final routine in routines.values) {
        for (final sid in [
          routine.originalSuggestionId,
          routine.appliedSuggestionId,
        ].whereType<String>()) {
          if (suggestions[sid]?.routineId != routine.id)
            throw CommandRejected('STORAGE_INVALID');
        }
      }
      if (rows['plant_catalog']!.any((c) => !plants.containsKey(c[0])) ||
          rows['routine_suggestions']!.any((c) => !routines.containsKey(c[0])))
        throw CommandRejected('STORAGE_INVALID');
      final media = _HydratedMedia(rows, plants, drafts);
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
          suggestions,
          media.entries,
          media.drafts,
          media.media,
          media.photos,
          media.covers,
          types,
          links,
        ),
        prior.receipts,
        prior.usedDraftIds,
        prior.undoneCommands,
      );
      _store._reservedIds.addAll(ids);
      _store._draftIds.addAll([
        ...drafts.keys,
        ...media.drafts.keys,
        ...media.media.keys,
      ]);
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
    if (command is SaveJournalDraft) _store._draftIds.add(command.draftId);
    if (command is SaveMediaDraft) _store._draftIds.add(command.draftId);
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
          snapshot.suggestions.values
              .where((s) => s.plantId == command.plantId)
              .length,
          snapshot.plants[command.plantId]!.catalogSelection == null ? 0 : 1,
          snapshot.routines.values
              .where(
                (r) =>
                    r.plantId == command.plantId &&
                    r.appliedSuggestionId != null,
              )
              .length,
          snapshot.journalEntries.values
              .where((e) => e.plantId == command.plantId)
              .length,
          snapshot.photos.values
              .where(
                (p) =>
                    p.plantId == command.plantId ||
                    snapshot.drafts[p.draftId]?.plantId == command.plantId ||
                    snapshot.journalDrafts[p.draftId]?.plantId ==
                        command.plantId ||
                    snapshot.mediaDrafts[p.draftId]?.plantId == command.plantId,
              )
              .length,
          [
            for (final d
                in snapshot.journalDrafts.values
                    .where((d) => d.plantId == command.plantId)
                    .toList()
                  ..sort((a, b) => a.id.compareTo(b.id)))
              {'draftId': d.id, 'revision': d.revision},
          ],
          [
            for (final d
                in snapshot.mediaDrafts.values
                    .where((d) => d.plantId == command.plantId)
                    .toList()
                  ..sort((a, b) => a.id.compareTo(b.id)))
              {'draftId': d.id, 'revision': d.revision},
          ],
          snapshot.customTypeIds.keys
              .where((id) => snapshot.routines[id]?.plantId == command.plantId)
              .length,
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
                (table == 'plant_drafts' && index == 7) ||
                (table == 'journal_entries' && index == 7) ||
                (table == 'journal_drafts' && index == 8) ||
                (table == 'media_drafts' && index == 7))
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
    if (command is MediaCommand) {
      final ids = <String>{
        if (command.guardedDraftId != null) command.guardedDraftId!,
      };
      if (command is DeleteJournalEntry)
        ids.addAll(
          snapshot.journalDrafts.values
              .where((d) => d.entryId == command.entryId)
              .map((d) => d.id),
        );
      if (command is DeletePhoto)
        ids.addAll(
          snapshot.drafts.values
              .where((d) => d.fields.coverPhotoId == command.photoId)
              .map((d) => d.id),
        );
      if (command is DeletePhoto)
        ids.addAll(
          snapshot.journalDrafts.values
              .where((d) => d.fields.selectedPhotoIds.contains(command.photoId))
              .map((d) => d.id),
        );
      for (final id in ids.toList()..sort()) {
        draftGuards.add({
          'draftId': id,
          'revision': id == command.guardedDraftId
              ? command.guardedDraftRevision
              : snapshot.journalDrafts[id]?.revision ??
                    snapshot.mediaDrafts[id]?.revision ??
                    snapshot.drafts[id]?.revision,
        });
      }
    }
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
      draftGuards.addAll(
        snapshot.journalDrafts.values
            .where((d) => d.plantId == command.plantId)
            .map((d) => {'draftId': d.id, 'revision': d.revision}),
      );
      draftGuards.addAll(
        snapshot.mediaDrafts.values
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
          command is CreateCustomCareType ||
              (command is CreateRoutine &&
                  command.careKind == StandardCareKind.custom) ||
              command is RestorePlant ||
              (command is SavePlant &&
                  snapshot.drafts[command.draftId]?.mode == DraftMode.add)
          ? _store._capabilityRevision
          : null,
      'expectedToday': _draftOnly(command) ? null : clock.today.toString(),
      'effectsHash': command._needsPreview ? canonicalValueHash(effects) : null,
      'statements': statements,
      'result': _successJson(result),
      'changeKind': _draftOnly(command) ? 'draft' : 'collection',
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
    result['custom_care_types']!.addAll(
      s.customCareTypes.values.map(
        (t) => [t.id, t.revision, t.label, t.retired ? 1 : 0],
      ),
    );
    result['routine_custom_types']!.addAll(
      s.customTypeIds.entries.map((e) => [e.key, e.value]),
    );
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
          e.careLabel,
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
    for (final p in s.plants.values) {
      final c = p.catalogSelection;
      if (c != null)
        result['plant_catalog']!.add([
          p.id,
          c.speciesId,
          c.catalogVersion,
          canonicalCommandJson(c.toJson()),
        ]);
    }
    for (final r in s.routines.values) {
      if (r.appliedSuggestionId != null)
        result['routine_suggestions']!.add([
          r.id,
          r.originalSuggestionId,
          r.appliedSuggestionId,
        ]);
    }
    for (final v in s.suggestions.values) {
      final c = v.suggestion;
      result['suggestion_snapshots']!.add([
        v.id,
        v.routineId,
        v.plantId,
        v.speciesId,
        v.catalogVersion,
        c.careKind.name,
        c.interval.count,
        c.interval.unit.name,
        c.sourceLabel,
        c.context,
        v.capturedAt.toIso8601String(),
      ]);
    }
    result['journal_entries']!.addAll(
      s.journalEntries.values.map((e) => e.toRow()),
    );
    result['journal_drafts']!.addAll(
      s.journalDrafts.values.map((d) => d.toRow()),
    );
    result['media_drafts']!.addAll(s.mediaDrafts.values.map((d) => d.toRow()));
    result['photos']!.addAll(s.photos.values.map((p) => p.toRow()));
    result['plant_covers']!.addAll(
      s.covers.entries.map((e) => <Object?>[e.key, e.value]),
    );
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
    'journal_entries': [6, 7],
    'journal_drafts': [7, 8],
    'media_drafts': [6, 7],
    'photos': [13],
    'suggestion_snapshots': [10],
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
