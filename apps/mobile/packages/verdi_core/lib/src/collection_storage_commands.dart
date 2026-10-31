part of 'collection.dart';

Map<String, Object?> _map(Object? value) =>
    (value as Map).cast<String, Object?>();
List<Object?> _list(Object? value) => (value as List).cast<Object?>();

CustomPlantFields _storedFields(Object? value) {
  final m = _map(value);
  if (m['identityKind'] != 'custom' ||
      m['coverPhotoId'] != null ||
      m['speciesId'] != null ||
      m['catalogSelection'] != null) {
    throw CommandRejected('STORAGE_INVALID');
  }
  final fields = CustomPlantFields(
    name: m['name'] as String,
    location: m['location'] as String,
    notes: m['notes'] as String,
    speciesName: m['customSpeciesName'] as String,
    light: CustomLight.values.byName(
      m['customLight'] == 'bright-indirect'
          ? 'brightIndirect'
          : m['customLight'] as String,
    ),
    toxicity: CustomToxicity.values.byName(
      m['customToxicity'] == 'non-toxic'
          ? 'nonToxic'
          : m['customToxicity'] as String,
    ),
    routines: _list(m['routineInputs']).map((v) {
      final r = _map(v);
      final seed = r['seed'] == null ? null : _map(r['seed']);
      return RoutineInput(
        kind: StandardCareKind.values.byName(r['kind'] as String),
        count: r['count'] as String,
        unit: IntervalUnit.values.byName(r['unit'] as String),
        seedKind: seed == null
            ? null
            : SeedKind.values.byName(seed['kind'] as String),
        date: seed == null
            ? ''
            : (seed['careDate'] ?? seed['firstCheckDate']) as String,
      );
    }),
    baseRoutineRevisions: {
      for (final v in _list(m['baseRoutineRevisions']))
        _map(v)['routineId'] as String: _map(v)['revision'] as int,
    },
    keepRoutineIds: _list(m['speciesChoices']).map((v) {
      final c = _map(v);
      if (c['decision'] != 'keep' || c['interval'] != null)
        throw CommandRejected('STORAGE_INVALID');
      return c['routineId'] as String;
    }),
  );
  if (canonicalCommandJson(fields._json()) != canonicalCommandJson(m))
    throw CommandRejected('STORAGE_INVALID');
  return fields;
}

CareTarget _storedTarget(Object? value) {
  final m = _map(value);
  return CareTarget(
    plantId: m['plantId'] as String,
    plantRevision: m['plantRevision'] as int,
    routineId: m['routineId'] as String,
    routineRevision: m['routineRevision'] as int,
    headId: m['headId'] as String,
    headRevision: m['headRevision'] as int,
  );
}

CoreCommand _storedCommand(String type, Map<String, Object?> p) {
  CareTarget target() => _storedTarget(p['target']);
  LocalDate d(String key) => LocalDate.parse(p[key] as String);
  final command = switch (type) {
    'SaveDraft' => SaveDraft(
      draftId: p['draftId'] as String,
      expectedRevision: p['expectedRevision'] as int?,
      mode: DraftMode.values.byName(p['mode'] as String),
      fields: _storedFields(p['rawFields']),
      plantId: p['plantId'] as String?,
      basePlantRevision: p['basePlantRevision'] as int?,
    ),
    'SavePlant' => SavePlant(
      draftId: p['draftId'] as String,
      draftRevision: p['draftRevision'] as int,
    ),
    'DiscardDraft' => DiscardDraft(
      draftId: p['draftId'] as String,
      draftRevision: p['draftRevision'] as int,
      confirmed: p['confirmed'] as bool,
    ),
    'CompleteCurrent' => CompleteCurrent(target(), d('careDate')),
    'CheckNotNeeded' => CheckNotNeeded(
      target(),
      d('checkDate'),
      d('nextCheckDate'),
    ),
    'Snooze' => Snooze(target(), d('nextCheckDate')),
    'Skip' => Skip(target()),
    'AddPastCare' => AddPastCare(
      target(),
      d('careDate'),
      CareStorage.outcome(p['outcome'] as String),
    ),
    'CorrectEvent' || 'RestoreEvent' => CorrectEvent(
      target(),
      eventId: p['eventId'] as String,
      eventRevision: p['eventRevision'] as int,
      careDate: d('careDate'),
      outcome: CareStorage.outcome(p['outcome'] as String),
      restore: type == 'RestoreEvent',
    ),
    'VoidEvent' => VoidEvent(
      target(),
      eventId: p['eventId'] as String,
      eventRevision: p['eventRevision'] as int,
    ),
    'SetInterval' => SetInterval(
      target(),
      CareInterval(
        _map(p['interval'])['count'] as int,
        IntervalUnit.values.byName(_map(p['interval'])['unit'] as String),
      ),
      firstCheckDate: CareStorage.date(p['firstCheckDate']),
    ),
    'ClearOverride' => ClearOverride(
      target(),
      firstCheckDate: CareStorage.date(p['firstCheckDate']),
    ),
    'PauseRoutine' => PauseRoutine(target()),
    'ResumeRoutine' => ResumeRoutine(target()),
    'RetireRoutine' => RetireRoutine(target()),
    'ArchivePlant' => ArchivePlant(
      plantId: p['plantId'] as String,
      plantRevision: p['plantRevision'] as int,
    ),
    'RestorePlant' => RestorePlant(
      plantId: p['plantId'] as String,
      plantRevision: p['plantRevision'] as int,
    ),
    'DeletePlant' => DeletePlant(
      plantId: p['plantId'] as String,
      plantRevision: p['plantRevision'] as int,
    ),
    'BulkComplete' => BulkComplete(
      careKind: StandardCareKind.values.byName(p['careKind'] as String),
      careDate: d('careDate'),
      targets: _list(p['targets']).map(_storedTarget),
    ),
    'Undo' => Undo(p['originalCommandId'] as String),
    _ => throw CommandRejected('PROTOCOL_INCOMPATIBLE'),
  };
  _validateShape(command);
  if (canonicalCommandJson(command._payload) != canonicalCommandJson(p))
    throw CommandRejected('STORAGE_INVALID');
  return command;
}

Map<String, Object?> _successJson(CommandSuccess r) => {
  'commandId': r.commandId,
  'datasetId': r.datasetId,
  'collectionRevision': r.collectionRevision,
  'primaryId': r.primaryId,
  'primaryType': r.primaryType,
  'replayed': r.replayed,
  'resourceIds': r.resourceIds,
  'newRevisions': r.newRevisions,
  'notices': r.notices,
};
Map<String, Object?> _headJson(RoutineHeadValues r) => {
  'version': 1,
  'headId': r.headId,
  'intervalCount': r.interval.count,
  'intervalUnit': r.interval.unit.name,
  'anchor': r.anchor.toString(),
  'firstCheckAnchor': r.firstCheckAnchor,
  'firstCheckDate': r.firstCheckDate?.toString(),
  'nextCheck': r.nextCheck.toString(),
  'overrideDate': r.overrideDate?.toString(),
  'status': r.status.name,
  'archived': r.archived,
};
RoutineHeadValues _storedHead(Object? value) {
  final m = _map(value);
  if (m['version'] != 1) throw CommandRejected('STORAGE_INVALID');
  final r = RoutineHeadValues._stored(
    m['headId'] as String,
    CareInterval(
      m['intervalCount'] as int,
      IntervalUnit.values.byName(m['intervalUnit'] as String),
    ),
    LocalDate.parse(m['anchor'] as String),
    m['firstCheckAnchor'] as bool,
    CareStorage.date(m['firstCheckDate']),
    LocalDate.parse(m['nextCheck'] as String),
    CareStorage.date(m['overrideDate']),
    RoutineStatus.values.byName(m['status'] as String),
    m['archived'] as bool,
  );
  if (canonicalCommandJson(_headJson(r)) != canonicalCommandJson(m))
    throw CommandRejected('STORAGE_INVALID');
  return r;
}
