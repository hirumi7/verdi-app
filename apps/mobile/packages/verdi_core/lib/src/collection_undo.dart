part of 'collection.dart';

final class _UndoMember {
  final String plantId;
  final String routineId;
  final RoutineUndoValues before;
  final int postRevision;
  final List<String> eventIds;
  _UndoMember(RoutineCore old, RoutineCore next)
    : plantId = old.plantId,
      routineId = old.id,
      before = RoutineUndoValues(old),
      postRevision = next.revision,
      eventIds = List.unmodifiable(
        next.events
            .where((e) => !old.events.any((prior) => prior.id == e.id))
            .map((e) => e.id),
      );
}

final class _UndoGrant {
  final String datasetId;
  final Duration acknowledged;
  Duration lastObserved;
  final List<_UndoMember> members;
  _UndoGrant(this.datasetId, this.acknowledged, Iterable<_UndoMember> members)
    : lastObserved = acknowledged,
      members = List.unmodifiable(members);
}

RoutineCore _targetRoutine(CollectionSnapshot current, CareTarget target) {
  final plant = current.plants[target.plantId];
  final routine = current.routines[target.routineId];
  if (plant == null || routine == null) {
    throw CommandRejected('NOT_FOUND', {target.routineId: 'NOT_FOUND'});
  }
  if (routine.plantId != plant.id || routine.headId != target.headId) {
    throw CommandRejected('FIELD_INVALID', {target.routineId: 'FIELD_INVALID'});
  }
  if (plant.revision != target.plantRevision ||
      routine.revision != target.routineRevision ||
      routine.headRevision != target.headRevision) {
    throw CommandRejected('STALE_TARGET', {target.routineId: 'STALE_TARGET'});
  }
  if (plant.archived ||
      routine.archived ||
      routine.status != RoutineStatus.active) {
    throw CommandRejected('NOT_ELIGIBLE', {target.routineId: 'NOT_ELIGIBLE'});
  }
  return routine;
}

List<_UndoMember> _captureUndo(
  CoreCommand command,
  CollectionSnapshot before,
  CollectionSnapshot after,
) {
  final ids = switch (command) {
    BulkComplete c => c.targets.map((t) => t.routineId),
    CompleteCurrent c => [c.target.routineId],
    CheckNotNeeded c => [c.target.routineId],
    Skip c => [c.target.routineId],
    Snooze c => [c.target.routineId],
    _ => <String>[],
  };
  return [
    for (final id in ids)
      _UndoMember(before.routines[id]!, after.routines[id]!),
  ];
}

extension on MemoryOperationCoordinator {
  _UndoGrant _undoGrant(String commandId) {
    final grant = _undoGrants[commandId];
    final current = _store._state;
    if (grant == null ||
        grant.datasetId != current.collection.datasetId ||
        current.undoneCommands.contains(commandId)) {
      throw CommandRejected('UNDO_UNAVAILABLE');
    }
    final now = _clock().elapsed;
    if (now < grant.lastObserved) {
      _undoGrants.remove(commandId);
      throw CommandRejected('UNDO_UNAVAILABLE');
    }
    grant.lastObserved = now;
    if (now - grant.acknowledged >= const Duration(milliseconds: 8000)) {
      _undoGrants.remove(commandId);
      throw CommandRejected('UNDO_EXPIRED');
    }
    for (final member in grant.members) {
      if (current.collection.routines[member.routineId]?.revision !=
          member.postRevision) {
        throw CommandRejected('UNDO_CHANGED', {
          member.routineId: 'UNDO_CHANGED',
        });
      }
    }
    return grant;
  }
}
