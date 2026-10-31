part of 'collection.dart';

extension on MemoryOperationCoordinator {
  _Plan _planMedia(FrozenCommand intent, CareClock clock) {
    final c = intent.command as MediaCommand, s = _store._state.collection;
    final plantDrafts = {...s.drafts};
    final entries = {...s.journalEntries},
        drafts = {...s.journalDrafts},
        media = {...s.mediaDrafts},
        photos = {...s.photos},
        covers = {...s.covers};
    final bindings = <String, Object?>{},
        resources = <String>{},
        revisions = <String, int>{};
    String? primaryId, primaryType;
    String plantId;
    JournalDraft journal(String id, int rev) {
      final d = drafts[id];
      if (d == null) throw CommandRejected('NOT_FOUND');
      if (d.revision != rev) throw CommandRejected('STALE_TARGET');
      return d;
    }

    MediaDraft replacement(String id, int rev) {
      final d = media[id];
      if (d == null) throw CommandRejected('NOT_FOUND');
      if (d.revision != rev) throw CommandRejected('STALE_TARGET');
      return d;
    }

    void discardOwned(String id) {
      photos.removeWhere((_, p) => p.draftId == id);
    }

    void ready(String id, Iterable<String> requested) {
      final actual = photos.values
          .where((p) => p.draftId == id)
          .map((p) => p.id)
          .toSet();
      if (actual.length != requested.length || !actual.containsAll(requested))
        throw CommandRejected('DRAFT_CONFLICT');
    }

    void selected(String draft, String plant, Iterable<String> ids) {
      for (final id in ids) {
        final p = photos[id];
        if (p == null || !(p.plantId == plant || p.draftId == draft))
          throw CommandRejected('FIELD_INVALID');
      }
    }

    switch (c) {
      case SaveJournalDraft():
        plantId = c.plantId;
        final old = drafts[c.draftId];
        if (old?.revision != c.expectedRevision)
          throw CommandRejected('STALE_TARGET');
        if (old == null &&
            (_store._state.usedDraftIds.contains(c.draftId) ||
                drafts.values.any(
                  (d) => d.plantId == plantId && d.entryId == c.entryId,
                )))
          throw CommandRejected('DRAFT_CONFLICT');
        if (old != null &&
            (old.plantId != plantId ||
                old.entryId != c.entryId ||
                old.baseEntryRevision != c.baseEntryRevision))
          throw CommandRejected('DRAFT_CONFLICT');
        if (c.entryId != null && entries[c.entryId]?.plantId != plantId)
          throw CommandRejected('NOT_FOUND');
        ready(c.draftId, c.readyPhotoIds);
        selected(c.draftId, plantId, c.fields.selectedPhotoIds);
        drafts[c.draftId] = JournalDraft(
          c.draftId,
          old == null ? 1 : _nextRevision(old.revision),
          plantId,
          c.entryId,
          c.baseEntryRevision,
          c.fields,
          c.readyPhotoIds,
          old?.createdAt ?? clock.instant,
          clock.instant,
        );
        primaryId = c.draftId;
        primaryType = 'journalDraft';
      case SaveMediaDraft():
        plantId = c.plantId;
        final old = media[c.draftId], target = photos[c.photoId];
        if (target?.plantId != plantId) throw CommandRejected('NOT_FOUND');
        if (old?.revision != c.expectedRevision)
          throw CommandRejected('STALE_TARGET');
        if (old == null &&
            (_store._state.usedDraftIds.contains(c.draftId) ||
                media.values.any((d) => d.photoId == c.photoId)))
          throw CommandRejected('DRAFT_CONFLICT');
        if (old != null &&
            (old.plantId != plantId ||
                old.photoId != c.photoId ||
                old.basePhotoRevision != c.basePhotoRevision))
          throw CommandRejected('DRAFT_CONFLICT');
        ready(c.draftId, c.readyPhotoIds);
        media[c.draftId] = MediaDraft(
          c.draftId,
          old == null ? 1 : _nextRevision(old.revision),
          plantId,
          c.photoId,
          c.basePhotoRevision,
          c.readyPhotoIds,
          old?.createdAt ?? clock.instant,
          clock.instant,
        );
        primaryId = c.draftId;
        primaryType = 'mediaDraft';
      case SaveJournalEntry():
        final d = journal(c.draftId, c.draftRevision), old = entries[d.entryId];
        plantId = d.plantId;
        if (d.entryId != null && old == null)
          throw CommandRejected('NOT_FOUND');
        if (old?.revision != d.baseEntryRevision)
          throw CommandRejected('DRAFT_CONFLICT');
        final errors = <String, String>{};
        final text = _text(d.fields.text, 2000, 'text', errors);
        LocalDate? date;
        try {
          date = LocalDate.parse(d.fields.entryDate);
        } catch (_) {
          errors['entryDate'] = 'FIELD_INVALID';
        }
        if (date != null && date.compareTo(clock.today) > 0)
          errors['entryDate'] = 'FUTURE_OBSERVATION_DATE';
        if (text.isEmpty && d.fields.selectedPhotoIds.isEmpty)
          errors['entry'] = 'EMPTY_ENTRY';
        // Imported multi-photo entries can be retained; new entries attach one.
        if (old == null && d.fields.selectedPhotoIds.length > 1)
          errors['photos'] = 'FIELD_INVALID';
        if (errors.isNotEmpty) throw CommandRejected('FIELD_INVALID', errors);
        selected(d.id, plantId, d.fields.selectedPhotoIds);
        ready(d.id, d.readyPhotoIds);
        final id = old?.id ?? intent.allocatedIds.single;
        entries[id] = JournalEntry(
          id,
          plantId,
          old == null ? 1 : _nextRevision(old.revision),
          date!,
          text,
          d.fields.selectedPhotoIds,
          old?.createdAt ?? clock.instant,
          clock.instant,
        );
        for (final photo in d.fields.selectedPhotoIds) {
          if (photos[photo]!.draftId == d.id)
            photos[photo] = photos[photo]!.ownedBy(plantId);
        }
        discardOwned(d.id);
        drafts.remove(d.id);
        primaryId = id;
        primaryType = 'journal';
        bindings['draft'] = d.toRow();
        bindings['entry'] = old?.toRow();
      case DiscardJournalDraft():
        final d = journal(c.draftId, c.draftRevision);
        plantId = d.plantId;
        if (!c.confirmed) throw CommandRejected('NOT_ELIGIBLE');
        drafts.remove(d.id);
        discardOwned(d.id);
        primaryId = d.id;
        primaryType = 'journalDraft';
      case DiscardMediaDraft():
        final d = replacement(c.draftId, c.draftRevision);
        plantId = d.plantId;
        if (!c.confirmed) throw CommandRejected('NOT_ELIGIBLE');
        media.remove(d.id);
        discardOwned(d.id);
        primaryId = d.id;
        primaryType = 'mediaDraft';
      case RebaseJournalDraft():
        final d = journal(c.draftId, c.draftRevision), e = entries[d.entryId];
        plantId = d.plantId;
        if (e == null) throw CommandRejected('NOT_FOUND');
        if (e.revision != c.targetRevision)
          throw CommandRejected('STALE_TARGET');
        drafts[d.id] = JournalDraft(
          d.id,
          _nextRevision(d.revision),
          plantId,
          d.entryId,
          e.revision,
          d.fields,
          d.readyPhotoIds,
          d.createdAt,
          clock.instant,
        );
        bindings['target'] = e.toRow();
        primaryId = d.id;
        primaryType = 'journalDraft';
      case RebaseMediaDraft():
        final d = replacement(c.draftId, c.draftRevision),
            p = photos[d.photoId];
        plantId = d.plantId;
        if (p == null) throw CommandRejected('NOT_FOUND');
        if (p.revision != c.targetRevision)
          throw CommandRejected('STALE_TARGET');
        media[d.id] = MediaDraft(
          d.id,
          _nextRevision(d.revision),
          plantId,
          d.photoId,
          p.revision,
          d.readyPhotoIds,
          d.createdAt,
          clock.instant,
        );
        bindings['target'] = p.toRow();
        primaryId = d.id;
        primaryType = 'mediaDraft';
      case DeleteJournalEntry():
        final e = entries[c.entryId];
        if (e == null) throw CommandRejected('NOT_FOUND');
        plantId = e.plantId;
        if (e.revision != c.entryRevision)
          throw CommandRejected('STALE_TARGET');
        final owned = drafts.values.where((d) => d.entryId == e.id).toList();
        bindings['drafts'] = [for (final d in owned) d.toRow()];
        bindings['entry'] = e.toRow();
        for (final d in owned) {
          drafts.remove(d.id);
          discardOwned(d.id);
        }
        entries.remove(e.id);
        primaryId = e.id;
        primaryType = 'journal';
      case PhotoCommand():
        final p = photos[c.photoId];
        if (p == null || p.plantId == null) throw CommandRejected('NOT_FOUND');
        plantId = p.plantId!;
        if (p.revision != c.photoRevision)
          throw CommandRejected('STALE_TARGET');
        bindings['photo'] = p.toRow();
        primaryId = p.id;
        primaryType = 'photo';
        switch (c) {
          case UpdatePhotoObservation():
            if (c.observedDate.compareTo(clock.today) > 0)
              throw CommandRejected('FUTURE_OBSERVATION_DATE');
            photos[p.id] = PlantPhoto(
              p.id,
              plantId,
              null,
              _nextRevision(p.revision),
              p.contentPath,
              p.sha256,
              p.byteCount,
              p.mime,
              p.width,
              p.height,
              c.observedDate,
              p.sourceKind,
              p.optimizedFromHash,
              p.createdAt,
            );
          case ReplacePhoto():
            final d = replacement(c.draftId, c.draftRevision);
            if (d.photoId != p.id ||
                d.plantId != plantId ||
                d.basePhotoRevision != p.revision)
              throw CommandRejected('DRAFT_CONFLICT');
            if (d.readyPhotoIds.length != 1)
              throw CommandRejected('MEDIA_NOT_READY');
            final fresh = photos[d.readyPhotoIds.single]!;
            final ext = fresh.contentPath.split('.').last;
            photos[p.id] = PlantPhoto(
              p.id,
              plantId,
              null,
              _nextRevision(p.revision),
              'media/${p.id}/${fresh.sha256}.$ext',
              fresh.sha256,
              fresh.byteCount,
              fresh.mime,
              fresh.width,
              fresh.height,
              fresh.observedDate,
              fresh.sourceKind,
              null,
              p.createdAt,
            );
            bindings['draft'] = d.toRow();
            bindings['prepared'] = fresh.toRow();
            media.remove(d.id);
            discardOwned(d.id);
          case DeletePhoto():
            if (media.values.any((d) => d.photoId == p.id))
              throw CommandRejected('DRAFT_CONFLICT');
            final affected = entries.values
                .where((e) => e.photoIds.contains(p.id))
                .toList();
            for (final e in affected) {
              final remaining = e.photoIds.where((id) => id != p.id).toList();
              if (e.text.isEmpty && remaining.isEmpty) {
                if (drafts.values.any((d) => d.entryId == e.id))
                  throw CommandRejected('DRAFT_CONFLICT');
                entries.remove(e.id);
              } else {
                entries[e.id] = JournalEntry(
                  e.id,
                  plantId,
                  _nextRevision(e.revision),
                  e.entryDate,
                  e.text,
                  remaining,
                  e.createdAt,
                  clock.instant,
                );
              }
            }
            for (final d in drafts.values.toList()) {
              if (!d.fields.selectedPhotoIds.contains(p.id) &&
                  !d.readyPhotoIds.contains(p.id))
                continue;
              drafts[d.id] = JournalDraft(
                d.id,
                _nextRevision(d.revision),
                d.plantId,
                d.entryId,
                d.baseEntryRevision,
                JournalFields(
                  text: d.fields.text,
                  entryDate: d.fields.entryDate,
                  selectedPhotoIds: d.fields.selectedPhotoIds.where(
                    (id) => id != p.id,
                  ),
                ),
                d.readyPhotoIds.where((id) => id != p.id),
                d.createdAt,
                clock.instant,
              );
            }
            for (final draft in plantDrafts.values.toList()) {
              if (draft.fields.coverPhotoId != p.id) continue;
              final raw = draft.fields._json();
              raw['coverPhotoId'] = null;
              plantDrafts[draft.id] = PlantDraft._(
                draft.id,
                _nextRevision(draft.revision),
                draft.mode,
                draft.plantId,
                draft.basePlantRevision,
                _storedFields(raw, draft.fields.readyPhotoIds),
                draft.createdAt,
                clock.instant,
              );
            }
            covers.removeWhere((_, id) => id == p.id);
            photos.remove(p.id);
        }
    }
    final plant = s.plants[plantId];
    if (plant == null) throw CommandRejected('NOT_FOUND');
    // All effects and bindings are derived from exact changed rows, including
    // drafts. Collection revision alone cannot guard autosaves.
    void delta<T>(
      Map<String, T> old,
      Map<String, T> next,
      List<Object?> Function(T) row,
      int? revisionIndex,
    ) {
      for (final id in {...old.keys, ...next.keys}) {
        final before = old[id], after = next[id];
        if (canonicalCommandJson(before == null ? null : row(before)) ==
            canonicalCommandJson(after == null ? null : row(after)))
          continue;
        resources.add(id);
        bindings[id] = before == null ? null : row(before);
        if (after != null && revisionIndex != null)
          revisions[id] = row(after)[revisionIndex] as int;
      }
    }

    delta(
      s.drafts,
      plantDrafts,
      (d) => [d.id, d.revision, d.fields._json()],
      1,
    );
    delta(s.journalEntries, entries, (e) => e.toRow(), 2);
    delta(s.journalDrafts, drafts, (d) => d.toRow(), 1);
    delta(s.mediaDrafts, media, (d) => d.toRow(), 1);
    delta(s.photos, photos, (p) => p.toRow(), 3);
    for (final id in {...s.covers.keys, ...covers.keys}) {
      if (s.covers[id] != covers[id]) {
        resources.add(id);
        bindings['cover:$id'] = s.covers[id];
      }
    }
    return _Plan(
      CollectionSnapshot._(
        s.datasetId,
        c.draftOnly ? s.revision : _nextRevision(s.revision),
        s.plants,
        s.routines,
        s.careKinds,
        plantDrafts,
        s.reminderGeneration,
        s.scheduleChanges,
        s.suggestions,
        entries,
        drafts,
        media,
        photos,
        covers,
      ),
      CommandEffects._(
        [PreviewRow._(plantId, plant.name, null, null, null)],
        drafts: resources
            .where(
              (id) =>
                  s.journalDrafts.containsKey(id) ||
                  s.mediaDrafts.containsKey(id),
            )
            .length,
      ),
      canonicalCommandJson(bindings),
      primaryId,
      primaryType,
      resources,
      revisions,
      [],
    );
  }
}
