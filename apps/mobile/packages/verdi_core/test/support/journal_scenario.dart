import 'package:verdi_core/verdi_core.dart';
import 'storage_scenario.dart';

StorageScenario journalScenario() {
  final s = StorageScenario();
  s.run(
    SaveDraft(
      draftId: fixtureId(3),
      expectedRevision: null,
      mode: DraftMode.add,
      fields: CustomPlantFields(name: 'Fern', speciesName: 'Custom fern'),
    ),
  );
  final plant = s
      .run(SavePlant(draftId: fixtureId(3), draftRevision: 1))
      .candidate
      .plants
      .values
      .single;
  final add = fixtureId(400), edit = fixtureId(401);
  s.run(
    SaveJournalDraft(
      draftId: add,
      expectedRevision: null,
      plantId: plant.id,
      fields: JournalFields(text: 'First frond', entryDate: '2026-10-20'),
    ),
  );
  s.run(
    SaveJournalDraft(
      draftId: add,
      expectedRevision: 1,
      plantId: plant.id,
      fields: JournalFields(text: 'First two fronds', entryDate: '2026-10-20'),
    ),
  );
  final entry = s
      .run(SaveJournalEntry(add, 2))
      .candidate
      .journalEntries
      .values
      .single;
  s.run(
    SaveJournalDraft(
      draftId: edit,
      expectedRevision: null,
      plantId: plant.id,
      entryId: entry.id,
      baseEntryRevision: entry.revision,
      fields: JournalFields(
        text: 'Corrected observation',
        entryDate: '2026-10-19',
      ),
    ),
  );
  s.run(SaveJournalEntry(edit, 1));
  final finalEntry = s.projection.snapshot.journalEntries[entry.id]!;
  final pending = fixtureId(402);
  s.run(
    SaveJournalDraft(
      draftId: pending,
      expectedRevision: null,
      plantId: plant.id,
      entryId: entry.id,
      baseEntryRevision: finalEntry.revision,
      fields: JournalFields(
        text: String.fromCharCode(0xd800),
        entryDate: 'invalid',
      ),
    ),
  );
  s.run(RebaseJournalDraft(pending, 1, finalEntry.revision));
  s.run(DeleteJournalEntry(entry.id, finalEntry.revision));
  s.run(
    SaveJournalDraft(
      draftId: fixtureId(403),
      expectedRevision: null,
      plantId: plant.id,
      fields: JournalFields(text: 'Discard me', entryDate: '2026-10-31'),
    ),
  );
  s.run(DiscardJournalDraft(fixtureId(403), 1, confirmed: true));
  s.run(ArchivePlant(plantId: plant.id, plantRevision: plant.revision));
  s.run(DeletePlant(plantId: plant.id, plantRevision: plant.revision + 1));
  return s;
}
