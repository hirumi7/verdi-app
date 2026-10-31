part of 'collection.dart';

String _outcomeName(CareOutcome outcome) => switch (outcome) {
  CareOutcome.actualCare => 'actual_care',
  CareOutcome.checkedNotNeeded => 'checked_not_needed',
  CareOutcome.skipped => 'skipped',
};

/// Closed command set for this fake harness. Native DTO parsing is separate.
sealed class CoreCommand {
  const CoreCommand();
  String get type;
  Map<String, Object?> get _payload;
  bool get _needsPreview => true;
  String get payloadHash => commandHash(type, _payload);
}

final class SaveDraft extends CoreCommand {
  final String draftId;
  final int? expectedRevision;
  final DraftMode mode;
  final String? plantId;
  final int? basePlantRevision;
  final CustomPlantFields fields;
  const SaveDraft({
    required this.draftId,
    required this.expectedRevision,
    required this.mode,
    required this.fields,
    this.plantId,
    this.basePlantRevision,
  });
  @override
  String get type => 'SaveDraft';
  @override
  bool get _needsPreview => false;
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'expectedRevision': expectedRevision,
    'mode': mode.name,
    'plantId': plantId,
    'basePlantRevision': basePlantRevision,
    'rawFields': fields._json(),
    'photoIds': <String>[],
  };
}

final class SavePlant extends CoreCommand {
  final String draftId;
  final int draftRevision;
  const SavePlant({required this.draftId, required this.draftRevision});
  @override
  String get type => 'SavePlant';
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'draftRevision': draftRevision,
  };
}

final class DiscardDraft extends CoreCommand {
  final String draftId;
  final int draftRevision;
  final bool confirmed;
  const DiscardDraft({
    required this.draftId,
    required this.draftRevision,
    required this.confirmed,
  });
  @override
  String get type => 'DiscardDraft';
  @override
  bool get _needsPreview => false;
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'draftRevision': draftRevision,
    'confirmed': confirmed,
  };
}

final class CareTarget {
  final String plantId;
  final int plantRevision;
  final String routineId;
  final int routineRevision;
  final String headId;
  final int headRevision;
  const CareTarget({
    required this.plantId,
    required this.plantRevision,
    required this.routineId,
    required this.routineRevision,
    required this.headId,
    required this.headRevision,
  });
  Map<String, Object?> _json() => {
    'plantId': plantId,
    'plantRevision': plantRevision,
    'routineId': routineId,
    'routineRevision': routineRevision,
    'headId': headId,
    'headRevision': headRevision,
  };
}

sealed class RoutineCommand extends CoreCommand {
  final CareTarget target;
  const RoutineCommand(this.target);
}

/// Explicit selection, normalized once so selection order cannot change retries.
final class BulkComplete extends CoreCommand {
  final StandardCareKind careKind;
  final LocalDate careDate;
  final List<CareTarget> targets;
  BulkComplete({
    required this.careKind,
    required this.careDate,
    required Iterable<CareTarget> targets,
  }) : targets = List.unmodifiable(
         targets.toList()..sort((a, b) => a.routineId.compareTo(b.routineId)),
       );
  @override
  String get type => 'BulkComplete';
  @override
  Map<String, Object?> get _payload => {
    'careKind': careKind.name,
    'customTypeId': null,
    'careDate': careDate.toString(),
    'targets': targets.map((t) => t._json()).toList(),
  };
}

final class Undo extends CoreCommand {
  final String originalCommandId;
  const Undo(this.originalCommandId);
  @override
  String get type => 'Undo';
  @override
  bool get _needsPreview => false;
  @override
  Map<String, Object?> get _payload => {'originalCommandId': originalCommandId};
}

sealed class ScheduleCommand extends RoutineCommand {
  const ScheduleCommand(super.target);
}

final class SetInterval extends ScheduleCommand {
  final CareInterval interval;
  final LocalDate? firstCheckDate;
  const SetInterval(super.target, this.interval, {this.firstCheckDate});
  @override
  String get type => 'SetInterval';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'interval': {'count': interval.count, 'unit': interval.unit.name},
    'firstCheckDate': firstCheckDate?.toString(),
  };
}

final class ClearOverride extends ScheduleCommand {
  final LocalDate? firstCheckDate;
  const ClearOverride(super.target, {this.firstCheckDate});
  @override
  String get type => 'ClearOverride';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'firstCheckDate': firstCheckDate?.toString(),
  };
}

final class PauseRoutine extends ScheduleCommand {
  const PauseRoutine(super.target);
  @override
  String get type => 'PauseRoutine';
  @override
  Map<String, Object?> get _payload => {'target': target._json()};
}

final class ResumeRoutine extends ScheduleCommand {
  const ResumeRoutine(super.target);
  @override
  String get type => 'ResumeRoutine';
  @override
  Map<String, Object?> get _payload => {'target': target._json()};
}

final class RetireRoutine extends ScheduleCommand {
  const RetireRoutine(super.target);
  @override
  String get type => 'RetireRoutine';
  @override
  Map<String, Object?> get _payload => {'target': target._json()};
}

sealed class PlantLifecycleCommand extends CoreCommand {
  final String plantId;
  final int plantRevision;
  const PlantLifecycleCommand({
    required this.plantId,
    required this.plantRevision,
  });
  @override
  Map<String, Object?> get _payload => {
    'plantId': plantId,
    'plantRevision': plantRevision,
  };
}

final class ArchivePlant extends PlantLifecycleCommand {
  const ArchivePlant({required super.plantId, required super.plantRevision});
  @override
  String get type => 'ArchivePlant';
}

final class RestorePlant extends PlantLifecycleCommand {
  const RestorePlant({required super.plantId, required super.plantRevision});
  @override
  String get type => 'RestorePlant';
}

final class DeletePlant extends PlantLifecycleCommand {
  const DeletePlant({required super.plantId, required super.plantRevision});
  @override
  String get type => 'DeletePlant';
}

final class CompleteCurrent extends RoutineCommand {
  final LocalDate careDate;
  const CompleteCurrent(super.target, this.careDate);
  @override
  String get type => 'CompleteCurrent';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'careDate': careDate.toString(),
  };
}

final class AddPastCare extends RoutineCommand {
  final LocalDate careDate;
  final CareOutcome outcome;
  const AddPastCare(super.target, this.careDate, this.outcome);
  @override
  String get type => 'AddPastCare';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'careDate': careDate.toString(),
    'outcome': _outcomeName(outcome),
  };
}

final class CheckNotNeeded extends RoutineCommand {
  final LocalDate checkDate;
  final LocalDate nextDate;
  const CheckNotNeeded(super.target, this.checkDate, this.nextDate);
  @override
  String get type => 'CheckNotNeeded';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'checkDate': checkDate.toString(),
    'nextCheckDate': nextDate.toString(),
  };
}

final class Snooze extends RoutineCommand {
  final LocalDate nextDate;
  const Snooze(super.target, this.nextDate);
  @override
  String get type => 'Snooze';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'nextCheckDate': nextDate.toString(),
  };
}

final class Skip extends RoutineCommand {
  const Skip(super.target);
  @override
  String get type => 'Skip';
  @override
  Map<String, Object?> get _payload => {'target': target._json()};
}

final class CorrectEvent extends RoutineCommand {
  final String eventId;
  final int eventRevision;
  final LocalDate careDate;
  final CareOutcome outcome;
  final bool restore;
  const CorrectEvent(
    super.target, {
    required this.eventId,
    required this.eventRevision,
    required this.careDate,
    required this.outcome,
    this.restore = false,
  });
  @override
  String get type => restore ? 'RestoreEvent' : 'CorrectEvent';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'eventId': eventId,
    'eventRevision': eventRevision,
    'careDate': careDate.toString(),
    'outcome': _outcomeName(outcome),
  };
}

final class VoidEvent extends RoutineCommand {
  final String eventId;
  final int eventRevision;
  const VoidEvent(
    super.target, {
    required this.eventId,
    required this.eventRevision,
  });
  @override
  String get type => 'VoidEvent';
  @override
  Map<String, Object?> get _payload => {
    'target': target._json(),
    'eventId': eventId,
    'eventRevision': eventRevision,
  };
}
