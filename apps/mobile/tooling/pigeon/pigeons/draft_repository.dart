import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: '../../lib/core/native/draft_bridge.g.dart',
    swiftOut: '../../ios/Runner/DraftBridge.g.swift',
    dartPackageName: 'verdi_mobile',
  ),
)
class DraftSessionMessage {
  DraftSessionMessage({
    required this.sessionId,
    required this.datasetId,
    required this.schemaVersion,
    required this.fileProtectionVerified,
  });
  String sessionId;
  String datasetId;
  int schemaVersion;
  bool fileProtectionVerified;
}

class DraftWriteMessage {
  DraftWriteMessage({
    required this.commandId,
    required this.draftId,
    this.expectedRevision,
    required this.rawFieldsCanonicalJson,
    required this.payloadHash,
  });
  String commandId;
  String draftId;
  int? expectedRevision;
  String rawFieldsCanonicalJson;
  String payloadHash;
}

class DraftRecordMessage {
  DraftRecordMessage({
    required this.draftId,
    required this.revision,
    required this.rawFieldsCanonicalJson,
    required this.createdAt,
    required this.updatedAt,
  });
  String draftId;
  int revision;
  String rawFieldsCanonicalJson;
  String createdAt;
  String updatedAt;
}

class DraftReceiptMessage {
  DraftReceiptMessage({
    required this.commandId,
    required this.datasetId,
    required this.draftId,
    required this.draftRevision,
    required this.collectionRevision,
    required this.replayed,
  });
  String commandId;
  String datasetId;
  String draftId;
  int draftRevision;
  int collectionRevision;
  bool replayed;
}

class DraftPendingMessage {
  DraftPendingMessage({
    required this.commandId,
    required this.draftId,
    this.expectedRevision,
    required this.payloadHash,
  });
  String commandId;
  String draftId;
  int? expectedRevision;
  String payloadHash;
}

class DraftPageMessage {
  DraftPageMessage({required this.items, this.nextCursor});
  List<DraftPendingMessage> items;
  String? nextCursor;
}

@HostApi()
abstract class DraftRepositoryHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftSessionMessage openDraftRepository(int protocolVersion);
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void closeDraftRepository(String sessionId);
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  void freezeDraft(String sessionId, DraftWriteMessage write);
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftReceiptMessage commitDraft(
    String sessionId,
    String commandId,
    String payloadHash,
  );
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftRecordMessage? readDraft(String sessionId);
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftReceiptMessage? resolveDraft(
    String sessionId,
    String commandId,
    String payloadHash,
  );
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftReceiptMessage? abandonDraft(
    String sessionId,
    String commandId,
    String payloadHash,
  );
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftPageMessage pendingDrafts(String sessionId, String? afterCommandId);
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  DraftWriteMessage getPendingDraft(
    String sessionId,
    String commandId,
    String payloadHash,
  );
}

/// Bounded canonical envelopes preserve raw UTF-16 drafts. Native dispatch is a
/// closed operation registry; this is not a SQL or filesystem transport.
@HostApi()
abstract class CoreRepositoryHostApi {
  @TaskQueue(type: TaskQueueType.serialBackgroundThread)
  String callCore(String operation, String canonicalBody);
}
