import 'dart:convert';

import 'package:characters/characters.dart';

import 'calendar.dart';
import 'care.dart';
import 'command_encoding.dart';
import 'errors.dart';

part 'collection_models.dart';
part 'collection_commands.dart';
part 'collection_planner.dart';
part 'collection_undo.dart';
part 'collection_reads.dart';
part 'collection_storage.dart';
part 'collection_storage_commands.dart';

const _maxRevision = 9007199254740991;
const _maxPayloadBytes = 1024 * 1024;
final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

void _id(String id) {
  if (!_uuid.hasMatch(id)) throw CommandRejected('FIELD_INVALID');
}

void _revision(int revision) {
  if (revision < 1 || revision > _maxRevision)
    throw CommandRejected('FIELD_INVALID');
}

int _nextRevision(int revision) {
  _revision(revision);
  if (revision == _maxRevision) throw CommandRejected('FIELD_INVALID');
  return revision + 1;
}

enum SimulatedFault { none, beforeCommit, afterCommitReplyLost, receiptRead }

final class _Receipt {
  final String hash;
  final CommandSuccess result;
  final DateTime committedAt;
  const _Receipt(this.hash, this.result, this.committedAt);
}

final class _State {
  final CollectionSnapshot collection;
  final Map<String, _Receipt> receipts;
  final Set<String> usedDraftIds;
  final Set<String> undoneCommands;
  _State(
    this.collection,
    Map<String, _Receipt> receipts, [
    Set<String> usedDraftIds = const {},
    Set<String> undoneCommands = const {},
  ]) : receipts = Map.unmodifiable(receipts),
       usedDraftIds = Set.unmodifiable(usedDraftIds),
       undoneCommands = Set.unmodifiable(undoneCommands);
}

/// Test persistence only. Keep this object to simulate a coordinator restart.
/// Dropping it loses all content: no files, SQL, process durability or purchases.
/// Every operation is synchronous on one isolate. The single state-pointer swap
/// models atomic commit; production needs the separately reviewed native guards.
final class MemoryCoreStore {
  final String Function() _nextId;
  final Set<String> _reservedIds = {};
  final Set<String> _draftIds = {};
  final Map<String, FrozenCommand> _intents = {};
  final Set<String> _resolved = {};
  final Set<String> _abandoned = {};
  late _State _state;
  bool _pro = false;
  int _capabilityRevision = 1;
  SimulatedFault nextFault = SimulatedFault.none;

  MemoryCoreStore({
    required String datasetId,
    required String Function() nextId,
  }) : _nextId = nextId {
    _id(datasetId);
    _reservedIds.add(datasetId);
    _state = _State(CollectionSnapshot._(datasetId, 1, {}, {}, {}, {}, 0), {});
  }

  String _allocate() {
    final value = _nextId();
    _id(value);
    if (!_reservedIds.add(value)) throw CommandRejected('FIELD_INVALID');
    return value;
  }

  /// Synthetic capability adapter only. Not evidence granting real Pro access.
  void setProForTest(bool pro) {
    if (_pro != pro) {
      _capabilityRevision = _nextRevision(_capabilityRevision);
      _pro = pro;
    }
  }

  /// Explicit generation-change simulation, not an import/reset API for a UI.
  void replaceWithEmptyDatasetForTest(String datasetId) {
    _id(datasetId);
    if (!_reservedIds.add(datasetId)) throw CommandRejected('FIELD_INVALID');
    _state = _State(CollectionSnapshot._(datasetId, 1, {}, {}, {}, {}, 0), {});
  }
}

final class _Preview {
  final PreparedCommand value;
  final String binding;
  final Duration created;
  const _Preview(this.value, this.binding, this.created);
}

final class MemoryOperationCoordinator {
  final MemoryCoreStore _store;
  final ClockReading Function() _clock;
  final Map<String, _Preview> _previews = {};
  final Map<String, _UndoGrant> _undoGrants = {};

  /// Call whenever foreground monotonic continuity cannot be established.
  void invalidateUndoOffers() => _undoGrants.clear();

  MemoryOperationCoordinator(
    this._store, {
    required ClockReading Function() clock,
  }) : _clock = clock;

  void _dataset(String datasetId) {
    _id(datasetId);
    if (datasetId != _store._state.collection.datasetId) {
      throw CommandRejected('DATASET_CHANGED');
    }
  }

  CollectionSnapshot readCollection({required String datasetId}) {
    _dataset(datasetId);
    return _store._state.collection;
  }

  ScheduleChange getScheduleChange({
    required String datasetId,
    required String changeId,
  }) {
    _id(changeId);
    final change = readCollection(
      datasetId: datasetId,
    ).scheduleChanges[changeId];
    if (change == null) throw CommandRejected('NOT_FOUND');
    return change;
  }

  PlantEditor getPlantEditor({required String datasetId, String? plantId}) {
    final collection = readCollection(datasetId: datasetId);
    if (plantId != null) _id(plantId);
    final plant = plantId == null ? null : collection.plants[plantId];
    if (plantId != null && plant == null) throw CommandRejected('NOT_FOUND');
    final drafts = collection.drafts.values.where((d) => d.plantId == plantId);
    final draft = drafts.isEmpty ? null : drafts.single;
    final fields =
        draft?.fields ??
        (plant == null
            ? CustomPlantFields()
            : CustomPlantFields(
                name: plant.name,
                location: plant.location,
                notes: plant.notes,
                speciesName: plant.speciesName,
                light: plant.light,
                toxicity: plant.toxicity,
                baseRoutineRevisions: {
                  for (final r in collection.routines.values.where(
                    (r) =>
                        r.plantId == plantId &&
                        r.status != RoutineStatus.retired,
                  ))
                    r.id: r.revision,
                },
              ));
    return PlantEditor._(
      draft,
      fields,
      plant?.revision,
      collection.activePlants.length,
      _store._pro ? null : 5,
    );
  }

  /// Persist the typed immutable intent in the fake installation store before
  /// any collection write. Passing an ID means resolving an existing intent.
  FrozenCommand freeze({
    required String datasetId,
    required CoreCommand command,
    String? commandId,
  }) {
    _dataset(datasetId);
    _validateShape(command);
    final hash = command.payloadHash;
    if (commandId != null) {
      _id(commandId);
      final existing = _store._intents[commandId];
      if (existing == null) throw CommandRejected('NOT_FOUND');
      if (existing.datasetId != datasetId)
        throw CommandRejected('DATASET_CHANGED');
      if (existing.payloadHash != hash)
        throw CommandRejected('COMMAND_ID_REUSED');
      if (_store._abandoned.contains(commandId))
        throw CommandRejected('NOT_ELIGIBLE');
      return existing;
    }
    if (command is SaveDraft && !_store._draftIds.contains(command.draftId)) {
      if (!_store._reservedIds.add(command.draftId))
        throw CommandRejected('FIELD_INVALID');
      _store._draftIds.add(command.draftId);
    }
    final id = _store._allocate();
    var count = 0;
    if (command is SavePlant) {
      final draft = _draft(command.draftId, command.draftRevision);
      if (draft.mode == DraftMode.add) {
        count =
            1 +
            draft.fields.routines.fold<int>(
              0,
              (n, r) => n + 2 + (r.seedKind == SeedKind.known ? 1 : 0),
            );
      }
    } else if (command is RoutineCommand) {
      count = 1;
    } else if (command is BulkComplete) {
      count = command.targets.length;
    } else if (command is Undo) {
      count = _undoGrant(
        command.originalCommandId,
      ).members.fold<int>(0, (n, m) => n + m.eventIds.length + 1);
    } else if (command is PlantLifecycleCommand && command is! DeletePlant) {
      count = _store._state.collection.routines.values
          .where((r) => r.plantId == command.plantId)
          .length;
    }
    final intent = FrozenCommand._(
      datasetId,
      id,
      command,
      hash,
      List.generate(count, (_) => _store._allocate()),
    );
    _store._intents[id] = intent;
    return intent;
  }

  PreparedCommand prepare({
    required String datasetId,
    required CoreCommand command,
    String? commandId,
  }) {
    final intent = freeze(
      datasetId: datasetId,
      command: command,
      commandId: commandId,
    );
    final reading = _clock();
    late _Plan plan;
    try {
      plan = _plan(intent, reading.care);
    } on CommandRejected {
      // Invalid first-time preparation does not leave an unreachable intent.
      // An already frozen intent stays recoverable if its re-preview fails.
      if (commandId == null) _store._intents.remove(intent.commandId);
      rethrow;
    }
    final token = _store._allocate();
    final value = PreparedCommand._(
      intent,
      token,
      reading.care.today,
      _store._capabilityRevision,
      plan.effects,
      reading.care.instant.add(const Duration(minutes: 10)),
    );
    _previews[token] = _Preview(value, plan.binding, reading.elapsed);
    return value;
  }

  CommandSuccess execute({
    required String datasetId,
    required String commandId,
    required CoreCommand command,
    String? previewToken,
  }) {
    _dataset(datasetId);
    _id(commandId);
    _validateShape(command);
    final hash = command.payloadHash;
    final receipt = _store._state.receipts[commandId];
    // A completed retry must succeed even after its draft is consumed, revisions
    // move, access changes or the old session's confirmation expires.
    if (receipt != null) {
      if (receipt.hash != hash) throw CommandRejected('COMMAND_ID_REUSED');
      _store._resolved.add(commandId);
      return receipt.result._replay();
    }
    final intent = freeze(
      datasetId: datasetId,
      command: command,
      commandId: commandId,
    );
    final reading = _clock();
    if (command._needsPreview) {
      final preview = _previews[previewToken];
      if (preview == null ||
          preview.value.intent.commandId != commandId ||
          preview.value.intent.payloadHash != hash ||
          preview.value.today != reading.care.today ||
          reading.elapsed < preview.created ||
          reading.elapsed - preview.created >= const Duration(minutes: 10)) {
        throw CommandRejected('PREVIEW_STALE');
      }
    }
    final plan = _plan(intent, reading.care);
    if (command._needsPreview &&
        _previews[previewToken]!.binding != plan.binding) {
      throw CommandRejected('PREVIEW_STALE');
    }
    if (plan.effects.gate != PreviewGate.allowed)
      throw CommandRejected('ACTIVE_LIMIT');
    final success = CommandSuccess._(
      commandId,
      datasetId,
      plan.next.revision,
      plan.primaryId,
      plan.primaryType,
      false,
      plan.resourceIds,
      plan.revisions,
      plan.notices,
    );
    final next = _State(
      plan.next,
      {
        ..._store._state.receipts,
        commandId: _Receipt(hash, success, reading.care.instant),
      },
      {
        ..._store._state.usedDraftIds,
        if (command is SaveDraft) command.draftId,
      },
      {
        ..._store._state.undoneCommands,
        if (command is Undo) command.originalCommandId,
      },
    );
    final scrub = <String>{};
    if (command is DeletePlant) {
      final ownedIds = {...plan.resourceIds};
      // Earlier SavePlant receipts retain consumed add/edit draft IDs without
      // retaining their text. Include those to scrub frozen raw draft payloads.
      for (final receipt in _store._state.receipts.values) {
        if (receipt.result.primaryType == 'plant' &&
            receipt.result.primaryId == command.plantId) {
          ownedIds.addAll(receipt.result.resourceIds);
        }
      }
      for (final pending in _store._intents.values) {
        if (pending.commandId == commandId || pending.datasetId != datasetId)
          continue;
        final related = switch (pending.command) {
          SaveDraft c =>
            c.plantId == command.plantId || ownedIds.contains(c.draftId),
          SavePlant c => ownedIds.contains(c.draftId),
          DiscardDraft c => ownedIds.contains(c.draftId),
          RoutineCommand c => c.target.plantId == command.plantId,
          PlantLifecycleCommand c => c.plantId == command.plantId,
          BulkComplete c => c.targets.any((t) => t.plantId == command.plantId),
          Undo c =>
            _undoGrants[c.originalCommandId]?.members.any(
                  (m) => m.plantId == command.plantId,
                ) ??
                false,
        };
        if (related) scrub.add(pending.commandId);
      }
    }
    // Fault after all candidate rows/receipt have been constructed, before the
    // sole publication point: no draft, event, head or receipt can leak out.
    if (_store.nextFault == SimulatedFault.beforeCommit) {
      _store.nextFault = SimulatedFault.none;
      throw CommandRejected('STORAGE_UNAVAILABLE');
    }
    // Sample the session clock again at the publication boundary. A queued Undo
    // must not pass simply because its first check was just before expiry.
    if (command is Undo) _undoGrant(command.originalCommandId);
    final undoMembers = _captureUndo(
      command,
      _store._state.collection,
      plan.next,
    );
    _store._state = next;
    // Synchronous, non-fallible cleanup before the reply/fault boundary. Old
    // receipts contain only IDs/revisions/outcome; they still resolve lost replies.
    // Callers may hold old snapshots: this is not a secure memory-erasure claim.
    _store._intents.removeWhere((id, _) => scrub.contains(id));
    _store._resolved.addAll(scrub);
    _previews.removeWhere((_, p) => scrub.contains(p.value.intent.commandId));
    if (command is DeletePlant) {
      _undoGrants.removeWhere(
        (_, g) => g.members.any((m) => m.plantId == command.plantId),
      );
    }
    if (command is Undo) _undoGrants.remove(command.originalCommandId);
    if (_store.nextFault == SimulatedFault.afterCommitReplyLost) {
      _store.nextFault = SimulatedFault.none;
      throw UnknownCommandOutcome(commandId);
    }
    _store._resolved.add(commandId);
    if (undoMembers.isEmpty) return success;
    final acknowledged = _clock().elapsed;
    _undoGrants[commandId] = _UndoGrant(datasetId, acknowledged, undoMembers);
    return CommandSuccess._(
      success.commandId,
      success.datasetId,
      success.collectionRevision,
      success.primaryId,
      success.primaryType,
      false,
      success.resourceIds,
      success.newRevisions,
      success.notices,
      UndoOffer._(commandId, 8000),
    );
  }

  CommandResolution getCommandResult({
    required String datasetId,
    required String commandId,
  }) {
    _dataset(datasetId);
    _id(commandId);
    if (_store.nextFault == SimulatedFault.receiptRead) {
      _store.nextFault = SimulatedFault.none;
      throw const RecoveryUnavailable();
    }
    return CommandResolution._(
      _store._state.receipts[commandId]?.result._replay(),
    );
  }

  List<FrozenCommand> listPendingCommands({required String datasetId}) {
    _dataset(datasetId);
    return List.unmodifiable(
      _store._intents.values.where(
        (intent) =>
            intent.datasetId == datasetId &&
            !_store._resolved.contains(intent.commandId) &&
            !_store._abandoned.contains(intent.commandId),
      ),
    );
  }

  FrozenCommand getPendingCommand({
    required String datasetId,
    required String commandId,
  }) {
    _dataset(datasetId);
    _id(commandId);
    final intent = _store._intents[commandId];
    if (intent == null || _store._abandoned.contains(commandId))
      throw CommandRejected('NOT_FOUND');
    if (intent.datasetId != datasetId) throw CommandRejected('DATASET_CHANGED');
    return intent;
  }

  CommandResolution resolvePendingCommand({
    required String datasetId,
    required String commandId,
  }) {
    final resolution = getCommandResult(
      datasetId: datasetId,
      commandId: commandId,
    );
    if (resolution.committed) {
      _store._resolved.add(commandId);
    } else {
      getPendingCommand(datasetId: datasetId, commandId: commandId);
    }
    return resolution;
  }

  /// Cancel the operation, not the editor. Resolution failure leaves it pending.
  CommandResolution abandonPendingCommand({
    required String datasetId,
    required String commandId,
  }) {
    final resolution = resolvePendingCommand(
      datasetId: datasetId,
      commandId: commandId,
    );
    if (!resolution.committed) {
      _store._abandoned.add(commandId);
      _store._intents.remove(commandId);
      _previews.removeWhere((_, p) => p.value.intent.commandId == commandId);
    }
    return resolution;
  }

  PlantDraft _draft(String id, int revision) {
    final draft = _store._state.collection.drafts[id];
    if (draft == null) throw CommandRejected('NOT_FOUND');
    if (draft.revision != revision) throw CommandRejected('STALE_TARGET');
    return draft;
  }
}
