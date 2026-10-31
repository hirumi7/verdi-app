part of 'collection.dart';

/// Original-file metadata. Paths are storage-only; the UI requests bounded views.
final class PlantPhoto {
  final String id;
  final String? plantId, draftId;
  final int revision;
  final String contentPath, sha256, mime, sourceKind;
  final int byteCount, width, height;
  final LocalDate observedDate;
  final String? optimizedFromHash;
  final DateTime createdAt;
  const PlantPhoto(
    this.id,
    this.plantId,
    this.draftId,
    this.revision,
    this.contentPath,
    this.sha256,
    this.byteCount,
    this.mime,
    this.width,
    this.height,
    this.observedDate,
    this.sourceKind,
    this.optimizedFromHash,
    this.createdAt,
  );
  PlantPhoto ownedBy(String plant) => PlantPhoto(
    id,
    plant,
    null,
    _nextRevision(revision),
    contentPath,
    sha256,
    byteCount,
    mime,
    width,
    height,
    observedDate,
    sourceKind,
    optimizedFromHash,
    createdAt,
  );
  List<Object?> toRow() => [
    id,
    plantId,
    draftId,
    revision,
    contentPath,
    sha256,
    byteCount,
    mime,
    width,
    height,
    observedDate.toString(),
    sourceKind,
    optimizedFromHash,
    createdAt.toIso8601String(),
  ];
}

final class JournalEntry {
  final String id, plantId, text;
  final int revision;
  final LocalDate entryDate;
  final List<String> photoIds;
  final DateTime createdAt, updatedAt;
  JournalEntry(
    this.id,
    this.plantId,
    this.revision,
    this.entryDate,
    this.text,
    Iterable<String> photos,
    this.createdAt,
    this.updatedAt,
  ) : photoIds = List.unmodifiable(photos);
  List<Object?> toRow() => [
    id,
    plantId,
    revision,
    entryDate.toString(),
    text,
    canonicalCommandJson(photoIds),
    createdAt.toIso8601String(),
    updatedAt.toIso8601String(),
  ];
}

final class JournalFields {
  final String text, entryDate;
  final List<String> selectedPhotoIds;
  JournalFields({
    this.text = '',
    required this.entryDate,
    Iterable<String> selectedPhotoIds = const [],
  }) : selectedPhotoIds = List.unmodifiable(selectedPhotoIds);
  Map<String, Object?> toJson() => {
    'text': text,
    'entryDate': entryDate,
    'selectedPhotoIds': selectedPhotoIds,
  };
  factory JournalFields.fromJson(Object? raw) {
    final m = _map(raw);
    if (m.keys.toSet().difference({
          'text',
          'entryDate',
          'selectedPhotoIds',
        }).isNotEmpty ||
        m.length != 3)
      throw CommandRejected('FIELD_INVALID');
    return JournalFields(
      text: m['text'] as String,
      entryDate: m['entryDate'] as String,
      selectedPhotoIds: _list(m['selectedPhotoIds']).cast<String>(),
    );
  }
}

final class JournalDraft {
  final String id, plantId;
  final int revision;
  final String? entryId;
  final int? baseEntryRevision;
  final JournalFields fields;
  final List<String> readyPhotoIds;
  final DateTime createdAt, updatedAt;
  JournalDraft(
    this.id,
    this.revision,
    this.plantId,
    this.entryId,
    this.baseEntryRevision,
    this.fields,
    Iterable<String> ready,
    this.createdAt,
    this.updatedAt,
  ) : readyPhotoIds = List.unmodifiable(ready);
  List<Object?> toRow() => [
    id,
    revision,
    plantId,
    entryId,
    baseEntryRevision,
    canonicalCommandJson(fields.toJson()),
    canonicalCommandJson(readyPhotoIds),
    createdAt.toIso8601String(),
    updatedAt.toIso8601String(),
  ];
}

final class MediaDraft {
  final String id, plantId, photoId;
  final int revision, basePhotoRevision;
  final List<String> readyPhotoIds;
  final DateTime createdAt, updatedAt;
  MediaDraft(
    this.id,
    this.revision,
    this.plantId,
    this.photoId,
    this.basePhotoRevision,
    Iterable<String> ready,
    this.createdAt,
    this.updatedAt,
  ) : readyPhotoIds = List.unmodifiable(ready);
  List<Object?> toRow() => [
    id,
    revision,
    plantId,
    photoId,
    basePhotoRevision,
    canonicalCommandJson(readyPhotoIds),
    createdAt.toIso8601String(),
    updatedAt.toIso8601String(),
  ];
}

sealed class MediaCommand extends CoreCommand {
  const MediaCommand();
  String? get guardedDraftId => null;
  int? get guardedDraftRevision => null;
  bool get draftOnly => false;
}

final class SaveJournalDraft extends MediaCommand {
  final String draftId, plantId;
  final int? expectedRevision, baseEntryRevision;
  final String? entryId;
  final JournalFields fields;
  final List<String> readyPhotoIds;
  SaveJournalDraft({
    required this.draftId,
    required this.expectedRevision,
    required this.plantId,
    this.entryId,
    this.baseEntryRevision,
    required this.fields,
    Iterable<String> readyPhotoIds = const [],
  }) : readyPhotoIds = List.unmodifiable(readyPhotoIds);
  @override
  String get type => 'SaveJournalDraft';
  @override
  bool get _needsPreview => false;
  @override
  bool get draftOnly => true;
  @override
  String get guardedDraftId => draftId;
  @override
  int? get guardedDraftRevision => expectedRevision;
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'expectedRevision': expectedRevision,
    'plantId': plantId,
    'entryId': entryId,
    'baseEntryRevision': baseEntryRevision,
    'rawFields': fields.toJson(),
    'readyPhotoIds': readyPhotoIds,
  };
}

final class SaveMediaDraft extends MediaCommand {
  final String draftId, plantId, photoId;
  final int? expectedRevision;
  final int basePhotoRevision;
  final List<String> readyPhotoIds;
  SaveMediaDraft({
    required this.draftId,
    required this.expectedRevision,
    required this.plantId,
    required this.photoId,
    required this.basePhotoRevision,
    Iterable<String> readyPhotoIds = const [],
  }) : readyPhotoIds = List.unmodifiable(readyPhotoIds);
  @override
  String get type => 'SaveMediaDraft';
  @override
  bool get _needsPreview => false;
  @override
  bool get draftOnly => true;
  @override
  String get guardedDraftId => draftId;
  @override
  int? get guardedDraftRevision => expectedRevision;
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'expectedRevision': expectedRevision,
    'plantId': plantId,
    'photoId': photoId,
    'basePhotoRevision': basePhotoRevision,
    'readyPhotoIds': readyPhotoIds,
  };
}

sealed class MediaDraftCommand extends MediaCommand {
  final String draftId;
  final int draftRevision;
  const MediaDraftCommand(this.draftId, this.draftRevision);
  @override
  String get guardedDraftId => draftId;
  @override
  int get guardedDraftRevision => draftRevision;
  @override
  Map<String, Object?> get _payload => {
    'draftId': draftId,
    'draftRevision': draftRevision,
  };
}

final class SaveJournalEntry extends MediaDraftCommand {
  const SaveJournalEntry(super.draftId, super.draftRevision);
  @override
  String get type => 'SaveJournalEntry';
}

final class DiscardJournalDraft extends MediaDraftCommand {
  final bool confirmed;
  const DiscardJournalDraft(
    super.draftId,
    super.draftRevision, {
    required this.confirmed,
  });
  @override
  String get type => 'DiscardJournalDraft';
  @override
  bool get _needsPreview => false;
  @override
  bool get draftOnly => true;
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'confirmed': confirmed,
  };
}

final class DiscardMediaDraft extends MediaDraftCommand {
  final bool confirmed;
  const DiscardMediaDraft(
    super.draftId,
    super.draftRevision, {
    required this.confirmed,
  });
  @override
  String get type => 'DiscardMediaDraft';
  @override
  bool get _needsPreview => false;
  @override
  bool get draftOnly => true;
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'confirmed': confirmed,
  };
}

final class RebaseJournalDraft extends MediaDraftCommand {
  final int targetRevision;
  const RebaseJournalDraft(
    super.draftId,
    super.draftRevision,
    this.targetRevision,
  );
  @override
  String get type => 'RebaseJournalDraft';
  @override
  bool get draftOnly => true;
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'targetRevision': targetRevision,
  };
}

final class RebaseMediaDraft extends MediaDraftCommand {
  final int targetRevision;
  const RebaseMediaDraft(
    super.draftId,
    super.draftRevision,
    this.targetRevision,
  );
  @override
  String get type => 'RebaseMediaDraft';
  @override
  bool get draftOnly => true;
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'targetRevision': targetRevision,
  };
}

final class DeleteJournalEntry extends MediaCommand {
  final String entryId;
  final int entryRevision;
  const DeleteJournalEntry(this.entryId, this.entryRevision);
  @override
  String get type => 'DeleteJournalEntry';
  @override
  Map<String, Object?> get _payload => {
    'entryId': entryId,
    'entryRevision': entryRevision,
  };
}

sealed class PhotoCommand extends MediaCommand {
  final String photoId;
  final int photoRevision;
  const PhotoCommand(this.photoId, this.photoRevision);
  @override
  Map<String, Object?> get _payload => {
    'photoId': photoId,
    'photoRevision': photoRevision,
  };
}

final class DeletePhoto extends PhotoCommand {
  const DeletePhoto(super.photoId, super.photoRevision);
  @override
  String get type => 'DeletePhoto';
}

final class UpdatePhotoObservation extends PhotoCommand {
  final LocalDate observedDate;
  const UpdatePhotoObservation(
    super.photoId,
    super.photoRevision,
    this.observedDate,
  );
  @override
  String get type => 'UpdatePhotoObservation';
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'observedDate': observedDate.toString(),
  };
}

final class ReplacePhoto extends PhotoCommand {
  final String preparationId, draftId;
  final int draftRevision;
  const ReplacePhoto(
    super.photoId,
    super.photoRevision, {
    required this.preparationId,
    required this.draftId,
    required this.draftRevision,
  });
  @override
  String get type => 'ReplacePhoto';
  @override
  String get guardedDraftId => draftId;
  @override
  int get guardedDraftRevision => draftRevision;
  @override
  Map<String, Object?> get _payload => {
    ...super._payload,
    'preparationId': preparationId,
    'draftId': draftId,
    'draftRevision': draftRevision,
  };
}

bool _draftOnly(CoreCommand c) =>
    c is SaveDraft || c is DiscardDraft || (c is MediaCommand && c.draftOnly);
void _photoIds(Iterable<String> ids) {
  if (ids.toSet().length != ids.length) throw CommandRejected('FIELD_INVALID');
  for (final id in ids) {
    _id(id);
  }
}

void _validateMedia(MediaCommand c) {
  if (c.guardedDraftId != null) _id(c.guardedDraftId!);
  if (c.guardedDraftRevision != null) _revision(c.guardedDraftRevision!);
  switch (c) {
    case SaveJournalDraft():
      _id(c.plantId);
      if ((c.entryId == null) != (c.baseEntryRevision == null))
        throw CommandRejected('FIELD_INVALID');
      if (c.entryId != null) {
        _id(c.entryId!);
        _revision(c.baseEntryRevision!);
      }
      _photoIds(c.fields.selectedPhotoIds);
      _photoIds(c.readyPhotoIds);
    case SaveMediaDraft():
      _id(c.plantId);
      _id(c.photoId);
      _revision(c.basePhotoRevision);
      _photoIds(c.readyPhotoIds);
    case RebaseJournalDraft():
      _revision(c.targetRevision);
    case RebaseMediaDraft():
      _revision(c.targetRevision);
    case DeleteJournalEntry():
      _id(c.entryId);
      _revision(c.entryRevision);
    case PhotoCommand():
      _id(c.photoId);
      _revision(c.photoRevision);
      if (c is ReplacePhoto) _id(c.preparationId);
    case SaveJournalEntry() || DiscardJournalDraft() || DiscardMediaDraft():
      break;
  }
}
