import Flutter
import Foundation
import VerdiNative

/// Only registered in DEBUG. No channel caller can choose the filesystem path.
final class DraftRepositoryBridge: DraftRepositoryHostApi {
  private let repository: DraftRepository
  init() throws {
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    repository = DraftRepository(directory: support.appendingPathComponent("VerdiDraftIntegration", isDirectory: true))
  }
  private func call<T>(_ body: () throws -> T) throws -> T {
    do { return try body() }
    catch let error as DraftRepositoryError { throw PigeonError(code: error.code, message: nil, details: nil) }
    catch { throw PigeonError(code: "STORAGE_UNAVAILABLE", message: nil, details: nil) }
  }
  private func receipt(_ value: NativeDraftReceipt) -> DraftReceiptMessage {
    DraftReceiptMessage(commandId: value.commandID, datasetId: value.datasetID, draftId: value.draftID, draftRevision: value.draftRevision, collectionRevision: value.collectionRevision, replayed: value.replayed)
  }
  func openDraftRepository(protocolVersion: Int64) throws -> DraftSessionMessage {
    try call {
      let value = try repository.open(protocolVersion: protocolVersion)
      return DraftSessionMessage(sessionId: value.sessionID, datasetId: value.datasetID, schemaVersion: value.schemaVersion, fileProtectionVerified: value.fileProtectionVerified)
    }
  }
  func closeDraftRepository(sessionId: String) throws { try call { try repository.close(sessionID: sessionId) } }
  func freezeDraft(sessionId: String, write: DraftWriteMessage) throws {
    try call { try repository.freeze(sessionID: sessionId, write: NativeDraftWrite(commandID: write.commandId, draftID: write.draftId, expectedRevision: write.expectedRevision, rawFieldsCanonicalJSON: write.rawFieldsCanonicalJson, payloadHash: write.payloadHash)) }
  }
  func commitDraft(sessionId: String, commandId: String, payloadHash: String) throws -> DraftReceiptMessage {
    try call { receipt(try repository.commit(sessionID: sessionId, commandID: commandId, payloadHash: payloadHash)) }
  }
  func readDraft(sessionId: String) throws -> DraftRecordMessage? {
    try call {
      guard let value = try repository.read(sessionID: sessionId) else { return nil }
      return DraftRecordMessage(draftId: value.draftID, revision: value.revision, rawFieldsCanonicalJson: value.rawFieldsCanonicalJSON, createdAt: value.createdAt, updatedAt: value.updatedAt)
    }
  }
  func resolveDraft(sessionId: String, commandId: String, payloadHash: String) throws -> DraftReceiptMessage? {
    try call { try repository.resolve(sessionID: sessionId, commandID: commandId, payloadHash: payloadHash).map(receipt) }
  }
  func abandonDraft(sessionId: String, commandId: String, payloadHash: String) throws -> DraftReceiptMessage? {
    try call { try repository.abandon(sessionID: sessionId, commandID: commandId, payloadHash: payloadHash).map(receipt) }
  }
  func pendingDrafts(sessionId: String, afterCommandId: String?) throws -> DraftPageMessage {
    try call {
      let value = try repository.pending(sessionID: sessionId, after: afterCommandId)
      return DraftPageMessage(items: value.items.map { DraftPendingMessage(commandId: $0.commandID, draftId: $0.draftID, expectedRevision: $0.expectedRevision, payloadHash: $0.payloadHash) }, nextCursor: value.nextCursor)
    }
  }
  func getPendingDraft(sessionId: String, commandId: String, payloadHash: String) throws -> DraftWriteMessage {
    try call {
      let value = try repository.getPending(sessionID: sessionId, commandID: commandId, payloadHash: payloadHash)
      return DraftWriteMessage(commandId: value.commandID, draftId: value.draftID, expectedRevision: value.expectedRevision, rawFieldsCanonicalJson: value.rawFieldsCanonicalJSON, payloadHash: value.payloadHash)
    }
  }
}
