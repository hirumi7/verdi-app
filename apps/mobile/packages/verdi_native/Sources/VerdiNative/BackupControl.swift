import Foundation
import Darwin
import CryptoKit

enum BackupBoundary { case bootstrapRecord, bootstrapDatabase, bootstrapPublished, snapshot, staged, prepared, switched, verified }

enum BackupControlWrite { case prepare, switchPointer, verify, rollback }

/// One installation pointer; no content transaction spans two SQLite databases.
final class BackupControl {
    let legacy: URL, root: URL, generations: URL, db: SQLiteDatabase
    let fault: ((BackupBoundary) throws -> Void)?
    let io: BackupFileIO
    let transactionFault: ((BackupControlWrite, SQLiteBoundary) throws -> Void)?
    static let definitions = [
        "CREATE TABLE artifacts(kind TEXT NOT NULL,key TEXT NOT NULL,owner TEXT,expires TEXT NOT NULL,PRIMARY KEY(kind,key))",
        "CREATE TABLE pointer(slot INTEGER PRIMARY KEY CHECK(slot=1),active TEXT NOT NULL,legacy TEXT NOT NULL)",
        "CREATE TABLE generations(id TEXT PRIMARY KEY NOT NULL,dataset TEXT NOT NULL,legacy INTEGER NOT NULL CHECK(legacy IN (0,1)))",
        "CREATE TABLE jobs(id TEXT PRIMARY KEY NOT NULL,request_hash TEXT NOT NULL,kind TEXT NOT NULL,created TEXT NOT NULL,updated TEXT NOT NULL,state_json TEXT NOT NULL,source_hash TEXT,new_generation TEXT,preview_json TEXT)",
        "CREATE TABLE replacement(slot INTEGER PRIMARY KEY CHECK(slot=1),job TEXT NOT NULL,old_generation TEXT NOT NULL,new_generation TEXT NOT NULL,phase TEXT NOT NULL CHECK(phase IN ('prepared','switched','verified','rolled_back')),db_hash TEXT NOT NULL,media_hash TEXT NOT NULL)",
    ]
    static var schema: CompiledSchema {
        CompiledSchema(applicationID:0x56424332,version:1,statements:definitions) { sql in
            let definitions = try sql.query("SELECT sql FROM sqlite_schema WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'").map {try CoreSchema.text($0[0])}
            try BackupIO.require(Set(definitions) == Set(Self.definitions),"STORAGE_UNAVAILABLE")
            let rows = try sql.query("SELECT active,legacy FROM pointer")
            if !rows.isEmpty {try BackupIO.require(rows.count == 1,"STORAGE_UNAVAILABLE");for value in rows[0] {try CoreSchema.uuid(CoreSchema.text(value))}}
        }
    }
    static func location(_ legacy:URL) -> URL {legacy.deletingLastPathComponent().appendingPathComponent(legacy.lastPathComponent+"-recovery")}
    static func exists(_ legacy:URL) -> Bool {FileManager.default.fileExists(atPath:location(legacy).appendingPathComponent("control.sqlite").path)}
    static func requiresRecovery(_ legacy:URL) -> Bool {FileManager.default.fileExists(atPath:location(legacy).appendingPathComponent("established").path)}
    init(legacy:URL, dataset:String? = nil, fault:((BackupBoundary)throws->Void)? = nil, transactionFault:((BackupControlWrite,SQLiteBoundary)throws->Void)? = nil, io:BackupFileIO = BackupFileIO()) throws {
        self.legacy = legacy; root = Self.location(legacy)
        generations = legacy.deletingLastPathComponent().appendingPathComponent(legacy.lastPathComponent+"-generations")
        self.io = io; self.fault = fault; self.transactionFault = transactionFault
        try BackupIO.directory(root,io:io);try BackupIO.directory(generations,io:io)
        let target = root.appendingPathComponent("control.sqlite"), marker = root.appendingPathComponent("established"), record = root.appendingPathComponent("bootstrap.json"), staging = root.appendingPathComponent("control.pending")
        if FileManager.default.fileExists(atPath:target.path) {
            db = try SQLiteDatabase.open(at:target,schema:Self.schema,controlProfile:true)
        } else {
            try BackupIO.require(!FileManager.default.fileExists(atPath:marker.path),"STORAGE_UNAVAILABLE")
            guard let dataset else {throw CoreRepositoryError("STORAGE_UNAVAILABLE")};try CoreSchema.uuid(dataset)
            let generation: String
            if FileManager.default.fileExists(atPath:record.path) {
                let input = try BackupJSONReader(record,limit:4096), value = try CoreSchema.object(input.value());try input.end()
                try BackupIO.require(Set(value.keys) == Set(["dataset","generation"]) && value["dataset"]?.text == dataset,"STORAGE_UNAVAILABLE")
                generation = try CoreSchema.string(value["generation"]);try CoreSchema.uuid(generation)
                // These exact private staging files are never an active collection.
                for suffix in ["","-journal","-wal","-shm"] {
                    let path = URL(fileURLWithPath:staging.path+suffix)
                    if FileManager.default.fileExists(atPath:path.path) {try FileManager.default.removeItem(at:path)}
                }
            } else {
                generation = UUID().uuidString.lowercased()
                let pendingRecord=root.appendingPathComponent("bootstrap.pending")
                if FileManager.default.fileExists(atPath:pendingRecord.path) {try FileManager.default.removeItem(at:pendingRecord)}
                let writer = try BackupWriter(pendingRecord,limit:4096,io:io)
                try writer.write(CanonicalValue.object(["dataset":.string(dataset),"generation":.string(generation)]).json());try writer.finish()
                try io.renameExclusive(pendingRecord,to:record)
            }
            try fault?(.bootstrapRecord)
            let staged = try SQLiteDatabase.create(at:staging,schema:Self.schema,controlProfile:true)
            try staged.transaction { sql in
                try sql.execute("INSERT INTO generations VALUES(?,?,1)",[.text(generation),.text(dataset)])
                try sql.execute("INSERT INTO pointer VALUES(1,?,?)",[.text(generation),.text(generation)])
            }
            try staged.close();try BackupIO.flush(staging,io:io);try fault?(.bootstrapDatabase)
            try io.renameExclusive(staging,to:target);try fault?(.bootstrapPublished)
            db = try SQLiteDatabase.open(at:target,schema:Self.schema,controlProfile:true)
        }
        if !FileManager.default.fileExists(atPath:marker.path) {
            let writer = try BackupWriter(marker,limit:32,io:io);try writer.write("verdi-control-v1");try writer.finish()
        }
        try BackupIO.protect(target)
        try validatePointer()
    }
    deinit {try? db.close()}
    func recoverConnection() throws {
        try db.recoverControlConnection(at:root.appendingPathComponent("control.sqlite"),schema:Self.schema)
        try validatePointer()
    }
    func validatePointer() throws {
        try db.read { sql in
            let rows = try sql.query("SELECT p.active,p.legacy,g.legacy FROM pointer p JOIN generations g ON g.id=p.active")
            try BackupIO.require(rows.count == 1,"STORAGE_UNAVAILABLE")
            let legacyRows = try sql.query("SELECT id FROM generations WHERE legacy=1")
            try BackupIO.require(legacyRows.count == 1 && legacyRows[0][0] == rows[0][1],"STORAGE_UNAVAILABLE")
        }
    }
    func generationURL(_ id:String) throws -> URL {
        try CoreSchema.uuid(id)
        let rows = try db.read {try $0.query("SELECT legacy FROM generations WHERE id=?",[.text(id)])}
        try BackupIO.require(rows.count == 1,"STORAGE_UNAVAILABLE")
        return rows[0][0] == .integer(1) ? legacy : generations.appendingPathComponent(id)
    }
    func activeID() throws -> String {try db.read {try CoreSchema.text($0.query("SELECT active FROM pointer")[0][0])}}
    func activeURL() throws -> URL {try generationURL(activeID())}
    /// Registered content is never a fresh installation, even if its directory vanished.
    func requireStorage(_ id:String) throws {
        let root = try generationURL(id)
        for (url, kind) in [(root, S_IFDIR), (root.appendingPathComponent("initialized"), S_IFREG), (root.appendingPathComponent("core.sqlite"), S_IFREG)] {
            var info = stat()
            try BackupIO.require(lstat(url.path, &info) == 0 && (info.st_mode & S_IFMT) == kind,"STORAGE_UNAVAILABLE")
        }
    }
    func expectedDataset(_ generation:String) throws -> String {
        let expected = try db.read {try $0.query("SELECT dataset FROM generations WHERE id=?",[.text(generation)])}
        try BackupIO.require(expected.count == 1,"STORAGE_UNAVAILABLE")
        let dataset = try CoreSchema.text(expected[0][0]);try CoreSchema.uuid(dataset)
        return dataset
    }
    func jobRoot(_ id:String) throws -> URL {try CoreSchema.uuid(id);let url = root.appendingPathComponent("jobs").appendingPathComponent(id);try BackupIO.directory(url,io:io,relativeTo:root);return url}
    func registerArtifact(kind:String,key:String,owner:String?,expires:String) throws {
        try CoreSchema.uuid(key);if let owner {try CoreSchema.uuid(owner)}
        try BackupIO.require(["selection","job","staging"].contains(kind),"FIELD_INVALID")
        try db.transaction {try $0.execute("INSERT OR IGNORE INTO artifacts VALUES(?,?,?,?)",[.text(kind),.text(key),owner.map(SQLValue.text) ?? .null,.text(expires)])}
    }
    func artifactURL(kind:String,key:String) throws -> URL {
        try CoreSchema.uuid(key)
        switch kind {
        case "selection":return root.appendingPathComponent("selections").appendingPathComponent(key+".zip")
        case "job":return root.appendingPathComponent("jobs").appendingPathComponent(key)
        case "staging":return generations.appendingPathComponent(key)
        default:throw CoreRepositoryError("STORAGE_UNAVAILABLE")
        }
    }
    func operation(_ id:String) throws -> CanonicalValue {
        try db.read {sql in
            guard let row = try sql.query("SELECT kind,created,updated,state_json FROM jobs WHERE id=?",[.text(id)]).first else {throw CoreRepositoryError("NOT_FOUND")}
            return .object(["operationId":.string(id),"createdAt":CoreSchema.canonical(row[1]),"updatedAt":CoreSchema.canonical(row[2]),"operation":.object(["kind":CoreSchema.canonical(row[0]),"state":try CanonicalParser.parse(CoreSchema.text(row[3]))])])
        }
    }
    func latest() throws -> CanonicalValue {
        guard let row = try db.read({try $0.query("SELECT id FROM jobs ORDER BY rowid DESC LIMIT 1").first}) else {return .null}
        return try operation(CoreSchema.text(row[0]))
    }
    func update(_ id:String, _ state:CanonicalValue, at:String) throws {
        try db.transaction {try $0.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try state.json()),.text(at),.text(id)])}
    }
    func prepare(job:String,new:String,dataset:String,dbHash:String,mediaHash:String,at:String) throws {
        let old = try activeID()
        try db.transaction(fault:{try self.transactionFault?(.prepare,$0)}) { sql in
            try sql.execute("INSERT INTO generations VALUES(?,?,0)",[.text(new),.text(dataset)])
            try sql.execute("INSERT OR REPLACE INTO replacement VALUES(1,?,?,?,'prepared',?,?)",[.text(job),.text(old),.text(new),.text(dbHash),.text(mediaHash)])
            try sql.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try CanonicalValue.object(["kind":.string("prepared"),"cancelAllowed":.boolean(false)]).json()),.text(at),.text(job)])
        }
        try fault?(.prepared)
    }
    func switchPointer(at:String) throws {
        try db.transaction(fault:{try self.transactionFault?(.switchPointer,$0)}) {sql in
            let r = try sql.query("SELECT job,new_generation FROM replacement WHERE phase='prepared'")
            try BackupIO.require(r.count == 1,"STORAGE_UNAVAILABLE")
            try sql.execute("UPDATE pointer SET active=? WHERE slot=1",[r[0][1]])
            try sql.execute("UPDATE replacement SET phase='switched' WHERE slot=1")
            try sql.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try CanonicalValue.object(["kind":.string("verifying"),"cancelAllowed":.boolean(false)]).json()),.text(at),r[0][0]])
        }
        try fault?(.switched)
    }
    /// Startup never guesses newest directory. Verified stores use normal recovery.
    func recover(at:String) throws {
        try recoverConnection()
        guard let r = try db.read({try $0.query("SELECT job,old_generation,new_generation,phase,db_hash,media_hash FROM replacement").first}) else {return}
        let phase = try CoreSchema.text(r[3]);if ["verified","rolled_back"].contains(phase) {return}
        let job = try CoreSchema.text(r[0]), old = try CoreSchema.text(r[1]), new = try CoreSchema.text(r[2])
        if phase == "prepared" {
            try BackupIO.require(try activeID() == old,"STORAGE_UNAVAILABLE")
            try verifyOrdinary(old)
            try db.transaction(fault:{try self.transactionFault?(.rollback,$0)}) {sql in
                try sql.execute("UPDATE replacement SET phase='rolled_back'")
                try sql.execute("DELETE FROM generations WHERE id=? AND legacy=0",[.text(new)])
                try sql.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try Self.failure(code:"IO_FAILURE",dataset:nil,recovery:"open_recovery",preserved:true).json()),.text(at),.text(job)])
            }
            return
        }
        try BackupIO.require(try activeID() == new,"STORAGE_UNAVAILABLE")
        let root = try generationURL(new)
        do {
            try requireStorage(new)
            try BackupIO.require(try BackupIO.hash(root.appendingPathComponent("core.sqlite")).0 == CoreSchema.text(r[4]),"BACKUP_HASH_MISMATCH")
            let opened = try SQLiteDatabase.open(at:root.appendingPathComponent("core.sqlite"),schema:CoreSchema.schema(expectedDataset:expectedDataset(new)))
            let content: (String,CanonicalValue)
            do {
                try BackupIO.require(try Self.mediaHash(opened,root:root) == CoreSchema.text(r[5]),"BACKUP_HASH_MISMATCH")
                content = (try opened.read {try CoreSchema.text($0.query("SELECT dataset_id FROM metadata")[0][0])},try BackupContent.counts(opened))
                try opened.close()
            } catch {try? opened.close();throw error}
            try db.transaction(fault:{try self.transactionFault?(.verify,$0)}) { sql in
                try sql.execute("UPDATE replacement SET phase='verified'")
                let state:CanonicalValue = .object(["kind":.string("complete"),"datasetId":.string(content.0),"counts":content.1,"notice":.null])
                try sql.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try state.json()),.text(at),.text(job)])
            }
            try fault?(.verified)
        } catch {
            // A failed verification may only select an independently valid old store.
            try recoverConnection()
            if try db.read({try $0.query("SELECT phase FROM replacement")[0][0]}) == .text("verified") {throw error}
            try verifyOrdinary(old)
            try db.transaction(fault:{try self.transactionFault?(.rollback,$0)}) {sql in
                try sql.execute("UPDATE pointer SET active=?",[.text(old)])
                try sql.execute("UPDATE replacement SET phase='rolled_back'")
                try sql.execute("DELETE FROM generations WHERE id=? AND legacy=0",[.text(new)])
                try sql.execute("UPDATE jobs SET state_json=?,updated=? WHERE id=?",[.text(try Self.failure(code:"STORAGE_UNAVAILABLE",dataset:nil,recovery:"open_recovery",preserved:true).json()),.text(at),.text(job)])
            }
        }
    }
    func verifyOrdinary(_ generation:String) throws {
        try requireStorage(generation)
        let root = try generationURL(generation)
        let opened = try CoreRepository.openDatabase(root.appendingPathComponent("core.sqlite"),expectedDataset:expectedDataset(generation))
        try opened.close()
    }
    static func failure(code:String,dataset:String?,recovery:String,preserved:Bool) -> CanonicalValue {
        .object(["kind":.string("failed"),"code":.string(code),"activeDatasetId":dataset.map(CanonicalValue.string) ?? .null,"recovery":.string(recovery),"oldDatasetPreserved":.boolean(preserved)])
    }
    static func mediaHash(_ db:SQLiteDatabase,root:URL) throws -> String {
        let files = try MediaFiles(root:root);var hash = SHA256()
        try db.read {sql in
            var cursor = ""
            while let row = try sql.query("SELECT relative_path FROM media_files WHERE relative_path>? ORDER BY relative_path LIMIT 1",[.text(cursor)]).first {
                cursor = try CoreSchema.text(row[0]);try BackupIO.canonicalMedia(cursor)
                let info = try files.inspect(cursor)
                hash.update(data:try CanonicalCommand.bytes(.array([.string(cursor),.string(info.hash),.integer(info.bytes)])))
            }
        }
        return hash.finalize().map {String(format:"%02x",$0)}.joined()
    }
}
