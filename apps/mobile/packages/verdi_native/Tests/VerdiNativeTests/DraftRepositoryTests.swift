import Foundation
import XCTest
@testable import VerdiNative

final class DraftRepositoryTests: XCTestCase {
    private var root: URL!
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }
    private func fields(notes: CanonicalValue = .string("raw note")) -> CanonicalValue {
        .object(["name": .string("Fern"), "location": .string(""), "notes": notes,
                 "identityKind": .string("custom"), "coverPhotoId": .null, "speciesId": .null,
                 "catalogSelection": .null, "customSpeciesName": .string("Unknown"),
                 "customLight": .string("unknown"), "customToxicity": .string("unknown"),
                 "routineInputs": .array([.object(["kind": .string("water"), "count": .string(""), "unit": .string("week"), "seed": .null])]),
                 "baseRoutineRevisions": .array([]), "speciesChoices": .array([])])
    }
    private func write(id: String = UUID().uuidString.lowercased(), draft: String = UUID().uuidString.lowercased(), revision: Int64? = nil, fields: CanonicalValue? = nil) throws -> NativeDraftWrite {
        let value = fields ?? self.fields()
        let payload: [String: CanonicalValue] = ["draftId": .string(draft), "expectedRevision": revision.map(CanonicalValue.integer) ?? .null, "mode": .string("add"), "plantId": .null, "basePlantRevision": .null, "rawFields": value, "photoIds": .array([])]
        return NativeDraftWrite(commandID: id, draftID: draft, expectedRevision: revision, rawFieldsCanonicalJSON: try value.json(), payloadHash: try CanonicalCommand.commandHash(type: "SaveDraft", payload: payload))
    }
    private func code<T>(_ expected: String, _ operation: () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            XCTAssertEqual((error as? DraftRepositoryError)?.code, expected, file: file, line: line)
        }
    }
    func testProtectionPolicyNeverTreatsSimulationAsDeviceProof() throws {
        XCTAssertFalse(try DraftProtection.apply(deviceRequired: false, set: {}, read: { nil }))
        XCTAssertFalse(try DraftProtection.apply(deviceRequired: false, set: {}, read: { DraftProtection.requiredClass }))
        XCTAssertTrue(try DraftProtection.apply(deviceRequired: true, set: {}, read: { DraftProtection.requiredClass }))
        XCTAssertThrowsError(try DraftProtection.apply(deviceRequired: true, set: {}, read: { nil }))
        for required in [false, true] {
            XCTAssertThrowsError(try DraftProtection.apply(deviceRequired: required, set: {}, read: { "NSFileProtectionNone" }))
            XCTAssertThrowsError(try DraftProtection.apply(deviceRequired: required, set: { throw StorageFailure.unavailable }, read: { DraftProtection.requiredClass }))
        }
    }
    func testRawDraftReopensAndLostReplyReplaysOneRevision() throws {
        let repository = DraftRepository(directory: root)
        var session = try repository.open(protocolVersion: 1)
        let raw: [UInt16] = [0, 0xd800, 0x61, 0xd83c, 0xdf3f, 0xdc00]
        let first = try write(fields: fields(notes: .utf16(raw)))
        try repository.freeze(sessionID: session.sessionID, write: first)
        // Termination after freeze: only the pending body is durable.
        let dataset = session.datasetID
        try repository.close(sessionID: session.sessionID)
        session = try repository.open(protocolVersion: 1)
        XCTAssertEqual(session.datasetID, dataset)
        #if !os(iOS) || targetEnvironment(simulator)
        XCTAssertFalse(session.fileProtectionVerified)
        #else
        XCTAssertTrue(session.fileProtectionVerified)
        #endif
        XCTAssertNil(try repository.read(sessionID: session.sessionID))
        XCTAssertNil(try repository.resolve(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash))
        XCTAssertEqual(try repository.getPending(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash).rawFieldsCanonicalJSON, first.rawFieldsCanonicalJSON)
        let saved = try repository.commit(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash)
        XCTAssertFalse(saved.replayed)
        // Discard fresh reply, close/reopen, and retry the original command.
        try repository.close(sessionID: session.sessionID)
        session = try repository.open(protocolVersion: 1)
        let replay = try repository.commit(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash)
        XCTAssertTrue(replay.replayed); XCTAssertEqual(replay.draftRevision, 1)
        XCTAssertEqual(try repository.pending(sessionID: session.sessionID, after: nil).items.count, 0)
        let record = try XCTUnwrap(repository.read(sessionID: session.sessionID))
        XCTAssertEqual(record.revision, 1)
        XCTAssertEqual(try CanonicalParser.parse(record.rawFieldsCanonicalJSON).object?["notes"]?.units, raw)
        let second = try write(draft: first.draftID, revision: 1, fields: fields(notes: .string("revised")))
        try repository.freeze(sessionID: session.sessionID, write: second)
        XCTAssertEqual(try repository.commit(sessionID: session.sessionID, commandID: second.commandID, payloadHash: second.payloadHash).draftRevision, 2)
        let updated = try XCTUnwrap(repository.read(sessionID: session.sessionID))
        XCTAssertEqual(updated.createdAt, record.createdAt)
        XCTAssertEqual(updated.rawFieldsCanonicalJSON, second.rawFieldsCanonicalJSON)
        try repository.close(sessionID: session.sessionID)
    }
    func testStaleConcurrentDraftAndChangedIdentityNeverOverwrite() throws {
        let repository = DraftRepository(directory: root)
        let session = try repository.open(protocolVersion: 1)
        let first = try write()
        let competing = try write()
        for value in [first, competing] { try repository.freeze(sessionID: session.sessionID, write: value) }
        _ = try repository.commit(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash)
        code("DRAFT_CONFLICT") { try repository.commit(sessionID: session.sessionID, commandID: competing.commandID, payloadHash: competing.payloadHash) }
        let stale = try write(draft: first.draftID)
        try repository.freeze(sessionID: session.sessionID, write: stale)
        code("STALE_TARGET") { try repository.commit(sessionID: session.sessionID, commandID: stale.commandID, payloadHash: stale.payloadHash) }
        let changed = try write(id: first.commandID, draft: first.draftID, revision: 1)
        code("COMMAND_ID_REUSED") { try repository.freeze(sessionID: session.sessionID, write: changed) }
        code("COMMAND_ID_REUSED") { try repository.resolve(sessionID: session.sessionID, commandID: first.commandID, payloadHash: changed.payloadHash) }
        code("NOT_FOUND") { try repository.getPending(sessionID: session.sessionID, commandID: first.commandID, payloadHash: first.payloadHash) }
        // Committed-body cleanup still permits identical freeze and receipt replay.
        try repository.freeze(sessionID: session.sessionID, write: first)
        XCTAssertEqual(try repository.read(sessionID: session.sessionID)?.revision, 1)
        XCTAssertNil(try repository.resolve(sessionID: session.sessionID, commandID: stale.commandID, payloadHash: stale.payloadHash))
        try repository.close(sessionID: session.sessionID)
    }
    func testAbandonmentScrubsBodyAndRetainsTombstone() throws {
        let repository = DraftRepository(directory: root)
        var session = try repository.open(protocolVersion: 1)
        let request = try write()
        try repository.freeze(sessionID: session.sessionID, write: request)
        XCTAssertNil(try repository.abandon(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash))
        try repository.close(sessionID: session.sessionID)
        session = try repository.open(protocolVersion: 1)
        XCTAssertNil(try repository.abandon(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash))
        code("NOT_FOUND") { try repository.getPending(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash) }
        code("NOT_ELIGIBLE") { try repository.freeze(sessionID: session.sessionID, write: request) }
        code("NOT_ELIGIBLE") { try repository.commit(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash) }
        XCTAssertTrue(try repository.pending(sessionID: session.sessionID, after: nil).items.isEmpty)
        XCTAssertNil(try repository.read(sessionID: session.sessionID))
        try repository.close(sessionID: session.sessionID)
    }
    func testPrecommitFailureRollsBackDraftAndReceiptTogether() throws {
        var fail = false
        let repository = DraftRepository(directory: root, fault: { boundary in
            if fail && boundary == .beforeCommit { fail = false; throw StorageFailure.unavailable }
        })
        let session = try repository.open(protocolVersion: 1)
        let request = try write()
        try repository.freeze(sessionID: session.sessionID, write: request)
        fail = true
        code("STORAGE_UNAVAILABLE") { try repository.commit(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash) }
        XCTAssertNil(try repository.read(sessionID: session.sessionID))
        XCTAssertNil(try repository.resolve(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash))
        XCTAssertEqual(try repository.commit(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash).draftRevision, 1)
        try repository.close(sessionID: session.sessionID)
    }
    func testUnknownAfterCommitRequiresReopenThenResolves() throws {
        var fail = false
        let repository = DraftRepository(directory: root, fault: { boundary in
            if fail && boundary == .afterCommit { fail = false; throw StorageFailure.unavailable }
        })
        var session = try repository.open(protocolVersion: 1)
        let request = try write(); try repository.freeze(sessionID: session.sessionID, write: request)
        fail = true
        code("UNKNOWN_OUTCOME") { try repository.commit(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash) }
        code("STORAGE_UNAVAILABLE") { try repository.resolve(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash) }
        session = try repository.open(protocolVersion: 1)
        XCTAssertEqual(try repository.resolve(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash)?.draftRevision, 1)
        XCTAssertEqual(try repository.read(sessionID: session.sessionID)?.revision, 1)
        try repository.close(sessionID: session.sessionID)
    }
    func testMissingInitializedStorageNeverResetsAndSessionExpires() throws {
        let repository = DraftRepository(directory: root)
        let first = try repository.open(protocolVersion: 1)
        let second = try repository.open(protocolVersion: 1)
        code("SESSION_INVALID") { try repository.read(sessionID: first.sessionID) }
        code("PROTOCOL_INCOMPATIBLE") { try repository.open(protocolVersion: 2) }
        try repository.close(sessionID: second.sessionID)
        try FileManager.default.removeItem(at: root.appendingPathComponent("drafts.sqlite"))
        code("STORAGE_UNAVAILABLE") { try repository.open(protocolVersion: 1) }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("drafts.sqlite").path))
    }
    func testMalformedAndOversizedFieldsPreservePriorDraftAndDuplicateRows() throws {
        let repository = DraftRepository(directory: root)
        let session = try repository.open(protocolVersion: 1)
        var raw = try XCTUnwrap(fields().object)
        raw["routineInputs"] = .array([raw["routineInputs"]!.array!.first!, raw["routineInputs"]!.array!.first!])
        let request = try write(fields: .object(raw))
        try repository.freeze(sessionID: session.sessionID, write: request)
        _ = try repository.commit(sessionID: session.sessionID, commandID: request.commandID, payloadHash: request.payloadHash)
        raw["extra"] = .null
        code("FIELD_INVALID") { try repository.freeze(sessionID: session.sessionID, write: write(draft: request.draftID, revision: 1, fields: .object(raw))) }
        let oversized = try write(draft: request.draftID, revision: 1, fields: fields(notes: .string(String(repeating: "a", count: 1_048_576))))
        code("FIELD_INVALID") { try repository.freeze(sessionID: session.sessionID, write: oversized) }
        let badHash = NativeDraftWrite(commandID: UUID().uuidString.lowercased(), draftID: request.draftID, expectedRevision: 1, rawFieldsCanonicalJSON: request.rawFieldsCanonicalJSON, payloadHash: String(repeating: "0", count: 64))
        code("HASH_MISMATCH") { try repository.freeze(sessionID: session.sessionID, write: badHash) }
        XCTAssertEqual(try repository.read(sessionID: session.sessionID)?.rawFieldsCanonicalJSON, request.rawFieldsCanonicalJSON)
        try repository.close(sessionID: session.sessionID)
    }
    func testPendingPagesOnlyMetadataAndFetchOneLargeBody() throws {
        let repository = DraftRepository(directory: root)
        let session = try repository.open(protocolVersion: 1)
        let large = try write(fields: fields(notes: .string(String(repeating: "a", count: 800_000))))
        try repository.freeze(sessionID: session.sessionID, write: large)
        for _ in 0..<201 { try repository.freeze(sessionID: session.sessionID, write: write()) }
        let first = try repository.pending(sessionID: session.sessionID, after: nil)
        XCTAssertEqual(first.items.count, 200)
        let last = try repository.pending(sessionID: session.sessionID, after: XCTUnwrap(first.nextCursor))
        XCTAssertEqual(last.items.count, 2); XCTAssertNil(last.nextCursor)
        XCTAssertEqual(Set((first.items + last.items).map(\.commandID)).count, 202)
        XCTAssertEqual(try repository.getPending(sessionID: session.sessionID, commandID: large.commandID, payloadHash: large.payloadHash).rawFieldsCanonicalJSON, large.rawFieldsCanonicalJSON)
        try repository.close(sessionID: session.sessionID)
    }
    func testExactPayloadByteBoundaryAndPreservedAcknowledgement() throws {
        let repository = DraftRepository(directory: root)
        let session = try repository.open(protocolVersion: 1)
        let draft = UUID().uuidString.lowercased()
        let base = try write(draft: draft, fields: fields(notes: .string("")))
        let payload: CanonicalValue = .object(["draftId": .string(draft), "expectedRevision": .null, "mode": .string("add"), "plantId": .null, "basePlantRevision": .null, "rawFields": fields(notes: .string("")), "photoIds": .array([])])
        let length = 1_048_576 - (try payload.json().utf8.count)
        // Include two-byte Unicode and escaped NUL, not just a character count.
        let note = "é" + String(repeating: "a", count: length - 8) + "\0"
        let exact = try write(id: base.commandID, draft: draft, fields: fields(notes: .string(note)))
        try repository.freeze(sessionID: session.sessionID, write: exact)
        _ = try repository.commit(sessionID: session.sessionID, commandID: exact.commandID, payloadHash: exact.payloadHash)
        let tooLarge = try write(draft: draft, fields: fields(notes: .string(note + "a")))
        code("FIELD_INVALID") { try repository.freeze(sessionID: session.sessionID, write: tooLarge) }
        XCTAssertEqual(try repository.read(sessionID: session.sessionID)?.rawFieldsCanonicalJSON, exact.rawFieldsCanonicalJSON)
        try repository.close(sessionID: session.sessionID)
    }
    func testCorruptInitializedFileIsPreservedAndNeverRecreated() throws {
        let repository = DraftRepository(directory: root)
        let session = try repository.open(protocolVersion: 1)
        try repository.close(sessionID: session.sessionID)
        let file = root.appendingPathComponent("drafts.sqlite")
        let original = Data("unsupported development fixture".utf8)
        try original.write(to: file)
        code("STORAGE_UNAVAILABLE") { try repository.open(protocolVersion: 1) }
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testLosslessParserRejectsNoncanonicalAndMalformedInputs() throws {
        for text in ["{\"x\":1,\"x\":2}", "{\"b\":1,\"a\":2}", "1.0", "01", "-0", "[1,]", "true ", "\"\\u0061\"", "\"\\ud800", "{\"é\":1}"] {
            XCTAssertThrowsError(try CanonicalParser.parse(text), text)
        }
        XCTAssertEqual(try CanonicalParser.parse("\"\\ud800a🌿\\udc00\"").units, [0xd800, 97, 0xd83c, 0xdf3f, 0xdc00])
        XCTAssertNoThrow(try CanonicalParser.parse(String(repeating: "[", count: 64) + "0" + String(repeating: "]", count: 64)))
        XCTAssertThrowsError(try CanonicalParser.parse(String(repeating: "[", count: 65) + "0" + String(repeating: "]", count: 65)))
    }
}
