part of 'collection.dart';

MediaCommand? _storedMediaCommand(String type, Map<String, Object?> p) {
  String id(String key) => p[key] as String;
  int rev(String key) => p[key] as int;
  final ready = (p['readyPhotoIds'] as List?)?.cast<String>() ?? <String>[];
  return switch (type) {
    'SaveJournalDraft' => SaveJournalDraft(
      draftId: id('draftId'),
      expectedRevision: p['expectedRevision'] as int?,
      plantId: id('plantId'),
      entryId: p['entryId'] as String?,
      baseEntryRevision: p['baseEntryRevision'] as int?,
      fields: JournalFields.fromJson(p['rawFields']),
      readyPhotoIds: ready,
    ),
    'SaveMediaDraft' => SaveMediaDraft(
      draftId: id('draftId'),
      expectedRevision: p['expectedRevision'] as int?,
      plantId: id('plantId'),
      photoId: id('photoId'),
      basePhotoRevision: rev('basePhotoRevision'),
      readyPhotoIds: ready,
    ),
    'SaveJournalEntry' => SaveJournalEntry(id('draftId'), rev('draftRevision')),
    'DiscardJournalDraft' => DiscardJournalDraft(
      id('draftId'),
      rev('draftRevision'),
      confirmed: p['confirmed'] as bool,
    ),
    'DiscardMediaDraft' => DiscardMediaDraft(
      id('draftId'),
      rev('draftRevision'),
      confirmed: p['confirmed'] as bool,
    ),
    'RebaseJournalDraft' => RebaseJournalDraft(
      id('draftId'),
      rev('draftRevision'),
      rev('targetRevision'),
    ),
    'RebaseMediaDraft' => RebaseMediaDraft(
      id('draftId'),
      rev('draftRevision'),
      rev('targetRevision'),
    ),
    'DeleteJournalEntry' => DeleteJournalEntry(
      id('entryId'),
      rev('entryRevision'),
    ),
    'DeletePhoto' => DeletePhoto(id('photoId'), rev('photoRevision')),
    'UpdatePhotoObservation' => UpdatePhotoObservation(
      id('photoId'),
      rev('photoRevision'),
      LocalDate.parse(id('observedDate')),
    ),
    'ReplacePhoto' => ReplacePhoto(
      id('photoId'),
      rev('photoRevision'),
      preparationId: id('preparationId'),
      draftId: id('draftId'),
      draftRevision: rev('draftRevision'),
    ),
    _ => null,
  };
}

final class _HydratedMedia {
  final entries = <String, JournalEntry>{},
      drafts = <String, JournalDraft>{},
      media = <String, MediaDraft>{},
      photos = <String, PlantPhoto>{},
      covers = <String, String>{};
  _HydratedMedia(
    Map<String, List<List<Object?>>> rows,
    Map<String, PlantCore> plants,
    Map<String, PlantDraft> plantDrafts,
  ) {
    List<String> ids(Object? value) {
      final result = _list(jsonDecode(value as String)).cast<String>();
      _photoIds(result);
      return result;
    }

    for (final r in rows['journal_entries']!) {
      _revision(r[2] as int);
      final entry = JournalEntry(
        r[0] as String,
        r[1] as String,
        r[2] as int,
        LocalDate.parse(r[3] as String),
        r[4] as String,
        ids(r[5]),
        CareStorage.instant(r[6]),
        CareStorage.instant(r[7]),
      );
      if (!plants.containsKey(entry.plantId) ||
          !_validUnicode(entry.text) ||
          entry.text.characters.length > 2000 ||
          (entry.text.isEmpty && entry.photoIds.isEmpty))
        throw CommandRejected('STORAGE_INVALID');
      entries[entry.id] = entry;
    }
    for (final r in rows['journal_drafts']!) {
      _revision(r[1] as int);
      final d = JournalDraft(
        r[0] as String,
        r[1] as int,
        r[2] as String,
        r[3] as String?,
        r[4] as int?,
        JournalFields.fromJson(jsonDecode(r[5] as String)),
        ids(r[6]),
        CareStorage.instant(r[7]),
        CareStorage.instant(r[8]),
      );
      _validateMedia(
        SaveJournalDraft(
          draftId: d.id,
          expectedRevision: d.revision,
          plantId: d.plantId,
          entryId: d.entryId,
          baseEntryRevision: d.baseEntryRevision,
          fields: d.fields,
          readyPhotoIds: d.readyPhotoIds,
        ),
      );
      if (!plants.containsKey(d.plantId) ||
          (d.entryId != null && entries[d.entryId]?.plantId != d.plantId) ||
          drafts.values.any(
            (o) => o.plantId == d.plantId && o.entryId == d.entryId,
          ))
        throw CommandRejected('STORAGE_INVALID');
      drafts[d.id] = d;
    }
    for (final r in rows['media_drafts']!) {
      _revision(r[1] as int);
      _revision(r[4] as int);
      final d = MediaDraft(
        r[0] as String,
        r[1] as int,
        r[2] as String,
        r[3] as String,
        r[4] as int,
        ids(r[5]),
        CareStorage.instant(r[6]),
        CareStorage.instant(r[7]),
      );
      if (!plants.containsKey(d.plantId) ||
          media.values.any((o) => o.photoId == d.photoId))
        throw CommandRejected('STORAGE_INVALID');
      media[d.id] = d;
    }
    for (final r in rows['photos']!) {
      _revision(r[3] as int);
      final p = PlantPhoto(
        r[0] as String,
        r[1] as String?,
        r[2] as String?,
        r[3] as int,
        r[4] as String,
        r[5] as String,
        r[6] as int,
        r[7] as String,
        r[8] as int,
        r[9] as int,
        LocalDate.parse(r[10] as String),
        r[11] as String,
        r[12] as String?,
        CareStorage.instant(r[13]),
      );
      if ((p.plantId == null) == (p.draftId == null) ||
          (p.plantId != null && !plants.containsKey(p.plantId)) ||
          (p.draftId != null &&
              !plantDrafts.containsKey(p.draftId) &&
              !drafts.containsKey(p.draftId) &&
              !media.containsKey(p.draftId)) ||
          !RegExp(
            r'^media/[0-9a-f-]{36}/[0-9a-f]{64}\.(jpg|png|heic)$',
          ).hasMatch(p.contentPath) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(p.sha256) ||
          p.byteCount < 1 ||
          p.byteCount > 64 * 1024 * 1024 ||
          p.width < 1 ||
          p.height < 1 ||
          p.width * p.height > 100000000 ||
          !['image/jpeg', 'image/png', 'image/heic'].contains(p.mime) ||
          !['camera', 'library'].contains(p.sourceKind))
        throw CommandRejected('STORAGE_INVALID');
      photos[p.id] = p;
    }
    void refs(String owner, String? draft, Iterable<String> selected) {
      for (final id in selected) {
        final p = photos[id];
        if (p == null ||
            !(p.plantId == owner || (draft != null && p.draftId == draft)))
          throw CommandRejected('STORAGE_INVALID');
      }
    }

    void ready(String draft, Iterable<String> ready) {
      final owned = photos.values
          .where((p) => p.draftId == draft)
          .map((p) => p.id)
          .toSet();
      if (owned.length != ready.length || !owned.containsAll(ready))
        throw CommandRejected('STORAGE_INVALID');
    }

    for (final e in entries.values) {
      refs(e.plantId, null, e.photoIds);
    }
    for (final d in drafts.values) {
      refs(d.plantId, d.id, d.fields.selectedPhotoIds);
      ready(d.id, d.readyPhotoIds);
    }
    for (final d in media.values) {
      if (photos[d.photoId]?.plantId != d.plantId)
        throw CommandRejected('STORAGE_INVALID');
      ready(d.id, d.readyPhotoIds);
    }
    for (final d in plantDrafts.values) {
      if (d.fields.coverPhotoId != null) {
        final p = photos[d.fields.coverPhotoId];
        if (p == null ||
            !(p.draftId == d.id ||
                (d.plantId != null && p.plantId == d.plantId)))
          throw CommandRejected('STORAGE_INVALID');
      }
      ready(d.id, d.fields.readyPhotoIds);
    }
    for (final r in rows['plant_covers']!) {
      final plant = r[0] as String, photo = r[1] as String;
      if (!plants.containsKey(plant) || photos[photo]?.plantId != plant)
        throw CommandRejected('STORAGE_INVALID');
      covers[plant] = photo;
    }
  }
}
