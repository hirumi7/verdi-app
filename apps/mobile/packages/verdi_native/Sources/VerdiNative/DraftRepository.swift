import Darwin
import Dispatch
import Foundation

public struct DraftRepositoryError: Error {
    public let code: String
    init(_ code: String) { self.code = code }
}
public struct DraftRepositorySession {
    public let sessionID: String
    public let datasetID: String
    public let schemaVersion: Int64 = 1
    public let fileProtectionVerified: Bool
}
public struct NativeDraftWrite {
    public let commandID: String
    public let draftID: String
    public let expectedRevision: Int64?
    public let rawFieldsCanonicalJSON: String
    public let payloadHash: String
    public init(commandID: String, draftID: String, expectedRevision: Int64?, rawFieldsCanonicalJSON: String, payloadHash: String) {
        self.commandID = commandID; self.draftID = draftID; self.expectedRevision = expectedRevision
        self.rawFieldsCanonicalJSON = rawFieldsCanonicalJSON; self.payloadHash = payloadHash
    }
}
public struct NativeDraftRecord {
    public let draftID: String
    public let revision: Int64
    public let rawFieldsCanonicalJSON: String
    public let createdAt: String
    public let updatedAt: String
}
public struct NativeDraftReceipt {
    public let commandID: String
    public let datasetID: String
    public let draftID: String
    public let draftRevision: Int64
    public let collectionRevision: Int64 = 1
    public let replayed: Bool
}
public struct NativeDraftPending {
    public let commandID: String
    public let draftID: String
    public let expectedRevision: Int64?
    public let payloadHash: String
}
public struct NativeDraftPage {
    public let items: [NativeDraftPending]
    public let nextCursor: String?
}

/// Isolated installation-local integration repository, NOT the product dataset.
/// One bounded add draft, successful receipts, and immutable command tombstones.
public final class DraftRepository {
    private let directory: URL
    private let queue = DispatchQueue(label: "verdi.native.draft-repository")
    private var database: SQLiteDatabase?
    private var session: DraftRepositorySession?
    private let fault: ((SQLiteBoundary) throws -> Void)?
    private let now: () -> Date
    private static let maximumRevision: Int64 = 9_007_199_254_740_991
    public convenience init(directory: URL) { self.init(directory: directory, fault: nil) }
    init(directory: URL, fault: ((SQLiteBoundary) throws -> Void)?, now: @escaping () -> Date = Date.init) {
        self.directory = directory; self.fault = fault; self.now = now
    }
    private func run<T>(_ work: () throws -> T) throws -> T {
        try queue.sync {
            do { return try work() }
            catch let failure as DraftRepositoryError { throw failure }
            catch StorageFailure.unknownOutcome { throw DraftRepositoryError("UNKNOWN_OUTCOME") }
            catch StorageFailure.sqlite(let code) where code & 255 == 5 { throw DraftRepositoryError("BUSY") }
            catch StorageFailure.sqlite(let code) where code & 255 == 13 { throw DraftRepositoryError("DISK_FULL") }
            catch { throw DraftRepositoryError("STORAGE_UNAVAILABLE") }
        }
    }
    private func connection(_ sessionID: String) throws -> (SQLiteDatabase, DraftRepositorySession) {
        guard let database, let session, session.sessionID == sessionID else { throw DraftRepositoryError("SESSION_INVALID") }
        return (database, session)
    }
    public func open(protocolVersion: Int64) throws -> DraftRepositorySession {
        try run {
            guard protocolVersion == 1 else { throw DraftRepositoryError("PROTOCOL_INCOMPATIBLE") }
            session = nil
            if let database { try database.close(); self.database = nil }
            let marker = directory.appendingPathComponent("initialized")
            let file = directory.appendingPathComponent("drafts.sqlite")
            let manager = FileManager.default
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            try protect(directory)
            let initialized = manager.fileExists(atPath: marker.path)
            if !initialized {
                guard try manager.contentsOfDirectory(atPath: directory.path).isEmpty else {
                    throw DraftRepositoryError("STORAGE_UNAVAILABLE")
                }
                // A failed bootstrap remains marked; no subsequent empty reset.
                let fd = Darwin.open(marker.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
                guard fd >= 0 else { throw StorageFailure.filesystem(errno) }
                let sync = fsync(fd); let closed = Darwin.close(fd)
                guard sync == 0, closed == 0 else { throw StorageFailure.filesystem(errno) }
                try protect(marker)
                let parent = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY)
                guard parent >= 0 else { throw StorageFailure.filesystem(errno) }
                let parentSync = fsync(parent); let parentClose = Darwin.close(parent)
                guard parentSync == 0, parentClose == 0 else { throw StorageFailure.filesystem(errno) }
            }
            try protect(marker)
            let db = try initialized
                ? SQLiteDatabase.open(at: file, schema: Self.schema())
                : SQLiteDatabase.create(at: file, schema: Self.schema(datasetID: UUID().uuidString.lowercased()), fault: fault)
            do {
                for suffix in ["", "-wal", "-shm"] {
                    let path = URL(fileURLWithPath: file.path + suffix)
                    if manager.fileExists(atPath: path.path) { try protect(path) }
                }
                let dataset = try db.read { try Self.text($0.query("SELECT dataset_id FROM metadata").single()[0]) }
                let ready = DraftRepositorySession(sessionID: UUID().uuidString.lowercased(), datasetID: dataset, fileProtectionVerified: Self.deviceProtectionRequired)
                database = db; session = ready
                return ready
            } catch { try? db.close(); throw error }
        }
    }
    public func close(sessionID: String) throws {
        try run {
            let (db, _) = try connection(sessionID)
            session = nil
            try db.close(); database = nil
        }
    }
    public func freeze(sessionID: String, write: NativeDraftWrite) throws {
        try run {
            let (db, _) = try connection(sessionID)
            let payload = try Self.validatedPayload(write)
            try db.transaction { sql in
                let old = try sql.query("SELECT payload_hash,status FROM frozen_draft_commands WHERE command_id=?", [.text(write.commandID)])
                if let row = old.first {
                    guard try Self.text(row[0]) == write.payloadHash else { throw DraftRepositoryError("COMMAND_ID_REUSED") }
                    if try Self.text(row[1]) == "abandoned" { throw DraftRepositoryError("NOT_ELIGIBLE") }
                    return
                }
                try sql.execute("INSERT INTO frozen_draft_commands(command_id,draft_id,expected_revision,payload_hash,body,status) VALUES(?,?,?,?,?,'pending')", [
                    .text(write.commandID), .text(write.draftID), write.expectedRevision.map(SQLValue.integer) ?? .null,
                    .text(write.payloadHash), .text(payload),
                ])
            }
        }
    }
    public func commit(sessionID: String, commandID: String, payloadHash: String) throws -> NativeDraftReceipt {
        try run {
            let (db, session) = try connection(sessionID)
            try Self.identity(commandID, payloadHash)
            return try db.transaction { sql in
                if let receipt = try Self.receipt(sql, session.datasetID, commandID, payloadHash) { return receipt }
                let row = try Self.pendingRow(sql, commandID, payloadHash)
                let write = try Self.write(row, commandID: commandID, payloadHash: payloadHash)
                let prior = try sql.query("SELECT draft_id,revision,created_at FROM add_draft WHERE slot=1").first
                let revision: Int64
                let created: String
                let instant = Self.instant(now())
                if let prior {
                    guard try Self.text(prior[0]) == write.draftID else { throw DraftRepositoryError("DRAFT_CONFLICT") }
                    let oldRevision = try Self.integer(prior[1])
                    guard write.expectedRevision == oldRevision else { throw DraftRepositoryError("STALE_TARGET") }
                    guard oldRevision < Self.maximumRevision else { throw DraftRepositoryError("FIELD_INVALID") }
                    revision = oldRevision + 1; created = try Self.text(prior[2])
                } else {
                    guard write.expectedRevision == nil else { throw DraftRepositoryError("STALE_TARGET") }
                    revision = 1; created = instant
                }
                try sql.execute("INSERT INTO add_draft(slot,draft_id,revision,raw_fields,created_at,updated_at) VALUES(1,?,?,?,?,?) ON CONFLICT(slot) DO UPDATE SET revision=excluded.revision,raw_fields=excluded.raw_fields,updated_at=excluded.updated_at", [.text(write.draftID), .integer(revision), .text(write.rawFieldsCanonicalJSON), .text(created), .text(instant)])
                try sql.execute("INSERT INTO draft_receipts(command_id,payload_hash,draft_id,draft_revision,committed_at) VALUES(?,?,?,?,?)", [.text(commandID), .text(payloadHash), .text(write.draftID), .integer(revision), .text(instant)])
                guard try sql.execute("UPDATE frozen_draft_commands SET body=NULL,status='committed' WHERE command_id=? AND status='pending'", [.text(commandID)]) == 1 else { throw StorageFailure.integrityFailure }
                return NativeDraftReceipt(commandID: commandID, datasetID: session.datasetID, draftID: write.draftID, draftRevision: revision, replayed: false)
            }
        }
    }
    public func read(sessionID: String) throws -> NativeDraftRecord? {
        try run {
            let (db, _) = try connection(sessionID)
            return try db.read { sql in
                guard let row = try sql.query("SELECT draft_id,revision,raw_fields,created_at,updated_at FROM add_draft WHERE slot=1").first else { return nil }
                let fields = try Self.text(row[2]); try Self.validateFields(CanonicalParser.parse(fields, limit: 1_048_576))
                return NativeDraftRecord(draftID: try Self.text(row[0]), revision: try Self.integer(row[1]), rawFieldsCanonicalJSON: fields, createdAt: try Self.text(row[3]), updatedAt: try Self.text(row[4]))
            }
        }
    }
    public func resolve(sessionID: String, commandID: String, payloadHash: String) throws -> NativeDraftReceipt? {
        try run {
            let (db, session) = try connection(sessionID); try Self.identity(commandID, payloadHash)
            return try db.read { sql in
                let result = try Self.receipt(sql, session.datasetID, commandID, payloadHash)
                try Self.matchKnownHash(sql, commandID, payloadHash)
                return result
            }
        }
    }
    public func abandon(sessionID: String, commandID: String, payloadHash: String) throws -> NativeDraftReceipt? {
        try run {
            let (db, session) = try connection(sessionID); try Self.identity(commandID, payloadHash)
            return try db.transaction { sql in
                if let result = try Self.receipt(sql, session.datasetID, commandID, payloadHash) { return result }
                try Self.matchKnownHash(sql, commandID, payloadHash)
                guard try sql.execute("UPDATE frozen_draft_commands SET body=NULL,status='abandoned' WHERE command_id=?", [.text(commandID)]) == 1 else { throw DraftRepositoryError("NOT_FOUND") }
                return nil
            }
        }
    }
    public func pending(sessionID: String, after: String?) throws -> NativeDraftPage {
        try run {
            let (db, _) = try connection(sessionID)
            if let after { try Self.uuid(after) }
            return try db.read { sql in
                let rows = try sql.query("SELECT command_id,draft_id,expected_revision,payload_hash FROM frozen_draft_commands WHERE status='pending' AND command_id>? ORDER BY command_id LIMIT 201", [.text(after ?? "")])
                let items = try rows.prefix(200).map { row in
                    NativeDraftPending(commandID: try Self.text(row[0]), draftID: try Self.text(row[1]), expectedRevision: try Self.optionalInteger(row[2]), payloadHash: try Self.text(row[3]))
                }
                return NativeDraftPage(items: items, nextCursor: rows.count > 200 ? items.last?.commandID : nil)
            }
        }
    }
    public func getPending(sessionID: String, commandID: String, payloadHash: String) throws -> NativeDraftWrite {
        try run {
            let (db, _) = try connection(sessionID); try Self.identity(commandID, payloadHash)
            do {
                return try db.read { try Self.write(Self.pendingRow($0, commandID, payloadHash), commandID: commandID, payloadHash: payloadHash) }
            } catch let error as DraftRepositoryError where error.code == "NOT_ELIGIBLE" {
                throw DraftRepositoryError("NOT_FOUND")
            }
        }
    }

    private static func uuid(_ value: String) throws {
        guard UUID(uuidString: value)?.uuidString.lowercased() == value else { throw DraftRepositoryError("FIELD_INVALID") }
    }
    private static func identity(_ id: String, _ hash: String) throws {
        try uuid(id)
        guard hash.utf8.count == 64, hash.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { throw DraftRepositoryError("FIELD_INVALID") }
    }
    private static func validatedPayload(_ write: NativeDraftWrite) throws -> String {
        do {
            try identity(write.commandID, write.payloadHash); try uuid(write.draftID)
            if let revision = write.expectedRevision, !(1...maximumRevision).contains(revision) { throw DraftRepositoryError("FIELD_INVALID") }
            let fields = try CanonicalParser.parse(write.rawFieldsCanonicalJSON, limit: 1_048_576)
            try validateFields(fields)
            let payload: [String: CanonicalValue] = ["draftId": .string(write.draftID), "expectedRevision": write.expectedRevision.map(CanonicalValue.integer) ?? .null,
                "mode": .string("add"), "plantId": .null, "basePlantRevision": .null, "rawFields": fields, "photoIds": .array([])]
            let text = try CanonicalValue.object(payload).json()
            guard text.utf8.count <= 1_048_576 else { throw DraftRepositoryError("FIELD_INVALID") }
            guard try CanonicalCommand.commandHash(type: "SaveDraft", payload: payload) == write.payloadHash else { throw DraftRepositoryError("HASH_MISMATCH") }
            return text
        } catch let error as DraftRepositoryError { throw error }
        catch { throw DraftRepositoryError("FIELD_INVALID") }
    }
    private static func validateFields(_ value: CanonicalValue) throws {
        let keys: Set<String> = ["name", "location", "notes", "identityKind", "coverPhotoId", "speciesId", "catalogSelection", "customSpeciesName", "customLight", "customToxicity", "routineInputs", "baseRoutineRevisions", "speciesChoices"]
        guard let fields = value.object, Set(fields.keys) == keys,
              ["name", "location", "notes", "customSpeciesName"].allSatisfy({ fields[$0]?.units != nil }),
              fields["identityKind"]?.text == "custom",
              ["coverPhotoId", "speciesId", "catalogSelection"].allSatisfy({ fields[$0]?.isNull == true }),
              ["unknown", "low", "medium", "bright-indirect", "direct"].contains(fields["customLight"]?.text ?? ""),
              ["unknown", "toxic", "non-toxic"].contains(fields["customToxicity"]?.text ?? ""),
              fields["baseRoutineRevisions"]?.array?.isEmpty == true, fields["speciesChoices"]?.array?.isEmpty == true,
              let routines = fields["routineInputs"]?.array else { throw DraftRepositoryError("FIELD_INVALID") }
        for routine in routines {
            guard let row = routine.object, Set(row.keys) == ["kind", "count", "unit", "seed"],
                  ["water", "fertilize", "mist", "repot", "rotate"].contains(row["kind"]?.text ?? ""),
                  row["count"]?.units != nil, ["day", "week", "month", "year"].contains(row["unit"]?.text ?? "") else { throw DraftRepositoryError("FIELD_INVALID") }
            if row["seed"]?.isNull == true { continue }
            guard let seed = row["seed"]?.object else { throw DraftRepositoryError("FIELD_INVALID") }
            let dateKey: String
            switch seed["kind"]?.text { case "known": dateKey = "careDate"; case "unknown": dateKey = "firstCheckDate"; default: throw DraftRepositoryError("FIELD_INVALID") }
            guard Set(seed.keys) == ["kind", dateKey], seed[dateKey]?.units != nil else { throw DraftRepositoryError("FIELD_INVALID") }
        }
    }
    private static func pendingRow(_ sql: SQLiteSession, _ id: String, _ hash: String) throws -> [SQLValue] {
        let rows = try sql.query("SELECT draft_id,expected_revision,body,payload_hash,status FROM frozen_draft_commands WHERE command_id=?", [.text(id)])
        guard let row = rows.first else { throw DraftRepositoryError("NOT_FOUND") }
        guard try text(row[3]) == hash else { throw DraftRepositoryError("COMMAND_ID_REUSED") }
        guard try text(row[4]) == "pending" else { throw DraftRepositoryError("NOT_ELIGIBLE") }
        return row
    }
    private static func write(_ row: [SQLValue], commandID: String, payloadHash: String) throws -> NativeDraftWrite {
        let body = try text(row[2])
        guard let payload = try CanonicalParser.parse(body, limit: 1_048_576).object, let fields = payload["rawFields"] else { throw StorageFailure.integrityFailure }
        let write = NativeDraftWrite(commandID: commandID, draftID: try text(row[0]), expectedRevision: try optionalInteger(row[1]), rawFieldsCanonicalJSON: try fields.json(), payloadHash: payloadHash)
        guard try validatedPayload(write) == body else { throw StorageFailure.integrityFailure }
        return write
    }
    private static func matchKnownHash(_ sql: SQLiteSession, _ id: String, _ hash: String) throws {
        if let row = try sql.query("SELECT payload_hash FROM frozen_draft_commands WHERE command_id=?", [.text(id)]).first,
           try text(row[0]) != hash { throw DraftRepositoryError("COMMAND_ID_REUSED") }
    }
    private static func receipt(_ sql: SQLiteSession, _ dataset: String, _ id: String, _ hash: String) throws -> NativeDraftReceipt? {
        guard let row = try sql.query("SELECT payload_hash,draft_id,draft_revision FROM draft_receipts WHERE command_id=?", [.text(id)]).first else { return nil }
        guard try text(row[0]) == hash else { throw DraftRepositoryError("COMMAND_ID_REUSED") }
        return NativeDraftReceipt(commandID: id, datasetID: dataset, draftID: try text(row[1]), draftRevision: try integer(row[2]), replayed: true)
    }
    private static func text(_ value: SQLValue) throws -> String { guard case .text(let text) = value else { throw StorageFailure.integrityFailure }; return text }
    private static func integer(_ value: SQLValue) throws -> Int64 { guard case .integer(let n) = value else { throw StorageFailure.integrityFailure }; return n }
    private static func optionalInteger(_ value: SQLValue) throws -> Int64? { if case .null = value { return nil }; return try integer(value) }
    private static func instant(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter(); formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
    private static var deviceProtectionRequired: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    private func protect(_ url: URL) throws {
        #if os(iOS)
        _ = try DraftProtection.apply(deviceRequired: Self.deviceProtectionRequired, set: {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        }, read: {
            let value = try FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey]
            return (value as? FileProtectionType)?.rawValue ?? (value as? String)
        })
        #endif
    }
    private static let definitions: [String] = [
        "CREATE TABLE metadata(slot INTEGER PRIMARY KEY CHECK(slot=1),dataset_id TEXT NOT NULL UNIQUE,collection_revision INTEGER NOT NULL CHECK(collection_revision=1))",
        "CREATE TABLE add_draft(slot INTEGER PRIMARY KEY CHECK(slot=1),draft_id TEXT NOT NULL UNIQUE,revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),raw_fields TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)",
        "CREATE TABLE frozen_draft_commands(command_id TEXT PRIMARY KEY NOT NULL,draft_id TEXT NOT NULL,expected_revision INTEGER CHECK(expected_revision BETWEEN 1 AND 9007199254740991),payload_hash TEXT NOT NULL,body TEXT,status TEXT NOT NULL CHECK(status IN ('pending','committed','abandoned')),CHECK((status='pending' AND body IS NOT NULL) OR (status!='pending' AND body IS NULL)))",
        "CREATE TABLE draft_receipts(command_id TEXT PRIMARY KEY NOT NULL REFERENCES frozen_draft_commands(command_id),payload_hash TEXT NOT NULL,draft_id TEXT NOT NULL,draft_revision INTEGER NOT NULL CHECK(draft_revision BETWEEN 1 AND 9007199254740991),committed_at TEXT NOT NULL)",
    ]
    private static func schema(datasetID: String? = nil) -> CompiledSchema {
        CompiledSchema(applicationID: 0x56445246, version: 1, statements: definitions + (datasetID.map { ["INSERT INTO metadata VALUES(1,'\($0)',1)"] } ?? [])) { sql in
            let meta = try sql.query("SELECT slot,dataset_id,collection_revision FROM metadata").single()
            guard meta[0] == .integer(1), meta[2] == .integer(1) else { throw StorageFailure.integrityFailure }
            try uuid(text(meta[1]))
            let ddl = try sql.query("SELECT sql FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            guard try Set(ddl.map { try text($0[0]) }) == Set(definitions) else { throw StorageFailure.schemaMismatch }
        }
    }
}

private extension Array {
    func single() throws -> Element { guard count == 1 else { throw StorageFailure.integrityFailure }; return self[0] }
}

// Internal policy exercised with injected setters/readers, never a channel flag.
enum DraftProtection {
    static let requiredClass = "NSFileProtectionCompleteUntilFirstUserAuthentication"
    static func apply(deviceRequired: Bool, set: () throws -> Void, read: () throws -> String?) throws -> Bool {
        try set()
        let actual = try read()
        guard actual == requiredClass || (!deviceRequired && actual == nil) else { throw StorageFailure.unavailable }
        return deviceRequired
    }
}
