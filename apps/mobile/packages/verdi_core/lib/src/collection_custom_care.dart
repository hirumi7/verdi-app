part of 'collection.dart';

const standardCareKinds = [
  StandardCareKind.water,
  StandardCareKind.fertilize,
  StandardCareKind.mist,
  StandardCareKind.repot,
  StandardCareKind.rotate,
];
String standardCareLabel(StandardCareKind kind) => switch (kind) {
  StandardCareKind.water => 'Water',
  StandardCareKind.fertilize => 'Fertilize',
  StandardCareKind.mist => 'Mist',
  StandardCareKind.repot => 'Repot',
  StandardCareKind.rotate => 'Rotate',
  StandardCareKind.custom => throw CommandRejected('FIELD_INVALID'),
};

final class CustomCareType {
  final String id, label;
  final int revision;
  final bool retired;
  const CustomCareType(this.id, this.revision, this.label, this.retired);
}

sealed class CustomCareCommand extends CoreCommand {
  const CustomCareCommand();
}

final class CreateCustomCareType extends CustomCareCommand {
  final String label;
  const CreateCustomCareType(this.label);
  @override
  String get type => 'CreateCustomCareType';
  @override
  Map<String, Object?> get _payload => {'label': label};
}

final class RenameCustomCareType extends CustomCareCommand {
  final String customTypeId, label;
  final int revision;
  const RenameCustomCareType(this.customTypeId, this.revision, this.label);
  @override
  String get type => 'RenameCustomCareType';
  @override
  Map<String, Object?> get _payload => {
    'customTypeId': customTypeId,
    'revision': revision,
    'label': label,
  };
}

final class RetireCustomCareType extends CustomCareCommand {
  final String customTypeId;
  final int revision;
  const RetireCustomCareType(this.customTypeId, this.revision);
  @override
  String get type => 'RetireCustomCareType';
  @override
  Map<String, Object?> get _payload => {
    'customTypeId': customTypeId,
    'revision': revision,
  };
}

final class CreateRoutine extends CustomCareCommand {
  final String plantId;
  final int plantRevision;
  final StandardCareKind careKind;
  final String? customTypeId;
  final int? customTypeRevision;
  final CareInterval interval;
  final SeedKind seedKind;
  final LocalDate seedDate;
  final CatalogSelection? catalogSelection;
  const CreateRoutine({
    required this.plantId,
    required this.plantRevision,
    required this.careKind,
    this.customTypeId,
    this.customTypeRevision,
    required this.interval,
    required this.seedKind,
    required this.seedDate,
    this.catalogSelection,
  });
  @override
  String get type => 'CreateRoutine';
  @override
  Map<String, Object?> get _payload => {
    'plantId': plantId,
    'plantRevision': plantRevision,
    'careKind': careKind.name,
    'customTypeId': customTypeId,
    'customTypeRevision': customTypeRevision,
    'interval': {'count': interval.count, 'unit': interval.unit.name},
    'seed': {
      'kind': seedKind.name,
      seedKind == SeedKind.known ? 'careDate' : 'firstCheckDate': seedDate
          .toString(),
    },
    'catalogSelection': catalogSelection == null
        ? null
        : {
            'speciesId': catalogSelection!.speciesId,
            ...catalogSelection!.toJson(),
          },
  };
}

void _validateCustomCare(CustomCareCommand c) {
  switch (c) {
    case CreateCustomCareType():
      break;
    case RenameCustomCareType():
      _id(c.customTypeId);
      _revision(c.revision);
    case RetireCustomCareType():
      _id(c.customTypeId);
      _revision(c.revision);
    case CreateRoutine():
      _id(c.plantId);
      _revision(c.plantRevision);
      if (c.careKind == StandardCareKind.custom) {
        if (c.customTypeId == null ||
            c.customTypeRevision == null ||
            c.catalogSelection != null)
          throw CommandRejected('FIELD_INVALID');
        _id(c.customTypeId!);
        _revision(c.customTypeRevision!);
      } else if (c.customTypeId != null || c.customTypeRevision != null) {
        throw CommandRejected('FIELD_INVALID');
      }
  }
  if (c is CreateCustomCareType || c is RenameCustomCareType) {
    final errors = <String, String>{};
    _text(
      c is CreateCustomCareType ? c.label : (c as RenameCustomCareType).label,
      24,
      'label',
      errors,
      required: true,
    );
    if (errors.isNotEmpty) throw CommandRejected('FIELD_INVALID', errors);
  }
}

extension on MemoryOperationCoordinator {
  _Plan _planCustomCare(FrozenCommand intent, CareClock clock) {
    final c = intent.command as CustomCareCommand, s = _store._state.collection;
    final types = {...s.customCareTypes},
        links = {...s.customTypeIds},
        routines = {...s.routines},
        kinds = {...s.careKinds},
        suggestions = {...s.suggestions};
    final resources = <String>{}, revisions = <String, int>{};
    final rows = <PreviewRow>[];
    var count = 0, events = 0;
    var gate = PreviewGate.allowed;
    String primaryId, primaryType;
    switch (c) {
      case CreateCustomCareType():
        primaryId = intent.allocatedIds.single;
        primaryType = 'customCareType';
        types[primaryId] = CustomCareType(primaryId, 1, c.label.trim(), false);
        gate = _store._pro ? PreviewGate.allowed : PreviewGate.proRequired;
      case RenameCustomCareType() || RetireCustomCareType():
        final id = c is RenameCustomCareType
            ? c.customTypeId
            : (c as RetireCustomCareType).customTypeId;
        final expected = c is RenameCustomCareType
            ? c.revision
            : (c as RetireCustomCareType).revision;
        final old = types[id];
        if (old == null) throw CommandRejected('NOT_FOUND');
        if (old.revision != expected) throw CommandRejected('STALE_TARGET');
        if (c is RetireCustomCareType && old.retired)
          throw CommandRejected('NOT_ELIGIBLE');
        primaryId = id;
        primaryType = 'customCareType';
        final label = c is RenameCustomCareType ? c.label.trim() : old.label;
        types[id] = CustomCareType(
          id,
          _nextRevision(old.revision),
          label,
          c is RetireCustomCareType || old.retired,
        );
        for (final r in s.routines.values.where(
          (r) => links[r.id] == id && r.status != RoutineStatus.retired,
        )) {
          count++;
          rows.add(
            PreviewRow._(
              r.plantId,
              s.plants[r.plantId]!.name,
              r.id,
              r.nextCheck,
              r.nextCheck,
              careKind: StandardCareKind.custom,
              careLabel: label,
            ),
          );
          if (c is RenameCustomCareType) {
            final next = r.renamed(label);
            routines[r.id] = next;
            resources.add(r.id);
            revisions[r.id] = next.revision;
          }
        }
      case CreateRoutine():
        final plant = s.plants[c.plantId];
        if (plant == null) throw CommandRejected('NOT_FOUND');
        if (plant.revision != c.plantRevision)
          throw CommandRejected('STALE_TARGET');
        if (plant.archived) throw CommandRejected('NOT_ELIGIBLE');
        String label;
        if (c.careKind == StandardCareKind.custom) {
          final type = types[c.customTypeId];
          if (type == null) throw CommandRejected('NOT_FOUND');
          if (type.revision != c.customTypeRevision)
            throw CommandRejected('STALE_TARGET');
          if (type.retired) throw CommandRejected('NOT_ELIGIBLE');
          label = type.label;
          gate = _store._pro ? PreviewGate.allowed : PreviewGate.proRequired;
        } else {
          if (routines.values.any(
            (r) =>
                r.plantId == plant.id &&
                r.status != RoutineStatus.retired &&
                kinds[r.id] == c.careKind,
          ))
            throw CommandRejected('NOT_ELIGIBLE');
          label = standardCareLabel(c.careKind);
        }
        final selection = c.catalogSelection;
        final suggestion = selection?.suggestion(c.careKind);
        if (selection != null &&
            (suggestion == null ||
                plant.catalogSelection == null ||
                selection.speciesId != plant.catalogSelection!.speciesId ||
                canonicalCommandJson(selection.toJson()) !=
                    canonicalCommandJson(plant.catalogSelection!.toJson())))
          throw CommandRejected('CATALOG_SELECTION_STALE');
        var slot = 0;
        primaryId = intent.allocatedIds[slot++];
        primaryType = 'routine';
        final head = intent.allocatedIds[slot++];
        var r = c.seedKind == SeedKind.unknown
            ? RoutineCore.unknown(
                id: primaryId,
                plantId: plant.id,
                headId: head,
                careLabel: label,
                interval: c.interval,
                firstCheck: c.seedDate,
              )
            : RoutineCore.known(
                id: primaryId,
                plantId: plant.id,
                headId: head,
                careLabel: label,
                interval: c.interval,
                careDate: c.seedDate,
                eventId: intent.allocatedIds[slot++],
                commandId: intent.commandId,
                clock: clock,
              );
        if (suggestion != null) {
          final sid = intent.allocatedIds[slot++];
          suggestions[sid] = SuggestionSnapshot(
            sid,
            r.id,
            plant.id,
            selection!.speciesId,
            selection.catalogVersion,
            suggestion,
            clock.instant,
          );
          r = r.withSuggestions(sid, sid);
          resources.add(sid);
        }
        routines[r.id] = r;
        kinds[r.id] = c.careKind;
        if (c.customTypeId != null) links[r.id] = c.customTypeId!;
        resources.addAll([r.id, r.headId, ...r.events.map((e) => e.id)]);
        revisions[r.id] = 1;
        revisions[r.headId] = 1;
        for (final e in r.events) {
          revisions[e.id] = 1;
        }
        count = 1;
        events = r.events.length;
        rows.add(
          PreviewRow._(
            plant.id,
            plant.name,
            r.id,
            null,
            r.nextCheck,
            careKind: c.careKind,
            careLabel: label,
          ),
        );
    }
    resources.add(primaryId);
    if (primaryType == 'customCareType')
      revisions[primaryId] = types[primaryId]!.revision;
    return _Plan(
      CollectionSnapshot._(
        s.datasetId,
        _nextRevision(s.revision),
        s.plants,
        routines,
        kinds,
        s.drafts,
        s.reminderGeneration + 1,
        s.scheduleChanges,
        suggestions,
        s.journalEntries,
        s.journalDrafts,
        s.mediaDrafts,
        s.photos,
        s.covers,
        types,
        links,
      ),
      CommandEffects._(rows, routines: count, events: events, gate: gate),
      canonicalCommandJson({
        'collectionRevision': s.revision,
        'access': _store._capabilityRevision,
      }),
      primaryId,
      primaryType,
      resources,
      revisions,
      [],
    );
  }
}
