import Darwin
import Dispatch
import Foundation

struct CoreClockFrame {
    let today: String
    let instant: String
    let zone: String
    static func capture(_ date: Date, zone: TimeZone = .current) -> CoreClockFrame {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = zone; formatter.dateFormat = "yyyy-MM-dd"
        let iso = ISO8601DateFormatter(); iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return CoreClockFrame(today: formatter.string(from: date), instant: iso.string(from: date), zone: zone.identifier)
    }
    var value: CanonicalValue { .object(["today": .string(today), "instant": .string(instant), "zone": .string(zone)]) }
}
struct CorePreview { let command: String; let hash: String; let created: TimeInterval }
struct CoreUndoGrant {
    let acknowledgement: String
    let context: CanonicalValue
    var started: TimeInterval?
}

/// One serialized native owner for the permanent custom_core_v1 installation.
/// JSON envelopes contain bounded typed protocol values, never arbitrary SQL.
public final class CoreRepository {
    let directory: URL
    let queue = DispatchQueue(label: "verdi.native.core-repository")
    var database: SQLiteDatabase?
    var sessionID = ""
    var datasetID = ""
    var previews: [String: CorePreview] = [:]
    var grants: [String: CoreUndoGrant] = [:]
    let zone: () -> TimeZone
    let now: () -> Date
    let elapsed: () -> TimeInterval
    let fault: ((SQLiteBoundary) throws -> Void)?
    let catalogProvider: (() throws -> BundledCatalogBytes)?
    var catalogLimitation: String?
    public convenience init(directory: URL, catalog: (() throws -> BundledCatalogBytes)? = nil) { self.init(directory: directory, fault: nil, catalog:catalog) }
    init(directory: URL, fault: ((SQLiteBoundary) throws -> Void)?, now: @escaping () -> Date = Date.init,
         elapsed: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }, zone: @escaping () -> TimeZone = { .current }, catalog: (() throws -> BundledCatalogBytes)? = nil) {
        self.catalogProvider=catalog
        self.directory = directory; self.fault = fault; self.now = now; self.elapsed = elapsed; self.zone = zone
    }
    public func invalidateUndo() { queue.sync { grants.removeAll() } }
    public func call(operation: String, body: String) throws -> String {
        try queue.sync {
            do {
                let args = try CoreSchema.object(CanonicalParser.parse(body))
                if operation == "open" { return try open(args).json() }
                guard args["sessionId"]?.text == sessionID, let db = database, !sessionID.isEmpty else { throw CoreRepositoryError("SESSION_INVALID") }
                let value: CanonicalValue
                switch operation {
                case "close": try db.close(); database = nil; sessionID = ""; grants.removeAll(); previews.removeAll(); value = .null
                case "catalogMeta": value = try db.read {try catalogMeta($0)}
                case "catalogRows": value = try db.read {try catalogRows($0,args)}
                case "retryCatalog": tryCatalog(db); value = try db.read {try catalogMeta($0)}
                case "clock": value = CoreClockFrame.capture(now(), zone: zone()).value
                case "metadata": value = try db.read { try metadata($0) }
                case "readRows": value = try db.read { try readRows($0, args) }
                case "freeze": value = try db.transaction { try freeze($0, CoreSchema.object(args["intent"])) }
                case "preview": value = try preview(args, db)
                case "commit": value = try commit(args, db)
                case "resolve", "abandon":
                    let id = try CoreSchema.string(args["commandId"]); try CoreSchema.uuid(id)
                    let work: (SQLiteSession) throws -> CanonicalValue = { sql in
                        if let result = try self.receipt(sql, id, hash: args["payloadHash"]?.text) { return result }
                        let pending = try sql.query("SELECT status,hash FROM intents WHERE id=?", [.text(id)])
                        if pending.isEmpty {
                            if operation == "resolve" { return .null }
                            throw CoreRepositoryError("NOT_FOUND")
                        }
                        if let hash = args["payloadHash"]?.text, pending[0][1] != .text(hash) { throw CoreRepositoryError("COMMAND_ID_REUSED") }
                        if operation == "abandon" {
                            try sql.execute("UPDATE intents SET body=NULL,status='abandoned' WHERE id=? AND status='pending'", [.text(id)])
                            self.previews = self.previews.filter { $0.value.command != id }
                        }
                        return .null
                    }
                    value = try operation == "abandon" ? db.transaction(work) : db.read(work)
                case "pending": value = try db.read { try pending($0, args) }
                case "pendingBody": value = try db.read { sql in
                    let id = try CoreSchema.string(args["commandId"]); try CoreSchema.uuid(id)
                    guard let row = try sql.query("SELECT body FROM intents WHERE id=? AND status='pending'", [.text(id)]).first else { throw CoreRepositoryError("NOT_FOUND") }
                    return try CanonicalParser.parse(CoreSchema.text(row[0]))
                }
                case "acknowledge": value = try acknowledge(args, db)
                case "invalidateUndo": grants.removeAll(); value = .null
                default: throw CoreRepositoryError("PROTOCOL_INCOMPATIBLE")
                }
                return try value.json()
            } catch let failure as CoreRepositoryError { throw failure }
            catch StorageFailure.unknownOutcome { throw CoreRepositoryError("UNKNOWN_OUTCOME") }
            catch StorageFailure.sqlite(let code) where code & 255 == 5 { throw CoreRepositoryError("BUSY") }
            catch StorageFailure.sqlite(let code) where code & 255 == 13 { throw CoreRepositoryError("DISK_FULL") }
            catch is CanonicalParseFailure { throw CoreRepositoryError("PLAN_INVALID") }
            catch is CanonicalFailure { throw CoreRepositoryError("PLAN_LIMIT") }
            catch { throw CoreRepositoryError("STORAGE_UNAVAILABLE") }
        }
    }
    private func open(_ args: [String: CanonicalValue]) throws -> CanonicalValue {
        guard args["protocolVersion"]?.integer == 1, args["profile"]?.text == "custom_core_v1" else { throw CoreRepositoryError("PROTOCOL_INCOMPATIBLE") }
        sessionID = ""; previews.removeAll(); grants.removeAll()
        if let database { try database.close(); self.database = nil }
        let manager = FileManager.default, marker = directory.appendingPathComponent("initialized"), file = directory.appendingPathComponent("core.sqlite")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true); try protect(directory)
        let initialized = manager.fileExists(atPath: marker.path)
        if !initialized {
            guard try manager.contentsOfDirectory(atPath: directory.path).isEmpty else { throw CoreRepositoryError("STORAGE_UNAVAILABLE") }
            let fd = Darwin.open(marker.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard fd >= 0 else { throw StorageFailure.filesystem(errno) }
            let synced = fsync(fd), closed = Darwin.close(fd)
            guard synced == 0, closed == 0 else { throw StorageFailure.filesystem(errno) }
            let parent = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY)
            guard parent >= 0 else { throw StorageFailure.filesystem(errno) }
            let parentSync = fsync(parent), parentClose = Darwin.close(parent)
            guard parentSync == 0, parentClose == 0 else { throw StorageFailure.filesystem(errno) }
        }
        try protect(marker)
        let db = try initialized ? SQLiteDatabase.open(at: file, schema: CoreSchema.schema(), upgradeFrom: CoreSchema.schema(version:1), migrationStatements: CoreSchema.catalogDefinitions, fault:fault)
            : SQLiteDatabase.create(at: file, schema: CoreSchema.schema(dataset: UUID().uuidString.lowercased(), instant: CoreClockFrame.capture(now(), zone: zone()).instant), fault: fault)
        do {
            for suffix in ["", "-wal", "-shm"] {
                let path = URL(fileURLWithPath: file.path + suffix)
                if manager.fileExists(atPath: path.path) { try protect(path) }
            }
            datasetID = try db.read { try CoreSchema.text($0.query("SELECT dataset_id FROM metadata")[0][0]) }
            sessionID = UUID().uuidString.lowercased(); database = db
            tryCatalog(db)
            var result = try CoreSchema.object(db.read { try metadata($0) })
            result["sessionId"] = .string(sessionID); result["profile"] = .string("custom_core_v1"); result["schemaVersion"] = .integer(2)
            result["fileProtectionVerified"] = .boolean(Self.deviceProtectionRequired)
            result["clock"] = CoreClockFrame.capture(now(), zone: zone()).value; result["capabilityRevision"] = .integer(1); result["access"] = .string("free")
            return .object(result)
        } catch { try? db.close(); throw error }
    }
    func metadata(_ sql: SQLiteSession) throws -> CanonicalValue {
        let rows = try sql.query("SELECT dataset_id,collection_revision,storage_revision FROM metadata")
        guard rows.count == 1 else { throw StorageFailure.integrityFailure }
        return .object(["datasetId": CoreSchema.canonical(rows[0][0]), "collectionRevision": CoreSchema.canonical(rows[0][1]), "storageRevision": CoreSchema.canonical(rows[0][2])])
    }
    private func readRows(_ sql: SQLiteSession, _ args: [String: CanonicalValue]) throws -> CanonicalValue {
        let table = try CoreSchema.string(args["table"])
        guard let columns = CoreSchema.columns[table] else { throw CoreRepositoryError("FIELD_INVALID") }
        let meta = try CoreSchema.object(metadata(sql))
        guard try CoreSchema.same(meta["storageRevision"], args["storageRevision"]) else { throw CoreRepositoryError("READ_STALE") }
        let cursor = args["after"]?.text ?? ""
        if !cursor.isEmpty { try CoreSchema.uuid(cursor) }
        let rows = try sql.query("SELECT \(columns.joined(separator: ",")) FROM \(table) WHERE id>? ORDER BY id LIMIT 201", [.text(cursor)])
        var values: [CanonicalValue] = []; var bytes = 0
        for row in rows.prefix(200) {
            let value = CoreSchema.vector(row), size = try CanonicalCommand.bytes(value).count
            guard size <= 2 * 1024 * 1024 else { throw CoreRepositoryError("ROW_LIMIT") }
            if bytes + size > 2 * 1024 * 1024 { break }
            values.append(value); bytes += size
        }
        let next = values.count < rows.count ? values.last?.array?.first ?? .null : .null
        return .object(["rows": .array(values), "nextCursor": next])
    }
    private func freeze(_ sql: SQLiteSession, _ intent: [String: CanonicalValue]) throws -> CanonicalValue {
        let id = try CoreSchema.string(intent["commandId"]), type = try CoreSchema.string(intent["commandType"])
        try CoreSchema.uuid(id)
        guard CoreRegistry.commands.contains(type), intent["datasetId"]?.text == datasetID else { throw CoreRepositoryError("FIELD_INVALID") }
        let payload = try CoreSchema.object(intent["normalisedPayload"]), hash = try CoreSchema.string(intent["payloadHash"])
        guard try CanonicalCommand.bytes(.object(payload)).count <= 1_048_576,
              try CanonicalCommand.commandHash(type: type, payload: payload) == hash else { throw CoreRepositoryError("FIELD_INVALID") }
        try CoreRegistry.validatePayload(type,payload)
        let allocated = try CoreSchema.array(intent["allocatedIds"]).map { try CoreSchema.string($0) }
        guard allocated.count <= 10000, Set(allocated).count == allocated.count else { throw CoreRepositoryError("FIELD_INVALID") }
        for value in allocated { try CoreSchema.uuid(value) }
        let body = try CanonicalValue.object(intent).json()
        if let row = try sql.query("SELECT hash,body,status FROM intents WHERE id=?", [.text(id)]).first {
            guard row[0] == .text(hash), row[2] != .text("abandoned") else { throw CoreRepositoryError("COMMAND_ID_REUSED") }
            if row[2] == .text("pending"), row[1] != .text(body) { throw CoreRepositoryError("COMMAND_ID_REUSED") }
            return .null
        }
        for reserved in [id] + allocated {
            guard try sql.query("SELECT id FROM reservations WHERE id=?", [.text(reserved)]).isEmpty, reserved != datasetID else { throw CoreRepositoryError("COMMAND_ID_REUSED") }
            try sql.execute("INSERT INTO reservations VALUES(?,?,?,0)", [.text(reserved), .text(reserved == id ? "command" : "entity"), .text(id)])
        }
        if type == "SaveDraft" {
            let draft = try CoreSchema.string(payload["draftId"]); try CoreSchema.uuid(draft)
            let prior = try sql.query("SELECT kind FROM reservations WHERE id=?", [.text(draft)])
            if prior.isEmpty {
                guard draft != datasetID else { throw CoreRepositoryError("FIELD_INVALID") }
                try sql.execute("INSERT INTO reservations VALUES(?,'draft',?,0)", [.text(draft), .text(id)])
            } else if prior[0][0] != .text("draft") { throw CoreRepositoryError("FIELD_INVALID") }
        }
        try sql.execute("INSERT INTO intents VALUES(?,?,?,?,'pending')", [.text(id), .text(type), .text(hash), .text(body)])
        return .null
    }
    func receipt(_ sql: SQLiteSession, _ id: String, hash: String?) throws -> CanonicalValue? {
        guard let row = try sql.query("SELECT hash,result FROM receipts WHERE id=?", [.text(id)]).first else { return nil }
        if let hash, row[0] != .text(hash) { throw CoreRepositoryError("COMMAND_ID_REUSED") }
        var result = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[1])))
        result["replayed"] = .boolean(true)
        return .object(result)
    }
    private func pending(_ sql: SQLiteSession, _ args: [String: CanonicalValue]) throws -> CanonicalValue {
        let cursor = args["after"]?.text ?? ""; if !cursor.isEmpty { try CoreSchema.uuid(cursor) }
        let rows = try sql.query("SELECT id,type,hash FROM intents WHERE status='pending' AND id>? ORDER BY id LIMIT 201", [.text(cursor)])
        return .object(["items": .array(rows.prefix(200).map { .object(["commandId":CoreSchema.canonical($0[0]),"commandType":CoreSchema.canonical($0[1]),"payloadHash":CoreSchema.canonical($0[2])]) }),
            "nextCursor": rows.count > 200 ? CoreSchema.canonical(rows[199][0]) : .null])
    }
    private func preview(_ args: [String: CanonicalValue], _ db: SQLiteDatabase) throws -> CanonicalValue {
        let plan = try CoreSchema.object(args["plan"]); let parsed = try CoreRegistry.parse(plan, session: sessionID, dataset: datasetID)
        guard CoreRegistry.needsPreview(parsed.type) else { throw CoreRepositoryError("PLAN_INVALID") }
        try db.read { sql in _ = try CoreRegistry.validate(sql, parsed, clock: CoreClockFrame.capture(now(), zone: zone()), grants: grants, elapsed: elapsed()) }
        if previews.count >= 128, let oldest = previews.min(by: { $0.value.created < $1.value.created })?.key { previews.removeValue(forKey: oldest) }
        let token = UUID().uuidString.lowercased()
        previews[token] = CorePreview(command: parsed.id, hash: parsed.hash, created: elapsed())
        return .object(["previewToken": .string(token),"expiresAt": .string(CoreClockFrame.capture(now().addingTimeInterval(600), zone: zone()).instant)])
    }
    private func commit(_ args: [String: CanonicalValue], _ db: SQLiteDatabase) throws -> CanonicalValue {
        let parsed = try CoreRegistry.parse(CoreSchema.object(args["plan"]), session: sessionID, dataset: datasetID)
        var undo: CanonicalValue?
        let result = try db.transaction { sql -> CanonicalValue in
            if let replay = try receipt(sql, parsed.id, hash: parsed.payloadHash) { return replay }
            let clock = CoreClockFrame.capture(now(), zone: zone())
            if CoreRegistry.needsPreview(parsed.type) {
                guard let token = parsed.body["previewToken"]?.text, let p = previews[token], p.command == parsed.id, p.hash == parsed.hash,
                      elapsed() >= p.created, elapsed() - p.created < 600 else { throw CoreRepositoryError("PREVIEW_STALE") }
            }
            let changes = try CoreRegistry.validate(sql, parsed, clock: clock, grants: grants, elapsed: elapsed())
            undo = try CoreRegistry.captureUndo(sql, parsed, changes)
            try CoreRegistry.apply(sql, parsed, changes)
            let content = !["SaveDraft","DiscardDraft"].contains(parsed.type)
            try sql.execute("UPDATE metadata SET collection_revision=collection_revision+?,storage_revision=storage_revision+1 WHERE slot=1", [.integer(content ? 1 : 0)])
            if content { try sql.execute("INSERT INTO outbox SELECT 1,collection_revision FROM metadata WHERE slot=1 ON CONFLICT(slot) DO UPDATE SET dirty_revision=excluded.dirty_revision") }
            try CoreRegistry.validateResult(sql, parsed, changes)
            let result = parsed.body["result"]!
            try sql.execute("INSERT INTO receipts VALUES(?,?,?,?,0)", [.text(parsed.id),.text(parsed.payloadHash),.text(try result.json()),try undo.map { .text(try $0.json()) } ?? .null])
            try sql.execute("UPDATE intents SET body=NULL,status='committed' WHERE id=?", [.text(parsed.id)])
            try sql.execute("UPDATE reservations SET used=1 WHERE command_id=?", [.text(parsed.id)])
            if parsed.type == "SaveDraft" { try sql.execute("UPDATE reservations SET used=1 WHERE id=?", [.text(try CoreSchema.string(parsed.payload["draftId"]))]) }
            if parsed.type == "Undo" { try sql.execute("UPDATE receipts SET undone=1,undo_context=NULL WHERE id=?", [.text(try CoreSchema.string(parsed.payload["originalCommandId"]))]) }
            return result
        }
        var ack: CanonicalValue = .null
        if let undo, parsed.type != "Undo" {
            let id = UUID().uuidString.lowercased(); grants[parsed.id] = CoreUndoGrant(acknowledgement: id, context: undo)
            ack = .string(id)
        }
        if parsed.type == "Undo", let original = parsed.payload["originalCommandId"]?.text { grants.removeValue(forKey: original) }
        if parsed.type == "DeletePlant", let plant = parsed.payload["plantId"]?.text {
            grants = grants.filter { _, grant in
                grant.context.object?["members"]?.array?.contains(where: { $0.object?["plantId"]?.text == plant }) != true
            }
            previews.removeAll()
        }
        return .object(["result":result,"acknowledgementId":ack])
    }
    private func acknowledge(_ args: [String: CanonicalValue], _ db: SQLiteDatabase) throws -> CanonicalValue {
        let id = try CoreSchema.string(args["commandId"])
        guard var grant = grants[id], args["acknowledgementId"]?.text == grant.acknowledgement else { return .null }
        do { try db.read { try CoreRegistry.checkUndoMembers($0, grant.context) } } catch { grants.removeValue(forKey:id); return .null }
        let time = elapsed()
        if grant.started == nil { grant.started = time; grants[id] = grant }
        guard let start = grant.started, time >= start, time - start < 8 else { return .null }
        return .object(["expiresInMilliseconds":.integer(Int64((8 - (time - start)) * 1000))])
    }
    static var deviceProtectionRequired: Bool {
        #if os(iOS) && !targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }
    private func protect(_ url: URL) throws {
        #if os(iOS)
        _ = try DraftProtection.apply(deviceRequired: Self.deviceProtectionRequired, set: {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath:url.path)
        }, read: {
            let value = try FileManager.default.attributesOfItem(atPath:url.path)[.protectionKey]
            return (value as? FileProtectionType)?.rawValue ?? (value as? String)
        })
        #endif
    }
}
