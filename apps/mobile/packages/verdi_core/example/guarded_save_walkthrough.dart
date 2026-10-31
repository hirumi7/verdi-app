import 'dart:io';

import 'package:verdi_core/verdi_core.dart';

String id(int n) => '00000000-0000-4000-8000-${n.toString().padLeft(12, '0')}';

void main() {
  // Synthetic memory-only adapter. Restart means a new coordinator sharing this
  // live store, not process death or any proof of disk durability.
  var sequence = 100;
  final dataset = id(1);
  final store = MemoryCoreStore(
    datasetId: dataset,
    nextId: () => id(sequence++),
  );
  ClockReading clock() => ClockReading(
    CareClock(
      LocalDate(2026, 10, 25),
      DateTime.utc(2026, 10, 25, 2),
      'Asia/Jakarta',
    ),
    Duration.zero,
  );
  var coordinator = MemoryOperationCoordinator(store, clock: clock);

  final write = SaveDraft(
    draftId: id(2),
    expectedRevision: null,
    mode: DraftMode.add,
    fields: CustomPlantFields(
      name: 'Synthetic fern',
      speciesName: 'Example species',
      routines: [
        const RoutineInput(
          kind: StandardCareKind.water,
          count: '1',
          unit: IntervalUnit.week,
          seedKind: SeedKind.known,
          date: '2026-10-20',
        ),
      ],
    ),
  );
  final frozen = coordinator.freeze(datasetId: dataset, command: write);
  coordinator.execute(
    datasetId: dataset,
    commandId: frozen.commandId,
    command: write,
  );
  final editor = coordinator.getPlantEditor(datasetId: dataset);
  stdout.writeln('Draft acknowledged at revision ${editor.draft!.revision}.');
  final preview = coordinator.prepare(
    datasetId: dataset,
    command: SavePlant(
      draftId: editor.draft!.id,
      draftRevision: editor.draft!.revision,
    ),
  );
  stdout.writeln(
    'Preview next check: ${preview.effects.rows.single.newNextCheck}.',
  );

  store.nextFault = SimulatedFault.afterCommitReplyLost;
  try {
    coordinator.execute(
      datasetId: dataset,
      commandId: preview.intent.commandId,
      command: preview.intent.command,
      previewToken: preview.previewToken,
    );
  } on UnknownCommandOutcome {
    stdout.writeln('Reply lost; resolving the original command before retry.');
  }
  coordinator = MemoryOperationCoordinator(store, clock: clock);
  final pending = coordinator.listPendingCommands(datasetId: dataset).single;
  final resolved = coordinator.resolvePendingCommand(
    datasetId: dataset,
    commandId: pending.commandId,
  );
  if (!resolved.committed)
    throw StateError('Expected injected post-commit failure');
  final replay = coordinator.execute(
    datasetId: dataset,
    commandId: pending.commandId,
    command: pending.command,
  );
  final collection = coordinator.readCollection(datasetId: dataset);
  stdout.writeln(
    'Recovered plant: ${resolved.result!.primaryId}. Retry replayed: ${replay.replayed}.',
  );
  stdout.writeln(
    'Plants: ${collection.plants.length}; care events: '
    '${collection.routines.values.single.events.length}; drafts: ${collection.drafts.length}.',
  );
}
