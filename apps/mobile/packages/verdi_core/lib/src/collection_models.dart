part of 'collection.dart';

enum DraftMode { add, edit }

enum StandardCareKind { water, fertilize, mist, repot, rotate }

enum CustomLight { unknown, low, medium, brightIndirect, direct }

enum CustomToxicity { unknown, toxic, nonToxic }

enum SeedKind { known, unknown }

/// Raw editor text is intentionally not parsed until SavePlant is prepared.
final class RoutineInput {
  final StandardCareKind kind;
  final String count;
  final IntervalUnit unit;
  final SeedKind? seedKind;
  final String date;
  const RoutineInput({
    required this.kind,
    required this.count,
    required this.unit,
    required this.seedKind,
    required this.date,
  });

  Map<String, Object?> _json() {
    // seed:null has no date member in the documented wire shape. Reject an
    // impossible typed representation before hashing or retaining any payload.
    if (seedKind == null && date.isNotEmpty) {
      throw CommandRejected('FIELD_INVALID');
    }
    return {
      'kind': kind.name,
      'count': count,
      'unit': unit.name,
      'seed': seedKind == null
          ? null
          : seedKind == SeedKind.known
          ? {'kind': 'known', 'careDate': date}
          : {'kind': 'unknown', 'firstCheckDate': date},
    };
  }
}

/// The supported editor subset: custom identity, no media, standard new routines.
/// Catalog selection, apply-suggestion choices and existing-routine edits cannot
/// be expressed here; those need their own reviewed adapters and command types.
final class CustomPlantFields {
  final String name;
  final String location;
  final String notes;
  final String speciesName;
  final CustomLight light;
  final CustomToxicity toxicity;
  final List<RoutineInput> routines;
  final Map<String, int> baseRoutineRevisions;
  final List<String> keepRoutineIds;

  CustomPlantFields({
    this.name = '',
    this.location = '',
    this.notes = '',
    this.speciesName = '',
    this.light = CustomLight.unknown,
    this.toxicity = CustomToxicity.unknown,
    Iterable<RoutineInput> routines = const [],
    Map<String, int> baseRoutineRevisions = const {},
    Iterable<String> keepRoutineIds = const [],
  }) : routines = List.unmodifiable(routines),
       baseRoutineRevisions = Map.unmodifiable(baseRoutineRevisions),
       keepRoutineIds = List.unmodifiable(keepRoutineIds);

  Map<String, Object?> _json() {
    final bases = baseRoutineRevisions.keys.toList()..sort();
    final choices = keepRoutineIds.toList()..sort();
    return {
      'name': name,
      'location': location,
      'notes': notes,
      'identityKind': 'custom',
      'coverPhotoId': null,
      'speciesId': null,
      'catalogSelection': null,
      'customSpeciesName': speciesName,
      'customLight': light == CustomLight.brightIndirect
          ? 'bright-indirect'
          : light.name,
      'customToxicity': toxicity == CustomToxicity.nonToxic
          ? 'non-toxic'
          : toxicity.name,
      'routineInputs': routines.map((r) => r._json()).toList(),
      'baseRoutineRevisions': [
        for (final id in bases)
          {'routineId': id, 'revision': baseRoutineRevisions[id]},
      ],
      'speciesChoices': [
        for (final id in choices)
          {'routineId': id, 'decision': 'keep', 'interval': null},
      ],
    };
  }
}

final class PlantDraft {
  final String id;
  final int revision;
  final DraftMode mode;
  final String? plantId;
  final int? basePlantRevision;
  final CustomPlantFields fields;
  final DateTime createdAt;
  final DateTime updatedAt;
  const PlantDraft._(
    this.id,
    this.revision,
    this.mode,
    this.plantId,
    this.basePlantRevision,
    this.fields,
    this.createdAt,
    this.updatedAt,
  );
}

final class PlantCore {
  final String id;
  final int revision;
  final String name;
  final String location;
  final String notes;
  final String speciesName;
  final CustomLight light;
  final CustomToxicity toxicity;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  const PlantCore._(
    this.id,
    this.revision,
    this.name,
    this.location,
    this.notes,
    this.speciesName,
    this.light,
    this.toxicity,
    this.createdAt,
    this.updatedAt, [
    this.archived = false,
  ]);

  PlantCore _setArchived(bool value, DateTime instant) => PlantCore._(
    id,
    _nextRevision(revision),
    name,
    location,
    notes,
    speciesName,
    light,
    toxicity,
    createdAt,
    instant,
    value,
  );
}

enum ScheduleChangeKind {
  interval,
  override,
  pause,
  resume,
  retire,
  archive,
  restore,
  undo,
}

/// Value snapshot excludes history so an audit never holds duplicate event data.
final class RoutineHeadValues {
  final String headId;
  // The supported custom-plant core has no catalog suggestion snapshots yet.
  final String? originalSuggestionId = null;
  final String? appliedSuggestionId = null;
  final CareInterval interval;
  final LocalDate anchor;
  final bool firstCheckAnchor;
  final LocalDate? firstCheckDate;
  final LocalDate nextCheck;
  final LocalDate? overrideDate;
  final RoutineStatus status;
  final bool archived;
  RoutineHeadValues._(RoutineCore routine)
    : headId = routine.headId,
      interval = routine.interval,
      anchor = routine.anchor,
      firstCheckAnchor = routine.firstCheckAnchor,
      firstCheckDate = routine.firstCheckDate,
      nextCheck = routine.nextCheck,
      overrideDate = routine.overrideDate,
      status = routine.status,
      archived = routine.archived;
}

final class ScheduleChange {
  final String id;
  final String commandId;
  final String plantId;
  final String routineId;
  final String careLabel;
  final ScheduleChangeKind kind;
  final LocalDate changeDate;
  final DateTime changedAt;
  final String recordedZone;
  final RoutineHeadValues before;
  final RoutineHeadValues after;
  ScheduleChange._(
    this.id,
    this.commandId,
    this.kind,
    RoutineCore old,
    RoutineCore next,
    CareClock clock,
  ) : plantId = old.plantId,
      routineId = old.id,
      careLabel = old.careLabel,
      changeDate = clock.today,
      changedAt = clock.instant,
      recordedZone = clock.zone,
      before = RoutineHeadValues._(old),
      after = RoutineHeadValues._(next);
}

/// Consistent immutable read; callers cannot patch saved records directly.
final class CollectionSnapshot {
  final String datasetId;
  final int revision;
  final Map<String, PlantCore> plants;
  final Map<String, RoutineCore> routines;
  final Map<String, StandardCareKind> careKinds;
  final Map<String, PlantDraft> drafts;
  final Map<String, ScheduleChange> scheduleChanges;

  /// Fake reminder invalidation only; no OS notification is scheduled.
  final int reminderGeneration;
  CollectionSnapshot._(
    this.datasetId,
    this.revision,
    Map<String, PlantCore> plants,
    Map<String, RoutineCore> routines,
    Map<String, StandardCareKind> careKinds,
    Map<String, PlantDraft> drafts,
    this.reminderGeneration, [
    Map<String, ScheduleChange> scheduleChanges = const {},
  ]) : plants = Map.unmodifiable(plants),
       routines = Map.unmodifiable(routines),
       careKinds = Map.unmodifiable(careKinds),
       drafts = Map.unmodifiable(drafts),
       scheduleChanges = Map.unmodifiable(scheduleChanges);

  List<PlantCore> get activePlants =>
      List.unmodifiable(plants.values.where((p) => !p.archived));
  List<PlantCore> get archivedPlants =>
      List.unmodifiable(plants.values.where((p) => p.archived));

  /// Eligibility projection only, not the full paginated Today/reminder API.
  List<RoutineCore> get eligibleRoutines {
    final result = routines.values
        .where(
          (r) =>
              !plants[r.plantId]!.archived &&
              !r.archived &&
              r.status == RoutineStatus.active,
        )
        .toList();
    result.sort((a, b) {
      final order = a.nextCheck.compareTo(b.nextCheck);
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return List.unmodifiable(result);
  }
}

final class PlantEditor {
  final PlantDraft? draft;
  final CustomPlantFields initialFields;
  final int? plantRevision;
  final int activeCount;
  final int? activeLimit;
  bool get canAdd => activeLimit == null || activeCount < activeLimit!;
  const PlantEditor._(
    this.draft,
    this.initialFields,
    this.plantRevision,
    this.activeCount,
    this.activeLimit,
  );
}

final class CommandSuccess {
  final String commandId;
  final String datasetId;
  final int collectionRevision;
  final String? primaryId;
  final String? primaryType;
  final bool replayed;
  final List<String> resourceIds;
  final Map<String, int> newRevisions;
  final List<String> notices;
  final UndoOffer? undo;
  CommandSuccess._(
    this.commandId,
    this.datasetId,
    this.collectionRevision,
    this.primaryId,
    this.primaryType,
    this.replayed,
    Iterable<String> resourceIds,
    Map<String, int> newRevisions,
    Iterable<String> notices, [
    this.undo,
  ]) : resourceIds = List.unmodifiable(resourceIds.toList()..sort()),
       newRevisions = Map.unmodifiable(newRevisions),
       notices = List.unmodifiable(notices);
  CommandSuccess _replay() => CommandSuccess._(
    commandId,
    datasetId,
    collectionRevision,
    primaryId,
    primaryType,
    true,
    resourceIds,
    newRevisions,
    notices,
  );
}

final class UndoOffer {
  final String commandId;
  final int expiresInMilliseconds;
  const UndoOffer._(this.commandId, this.expiresInMilliseconds);
}

/// Rejection is only used when this synchronous harness knows no commit occurred.
final class CommandRejected extends DomainException {
  final Map<String, String> fields;
  bool get committed => false;
  CommandRejected(super.code, [Map<String, String> fields = const {}])
    : fields = Map.unmodifiable(fields);
}

/// A lost reply makes no assertion about whether a commit occurred. Resolve the
/// original command ID against receipts before retrying or abandoning it.
final class UnknownCommandOutcome implements Exception {
  final String commandId;
  const UnknownCommandOutcome(this.commandId);
}

final class RecoveryUnavailable implements Exception {
  const RecoveryUnavailable();
}

final class CommandResolution {
  final CommandSuccess? result;
  bool get committed => result != null;
  const CommandResolution._(this.result);
}

final class ClockReading {
  final CareClock care;

  /// Monotonic elapsed time within the caller's current process session.
  final Duration elapsed;
  const ClockReading(this.care, this.elapsed);
}

enum PreviewGate { allowed, activeLimit }

final class PreviewRow {
  final String plantId;
  final String plantName;
  final String? routineId;
  final LocalDate? oldNextCheck;
  final LocalDate? newNextCheck;
  final StandardCareKind? careKind;
  final String? careLabel;
  const PreviewRow._(
    this.plantId,
    this.plantName,
    this.routineId,
    this.oldNextCheck,
    this.newNextCheck, {
    this.careKind,
    this.careLabel,
  });
}

final class CommandEffects {
  final List<PreviewRow> rows;
  final bool historyOnly;
  final int plants;
  final int routines;
  final int events;
  final int corrections;
  final int scheduleChanges;
  final int drafts;
  final PreviewGate gate;
  CommandEffects._(
    Iterable<PreviewRow> rows, {
    this.historyOnly = false,
    this.plants = 0,
    this.routines = 0,
    this.events = 0,
    this.corrections = 0,
    this.scheduleChanges = 0,
    this.drafts = 0,
    this.gate = PreviewGate.allowed,
  }) : rows = List.unmodifiable(rows);
}

final class FrozenCommand {
  final String datasetId;
  final String commandId;
  final CoreCommand command;
  final String payloadHash;
  final List<String> allocatedIds;
  FrozenCommand._(
    this.datasetId,
    this.commandId,
    this.command,
    this.payloadHash,
    Iterable<String> allocatedIds,
  ) : allocatedIds = List.unmodifiable(allocatedIds);
}

final class PreparedCommand {
  final FrozenCommand intent;
  final String previewToken;
  final LocalDate today;
  final int capabilityRevision;
  final CommandEffects effects;
  final DateTime expiresAt;
  String get confirmationKey => intent.command is DeletePlant
      ? 'confirm.DeletePlant.permanent'
      : 'confirm.${intent.command.type}';
  const PreparedCommand._(
    this.intent,
    this.previewToken,
    this.today,
    this.capabilityRevision,
    this.effects,
    this.expiresAt,
  );
}
