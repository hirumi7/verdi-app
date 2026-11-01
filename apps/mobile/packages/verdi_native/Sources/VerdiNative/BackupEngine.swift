import Foundation
import CryptoKit
import Darwin

final class BackupEngine {
    unowned let core: CoreRepository
    let worker = DispatchQueue(label:"verdi.native.backup",qos:.userInitiated)
    private let lock = NSLock()
    private var running: String?, cancelled = Set<String>()
    private var selections: [String:(URL,Date)] = [:]
    private var handles: [String:(String,Date)] = [:]
    private var shared = Set<String>()
    private var pendingFailures: [String:(String,Error)] = [:]
    private var cleanupScheduled = false
    private var deleting = Set<String>()
    var cleanupClaimed: ((String) -> Void)?
    var failureWriteFault: (() throws -> Void)?
    init(core:CoreRepository) {self.core=core}
    func withLock<T>(_ body:() throws -> T) rethrows -> T {lock.lock();defer{lock.unlock()};return try body()}
    func clock() -> String {CoreClockFrame.capture(core.now(),zone:core.zone()).instant}
    func control() throws -> BackupControl {try core.queue.sync {try core.control()}}
    func check(_ id:String) throws {try withLock {if cancelled.contains(id) {throw CoreRepositoryError("BACKUP_CANCELLED")}}}
    func state(_ id:String,_ value:CanonicalValue,_ control:BackupControl) throws {try control.update(id,value,at:clock())}
    func progress(_ kind:String) -> CanonicalValue {.object(["kind":.string(kind),"completedBytes":.integer(0),"totalBytes":.null])}
    func recoverInterrupted(_ control:BackupControl) throws {
        if withLock({running != nil}) {return}
        var cursor = ""
        while let row = try control.db.read({try $0.query("SELECT id,kind,state_json FROM jobs WHERE id>? ORDER BY id LIMIT 1",[.text(cursor)]).first}) {
            cursor = try CoreSchema.text(row[0]);let kind=try CoreSchema.text(row[1]), current=try CanonicalParser.parse(CoreSchema.text(row[2])).object?["kind"]?.text
            if ["preparing","writing","validating","selected","staging","preview_ready"].contains(current) {
                let failed:CanonicalValue = kind == "export" ? .object(["kind":.string("failed"),"code":.string("IO_FAILURE"),"retry":.string("start_new_export")]) : BackupControl.failure(code:"IO_FAILURE",dataset:nil,recovery:"retry_validation",preserved:true)
                try state(cursor,failed,control)
            }
        }
    }
    func retainSelection(_ source:URL) throws -> String {
        let control = try control(), id = UUID().uuidString.lowercased(), root = control.root.appendingPathComponent("selections")
        try BackupIO.directory(root,io:core.backupFileIO,relativeTo:control.root);try BackupIO.excludeFromOSBackup(root)
        try control.registerArtifact(kind:"selection",key:id,owner:nil,expires:expiry())
        let size=try BackupIO.size(source);try BackupIO.require(size > 0 && size <= BackupIO.archiveLimit,"BACKUP_LIMIT")
        try BackupIO.reserve(at:root,additional:size)
        let destination=root.appendingPathComponent(id+".zip")
        try BackupIO.copy(source,to:destination,limit:BackupIO.archiveLimit,io:core.backupFileIO)
        withLock {selections[id]=(destination,core.now().addingTimeInterval(600))};return id
    }
    func call(_ method:String,_ request:String) throws -> String {
        try BackupIO.require(request.utf8.count <= 65536,"BACKUP_LIMIT")
        let args=try CoreSchema.object(CanonicalParser.package(request)), control=try control()
        try persistFailures(control)
        scheduleCleanup(control)
        func exact(_ keys:Set<String>) throws {try BackupIO.require(Set(args.keys)==keys,"FIELD_INVALID")}
        if method == "latestBackupOperation" {try exact([]);return try control.latest().json()}
        let id=try CoreSchema.string(args["operationId"]);try CoreSchema.uuid(id)
        switch method {
        case "startExport","startImport":
            try exact(method == "startExport" ? ["operationId","datasetId"] : ["operationId","selectionHandle"])
            let hash=try CanonicalCommand.hash(.object(args))
            if let previous=try control.db.read({try $0.query("SELECT request_hash FROM jobs WHERE id=?",[.text(id)]).first}) {
                try BackupIO.require(previous[0] == .text(hash),"COMMAND_ID_REUSED");return try control.operation(id).json()
            }
            var cursor=""
            while let row=try control.db.read({try $0.query("SELECT id,state_json FROM jobs WHERE id>? ORDER BY id LIMIT 1",[.text(cursor)]).first}) {
                cursor=try CoreSchema.text(row[0])
                let phase=try CanonicalParser.parse(CoreSchema.text(row[1])).object?["kind"]?.text
                try BackupIO.require(!["preparing","writing","validating","selected","staging","preview_ready","prepared","switching","verifying"].contains(phase),"BUSY")
            }
            let kind=method == "startExport" ? "export":"import"
            try withLock {try BackupIO.require(running==nil && shared.isEmpty && !deleting.contains(id),"BUSY");running=id}
            do {
                if kind == "export" {try core.queue.sync {try BackupIO.require(args["datasetId"]?.text == core.datasetID,"DATASET_CHANGED")}}
                try control.registerArtifact(kind:"job",key:id,owner:id,expires:expiry())
                let jobDirectory=try control.jobRoot(id);try BackupIO.excludeFromOSBackup(jobDirectory)
                let time=clock()
                try control.db.transaction {try $0.execute("INSERT INTO jobs VALUES(?,?,?,?,?,?,NULL,NULL,NULL)",[.text(id),.text(hash),.text(kind),.text(time),.text(time),.text(try progress(kind == "export" ? "preparing":"selected").json())])}
                if kind == "import" {
                    let handle=try CoreSchema.string(args["selectionHandle"])
                    let source=try withLock { () throws -> URL in
                        guard let selected=selections[handle], selected.1>core.now() else{throw CoreRepositoryError("SELECTION_EXPIRED")}
                        return selected.0
                    }
                    let selection = source.deletingPathExtension().lastPathComponent
                    try CoreSchema.uuid(selection)
                    // Bind native inventory before moving the file. The same job
                    // can then resume either side of a failed/uncertain rename.
                    try control.db.transaction {sql in
                        try BackupIO.require(try sql.query("SELECT key FROM artifacts WHERE kind='selection' AND key=? AND owner IS NULL",[.text(selection)]).count == 1,"SELECTION_EXPIRED")
                        try sql.execute("UPDATE artifacts SET owner=? WHERE kind='selection' AND key=?",[.text(id),.text(selection)])
                    }
                    withLock{_ = selections.removeValue(forKey:handle)}
                }
                dispatch(id,kind:kind,control:control) {
                    if kind == "export" {try self.export(id,control:control)} else {try self.validateImport(id,control:control)}
                }
            } catch {
                let original=error
                defer{withLock{running=nil}}
                do {
                    if try control.db.read({try $0.query("SELECT id FROM jobs WHERE id=?",[.text(id)]).first}) != nil {
                        try fail(id,kind:kind,error:original,control:control)
                    }
                } catch {withLock{pendingFailures[id]=(kind,original)}}
                throw original
            }
        case "backupStatus":try exact(["operationId"])
        case "cancelBackup":
            try exact(["operationId"])
            let operation=try control.operation(id), current=operation.object?["operation"]?.object?["state"]?.object?["kind"]?.text
            if ["prepared","switching","verifying","complete"].contains(current) {break}
            if withLock({running==id}) {withLock{_ = cancelled.insert(id)}}
            else if current == "preview_ready" || current == "failed" {
                let kind=operation.object?["operation"]?.object?["kind"]?.text
                try state(id,kind == "import" ? .object(["kind":.string("cancelled"),"oldDatasetPreserved":.boolean(true)]) : .object(["kind":.string("cancelled"),"fileCreated":.boolean(false)]),control)
            }
        case "retryImport":
            try exact(["operationId"])
            let operation=try control.operation(id)
            try BackupIO.require(operation.object?["operation"]?.object?["kind"]?.text == "import" && operation.object?["operation"]?.object?["state"]?.object?["kind"]?.text == "failed","NOT_ELIGIBLE")
            try withLock {try BackupIO.require(running==nil && shared.isEmpty && !deleting.contains(id),"BUSY");running=id;cancelled.remove(id)}
            // Publish an in-progress state before returning; otherwise a polling
            // client can see the old failure and stop watching a running retry.
            do {try state(id,progress("validating"),control)} catch {withLock{running=nil};throw error}
            dispatch(id,kind:"import",control:control) {try self.validateImport(id,control:control)}
        case "confirmImport":
            try exact(["operationId","preview","confirmed"]);try BackupIO.require(try args["confirmed"]?.json() == "true","NOT_ELIGIBLE")
            let operation=try control.operation(id), current=operation.object?["operation"]?.object?["state"]
            if ["staging","prepared","switching","verifying","complete"].contains(current?.object?["kind"]?.text) {break}
            try BackupIO.require(current?.object?["kind"]?.text == "preview_ready" && (try CoreSchema.same(current?.object?["preview"],args["preview"])),"PREVIEW_STALE")
            try withLock {try BackupIO.require(running==nil && shared.isEmpty && !deleting.contains(id),"BUSY");running=id;cancelled.remove(id)}
            do {try state(id,progress("staging"),control)} catch {withLock{running=nil};throw error}
            dispatch(id,kind:"import",control:control) {try self.confirm(id,preview:args["preview"]!,control:control)}
        case "renewExportHandle":
            try exact(["operationId"]);try renew(id,control:control)
        default:throw CoreRepositoryError("FIELD_INVALID")
        }
        return try control.operation(id).json()
    }
    func dispatch(_ id:String,kind:String,control:BackupControl,_ work:@escaping()throws->Void) {
        worker.async { [core=self.core] in
            defer{withExtendedLifetime(core){}}
            do {try work()} catch {
                let original=error
                do {try self.fail(id,kind:kind,error:original,control:control)}
                catch {self.withLock{self.pendingFailures[id]=(kind,original)}}
            }
            self.withLock {if self.running==id {self.running=nil};self.cancelled.remove(id)}
            self.scheduleCleanup(control)
        }
    }
    func fail(_ id:String,kind:String,error:Error,control:BackupControl) throws {
        try failureWriteFault?()
        try control.recoverConnection()
        let code=Self.code(error)
        if kind == "import", let row = try control.db.read({try $0.query("SELECT r.phase,j.state_json FROM replacement r JOIN jobs j ON j.id=r.job WHERE r.job=?",[.text(id)]).first}) {
            let phase = row[0].stringValue
            let current = try CanonicalParser.parse(CoreSchema.text(row[1])).object?["kind"]?.text
            if ["prepared","switched","verified"].contains(phase) || (phase == "rolled_back" && current == "failed") {
                // Preserve a committed outcome, including a lost rollback reply.
                // A later same-ID retry in validating/staging must still record its
                // own failure; an old rolled_back row does not describe that attempt.
                try control.recover(at:clock())
                core.queue.sync {core.replacementAdmissionClosed=false}
                return
            }
        }
        if code == "BACKUP_CANCELLED" {
            try state(id,kind == "import" ? .object(["kind":.string("cancelled"),"oldDatasetPreserved":.boolean(true)]) : .object(["kind":.string("cancelled"),"fileCreated":.boolean(false)]),control)
        } else {
            try state(id,kind == "import" ? BackupControl.failure(code:code,dataset:core.queue.sync{core.datasetID.isEmpty ? nil:core.datasetID},recovery:core.queue.sync{core.database == nil} ? "open_recovery" : code == "PREVIEW_STALE" ? "review_again":"retry_validation",preserved:true) : .object(["kind":.string("failed"),"code":.string(code),"retry":.string("start_new_export")]),control)
        }
    }
    func expiry() -> String {CoreClockFrame.capture(core.now().addingTimeInterval(86400)).instant}
    func scheduleCleanup(_ control:BackupControl) {
        let scheduled=withLock { () -> Bool in if cleanupScheduled{return false};cleanupScheduled=true;return true }
        guard scheduled else{return}
        worker.async { [core=self.core] in
            defer{withExtendedLifetime(core){}}
            defer{self.withLock{self.cleanupScheduled=false}}
            try? self.cleanup(control)
        }
    }
    /// Only durable, native-derived scratch roots expire. Never recurse into legacy.
    func cleanup(_ control:BackupControl) throws {
        var cursor=""
        let time=clock()
        while let row=try control.db.read({try $0.query("SELECT kind,key,owner FROM artifacts WHERE expires<=? AND kind||':'||key>? ORDER BY kind,key LIMIT 1",[.text(time),.text(cursor)]).first}) {
            let kind=try CoreSchema.text(row[0]), key=try CoreSchema.text(row[1]),owner=row[2].stringValue
            cursor=kind+":"+key
            let protected=withLock { () -> Bool in
                if let owner, running==owner || shared.contains(owner) || pendingFailures[owner] != nil {return true}
                if kind == "selection" && selections[key].map({$0.1>core.now()}) == true {return true}
                deleting.insert(owner ?? key)
                return false
            }
            if protected {continue}
            defer{withLock{_ = deleting.remove(owner ?? key)}}
            cleanupClaimed?(owner ?? key)
            if kind == "staging" {
                // Rollback unregisters rejected candidates atomically. Registered
                // generations are only current or retained successful collections.
                if try !control.db.read({try $0.query("SELECT id FROM generations WHERE id=?",[.text(key)])}).isEmpty {continue}
                let ownerPreview=try control.db.read {try $0.query("SELECT state_json,new_generation FROM jobs WHERE id=?",[row[2]]).first}
                if let ownerPreview,ownerPreview[1] == .text(key),try CanonicalParser.parse(CoreSchema.text(ownerPreview[0])).object?["kind"]?.text == "preview_ready" {
                    try state(owner!,BackupControl.failure(code:"IO_FAILURE",dataset:nil,recovery:"retry_validation",preserved:true),control)
                }
            }
            if kind == "job" {
                let exists=try control.db.read {try $0.query("SELECT id FROM jobs WHERE id=?",[.text(key)]).first != nil}
                let operation=exists ? try control.operation(key) : CanonicalValue.null
                let job=operation.object?["operation"]?.object,phase=job?["state"]?.object?["kind"]?.text
                if ["prepared","switching","verifying"].contains(phase) {continue}
                if ["preview_ready","selected","staging","validating"].contains(phase) {
                    try state(key,BackupControl.failure(code:"IO_FAILURE",dataset:nil,recovery:"retry_validation",preserved:true),control)
                }
                if job?["kind"]?.text == "export" {
                    try state(key,.object(["kind":.string("failed"),"code":.string("IO_FAILURE"),"retry":.string("start_new_export")]),control)
                }
            }
            let target=try control.artifactURL(kind:kind,key:key)
            try core.backupFileIO.remove(target)
            try control.db.transaction {try $0.execute("DELETE FROM artifacts WHERE kind=? AND key=?",[.text(kind),.text(key)])}
            if kind == "selection" {withLock{_ = selections.removeValue(forKey:key)}}
            if kind == "job" {withLock{handles=handles.filter{$0.value.0 != key}}}
        }
    }
    func persistFailures(_ control:BackupControl) throws {
        let pending=withLock{pendingFailures}
        for (id,value) in pending {
            if try control.db.read({try $0.query("SELECT id FROM jobs WHERE id=?",[.text(id)]).first}) != nil {
                try fail(id,kind:value.0,error:value.1,control:control)
            }
            withLock{_ = pendingFailures.removeValue(forKey:id)}
        }
    }
    func acknowledgeReopen(_ control:BackupControl,dataset:String) throws {
        guard let row=try control.db.read({try $0.query("SELECT id,state_json FROM jobs ORDER BY rowid DESC LIMIT 1").first}) else{return}
        var value=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[1])))
        if value["kind"]?.text == "failed",value["recovery"]?.text == "open_recovery" {
            value["recovery"] = .string("retry_validation");value["activeDatasetId"] = .string(dataset)
            try state(CoreSchema.text(row[0]),.object(value),control)
        }
    }
    static func code(_ error:Error) -> String {
        if let e=error as? CoreRepositoryError {
            if ["FIELD_INVALID","PLAN_INVALID","STORAGE_INVALID","MEDIA_INVALID"].contains(e.code) {return "BACKUP_SCHEMA_INVALID"}
            if e.code == "PLAN_LIMIT" || e.code == "MEDIA_TOO_LARGE" {return "BACKUP_LIMIT"}
            if e.code == "NOT_FOUND" {return "BACKUP_REFERENCE_INVALID"}
            return e.code
        }
        if case StorageFailure.filesystem(let n)=error, n == ENOSPC || n == EDQUOT {return "DISK_FULL"}
        if case StorageFailure.sqlite(let n)=error, n&255 == 13 {return "DISK_FULL"}
        if error is CanonicalParseFailure || error is CanonicalFailure {return "BACKUP_SCHEMA_INVALID"}
        if case StorageFailure.sqlite(let n)=error, n&255 == 19 {return "BACKUP_REFERENCE_INVALID"}
        return "IO_FAILURE"
    }
    func fingerprint(_ db:SQLiteDatabase) throws -> [String:CanonicalValue] {
        try db.read {sql in
            let meta=try sql.query("SELECT dataset_id,collection_revision,storage_revision FROM metadata")[0]
            var hash=SHA256()
            for table in CoreRegistry.draftTables.sorted()+["media_preparations"] {
                var cursor="", column=table == "media_preparations" ? "state":"revision"
                while let row=try sql.query("SELECT id,\(column) FROM \(table) WHERE id>? ORDER BY id LIMIT 1",[.text(cursor)]).first {
                    cursor=try CoreSchema.text(row[0]);hash.update(data:try CanonicalCommand.bytes(.array([.string(table),CoreSchema.canonical(row[0]),CoreSchema.canonical(row[1])])))
                }
            }
            return ["currentDatasetId":CoreSchema.canonical(meta[0]),"currentCollectionRevision":CoreSchema.canonical(meta[1]),"currentStorageRevision":CoreSchema.canonical(meta[2]),"currentSettingsRevision":CoreSchema.canonical(try sql.query("SELECT revision FROM user_settings WHERE slot=1")[0][0]),"currentDraftFingerprint":.string(hash.finalize().map{String(format:"%02x",$0)}.joined())]
        }
    }
    func idleContent(_ db:SQLiteDatabase) throws {
        try db.read {sql in
            for query in ["SELECT id FROM intents WHERE status='pending' LIMIT 1","SELECT id FROM media_preparations WHERE state='copying' LIMIT 1","SELECT id FROM media_selections WHERE state='copying' LIMIT 1"] {
                try BackupIO.require(try sql.query(query).isEmpty,"BUSY")
            }
        }
    }
    func export(_ id:String,control:BackupControl) throws {
        let root=try control.jobRoot(id), snapshot=root.appendingPathComponent("snapshot.sqlite")
        let mediaRoot:URL=try core.queue.sync {
            guard let db=core.database,!core.replacementAdmissionClosed,core.platformLeases.isEmpty else{throw CoreRepositoryError("BUSY")}
            try idleContent(db)
            let mediaBytes=try db.read {try CoreSchema.integer($0.query("SELECT COALESCE(sum(byte_count),0) FROM photos")[0][0])}
            try BackupIO.reserve(at:root,additional:4*BackupIO.size(core.directory.appendingPathComponent("core.sqlite"))+3*mediaBytes+64*1024*1024)
            core.backupReadLease=true
            do {try db.snapshot(to:snapshot)} catch {core.backupReadLease=false;throw error}
            return core.directory
        }
        defer {core.queue.sync{core.backupReadLease=false};core.mediaWorker.async{[core=self.core] in core.cleanupMedia()}}
        try BackupIO.protect(snapshot);try core.backupFault?(.snapshot)
        let db=try SQLiteDatabase.open(at:snapshot,schema:CoreSchema.schema())
        defer {try? db.close()}
        let index=try BackupIndex(root.appendingPathComponent("export-index.sqlite"))
        try state(id,progress("writing"),control)
        try BackupContent.export(db,to:root,mediaRoot:mediaRoot,index:index,instant:clock(),io:core.backupFileIO,cancel:{try self.check(id)})
        let zip=root.appendingPathComponent("Verdi-backup.zip")
        try BackupArchive.create(zip,dataRoot:root,mediaRoot:mediaRoot,index:index,io:core.backupFileIO,cancel:{try self.check(id)})
        try state(id,progress("validating"),control)
        let verify=root.appendingPathComponent("verify");try BackupIO.directory(verify,io:core.backupFileIO,relativeTo:root)
        let validationIndex=try BackupIndex(root.appendingPathComponent("verify-index.sqlite"))
        try BackupArchive.extract(zip,to:verify,index:validationIndex,io:core.backupFileIO,cancel:{try self.check(id)})
        let verified=try BackupContent.importData(root:verify,index:validationIndex,dataset:UUID().uuidString.lowercased(),instant:clock(),cancel:{try self.check(id)})
        try verified.close();try check(id)
        let digest=try BackupIO.hash(zip,cancel:{try self.check(id)})
        try fileCreated(id,digest:digest,control:control)
    }
    func fileCreated(_ id:String,digest:(String,Int64),control:BackupControl) throws {
        let handle=UUID().uuidString.lowercased(), expires=core.now().addingTimeInterval(600)
        withLock{handles[handle]=(id,expires)}
        try control.db.transaction {try $0.execute("UPDATE jobs SET source_hash=? WHERE id=?",[.text(digest.0),.text(id)])}
        try state(id,.object(["kind":.string("file_created"),"exportHandle":.string(handle),"byteCount":.integer(digest.1),"sha256":.string(digest.0),"expiresAt":.string(CoreClockFrame.capture(expires).instant)]),control)
    }
    func renew(_ id:String,control:BackupControl) throws {
        let operation=try control.operation(id), state=operation.object?["operation"]?.object?["state"]
        try BackupIO.require(operation.object?["operation"]?.object?["kind"]?.text == "export" && (["file_created","handed_to_os"].contains(state?.object?["kind"]?.text) || state?.object?["fileCreated"]?.json() == "true"),"NOT_ELIGIBLE")
        try withLock {try BackupIO.require(running==nil && !shared.contains(id) && !deleting.contains(id),"BUSY");shared.insert(id)}
        defer {withLock{_ = shared.remove(id)}}
        let expiry = try control.db.read {try $0.query("SELECT expires FROM artifacts WHERE kind='job' AND key=?",[.text(id)]).first?.first?.stringValue}
        try BackupIO.require(expiry.map{$0>clock()} == true,"EXPORT_EXPIRED")
        let zip=try control.jobRoot(id).appendingPathComponent("Verdi-backup.zip")
        let expected=try control.db.read {try $0.query("SELECT source_hash FROM jobs WHERE id=?",[.text(id)])[0][0].stringValue}
        let digest=try BackupIO.hash(zip)
        if let expected {try BackupIO.require(expected == digest.0,"BACKUP_HASH_MISMATCH")}
        try fileCreated(id,digest:digest,control:control)
    }
    func validateImport(_ id:String,control:BackupControl) throws {
        try state(id,progress("validating"),control)
        let source=try importSource(id,control:control), digest=try BackupIO.hash(source,cancel:{try self.check(id)})
        let generation=UUID().uuidString.lowercased(), dataset=UUID().uuidString.lowercased(), root=control.generations.appendingPathComponent(generation)
        // A durable job registers the generation before any of its files are created.
        try control.db.transaction {try $0.execute("UPDATE jobs SET source_hash=?,new_generation=?,preview_json=NULL WHERE id=?",[.text(digest.0),.text(generation),.text(id)])}
        try control.registerArtifact(kind:"staging",key:generation,owner:id,expires:expiry())
        try BackupIO.directory(root,io:core.backupFileIO,relativeTo:control.generations);try BackupIO.excludeFromOSBackup(root)
        let index=try BackupIndex(root.appendingPathComponent("archive-index.sqlite"))
        try BackupArchive.extract(source,to:root,index:index,io:core.backupFileIO,cancel:{try self.check(id)})
        try state(id,progress("staging"),control)
        let db=try BackupContent.importData(root:root,index:index,dataset:dataset,instant:clock(),cancel:{try self.check(id)})
        do {
            let counts=try BackupContent.counts(db)
            try db.checkpoint();try db.close();try BackupIO.flush(root.appendingPathComponent("core.sqlite"),io:core.backupFileIO)
            let marker=try BackupWriter(root.appendingPathComponent("initialized"),limit:32,io:core.backupFileIO);try marker.write("verdi-generation-v2");try marker.finish()
            try check(id);try core.backupFault?(.staged)
            var preview=try core.queue.sync { () throws -> [String:CanonicalValue] in
                guard let current=core.database,!core.replacementAdmissionClosed else{throw CoreRepositoryError("BUSY")}
                try idleContent(current);return try fingerprint(current)
            }
            let expanded=try index.database.read {try CoreSchema.integer($0.query("SELECT COALESCE(sum(expanded),0) FROM entries")[0][0])}
            preview.merge(["importId":.string(id),"sourceSha256":.string(digest.0),"formatVersion":.integer(2),"dataSchemaVersion":.integer(2),"counts":counts,"requiredAdditionalBytes":.integer(expanded),"warningKey":.string("replace_not_merge")]) {_,new in new}
            let value=CanonicalValue.object(preview)
            try control.db.transaction {try $0.execute("UPDATE jobs SET preview_json=? WHERE id=?",[.text(try value.json()),.text(id)])}
            try state(id,.object(["kind":.string("preview_ready"),"preview":value]),control)
        } catch {try? db.close();throw error}
    }
    func importSource(_ id:String,control:BackupControl) throws -> URL {
        let target = try control.jobRoot(id).appendingPathComponent("source.zip")
        let rows = try control.db.read {try $0.query("SELECT key FROM artifacts WHERE kind='selection' AND owner=?",[.text(id)])}
        try BackupIO.require(rows.count <= 1,"STORAGE_UNAVAILABLE")
        if let row = rows.first {
            let source = try control.artifactURL(kind:"selection",key:CoreSchema.text(row[0]))
            if !FileManager.default.fileExists(atPath:target.path) {try core.backupFileIO.renameExclusive(source,to:target)}
            // Also required on retry after rename succeeded but a parent sync failed.
            try core.backupFileIO.syncDirectory(source.deletingLastPathComponent())
            try core.backupFileIO.syncDirectory(target.deletingLastPathComponent())
        }
        // Older retained jobs already own source.zip without a selection binding.
        _ = try BackupIO.size(target)
        return target
    }
    func confirm(_ id:String,preview:CanonicalValue,control:BackupControl) throws {
        try check(id)
        let expected=try CoreSchema.object(preview)
        try core.queue.sync {
            guard let db=core.database,!core.replacementAdmissionClosed,!core.backupReadLease,core.platformLeases.isEmpty else {throw CoreRepositoryError("BUSY")}
            core.exportLeases=core.exportLeases.filter{$0.value>core.now()}
            try BackupIO.require(core.exportLeases.isEmpty,"BUSY");try idleContent(db)
            for (key,value) in try fingerprint(db) {try BackupIO.require(try CoreSchema.same(expected[key],value),"PREVIEW_STALE")}
            core.replacementAdmissionClosed=true
        }
        var prepared=false
        defer {if !prepared {core.queue.sync{core.replacementAdmissionClosed=false}}}
        // Drain outside the core queue: file workers can finish their core callbacks.
        core.mediaWorker.sync {}
        let row=try control.db.read {try $0.query("SELECT new_generation,preview_json,source_hash FROM jobs WHERE id=?",[.text(id)])[0]}
        try BackupIO.require(try CoreSchema.same(CanonicalParser.parse(CoreSchema.text(row[1])),preview),"PREVIEW_STALE")
        let generation=try CoreSchema.text(row[0]), root=control.generations.appendingPathComponent(generation)
        let source=try control.jobRoot(id).appendingPathComponent("source.zip")
        try BackupIO.require(try BackupIO.hash(source,cancel:{try self.check(id)}).0 == CoreSchema.text(row[2]),"BACKUP_HASH_MISMATCH")
        let staged=try SQLiteDatabase.open(at:root.appendingPathComponent("core.sqlite"),schema:CoreSchema.schema())
        let mediaHash:String, dataset:String
        do {
            mediaHash=try BackupControl.mediaHash(staged,root:root)
            dataset=try staged.read{try CoreSchema.text($0.query("SELECT dataset_id FROM metadata")[0][0])}
            try staged.checkpoint();try staged.close()
        } catch {try? staged.close();throw error}
        try BackupIO.excludeFromOSBackup(root,excluded:false)
        try BackupIO.flush(root.appendingPathComponent("core.sqlite"),io:core.backupFileIO)
        let dbHash=try BackupIO.hash(root.appendingPathComponent("core.sqlite")).0
        try BackupIO.reserve(at:root,additional:0);try check(id)
        try core.queue.sync {
            guard let db=core.database else{throw CoreRepositoryError("STORAGE_UNAVAILABLE")}
            try idleContent(db)
            for (key,value) in try fingerprint(db) {try BackupIO.require(try CoreSchema.same(expected[key],value),"PREVIEW_STALE")}
            // Retire the session before a close that may fail. The UI must reopen.
            core.database=nil;core.mediaFiles=nil;core.sessionID="";core.grants.removeAll();core.previews.removeAll()
            do {try db.checkpoint();try db.close()} catch {try? db.close();throw error}
        }
        // Cancellation stops here. The pointer coordinator owns recovery thereafter.
        try control.prepare(job:id,new:generation,dataset:dataset,dbHash:dbHash,mediaHash:mediaHash,at:clock());prepared=true
        try control.switchPointer(at:clock());try control.recover(at:clock())
        core.queue.sync{core.replacementAdmissionClosed=false}
    }
    func shareURL(_ request:String) throws -> (String,URL) {
        let args=try CoreSchema.object(CanonicalParser.package(request))
        try BackupIO.require(Set(args.keys)==Set(["operationId","exportHandle"]),"FIELD_INVALID")
        let id=try CoreSchema.string(args["operationId"]), handle=try CoreSchema.string(args["exportHandle"])
        try withLock {
            guard let known=handles[handle],known.0==id,known.1>core.now() else{throw CoreRepositoryError("EXPORT_EXPIRED")}
            try BackupIO.require(running==nil && !shared.contains(id) && !deleting.contains(id),"BUSY");shared.insert(id)
        }
        do {
            let control=try control(), url=try control.jobRoot(id).appendingPathComponent("Verdi-backup.zip")
            let expected=try control.db.read{try $0.query("SELECT source_hash FROM jobs WHERE id=?",[.text(id)]).first?.first?.stringValue}
            try BackupIO.require(try BackupIO.hash(url).0 == expected,"BACKUP_HASH_MISMATCH")
            return (id,url)
        }
        catch {withLock{_ = shared.remove(id)};throw error}
    }
    func finishShare(_ id:String,result:String) throws {
        defer {withLock{_ = shared.remove(id)}}
        let control=try control()
        try state(id,result == "handedToOS" ? .object(["kind":.string("handed_to_os"),"fileCreated":.boolean(true)]) : .object(["kind":.string("cancelled"),"fileCreated":.boolean(true)]),control)
    }
}

extension CoreRepository {
    public func backupCall(method:String,request:String) throws -> String {try backupEngine.call(method,request)}
    public func retainBackupSelection(source:URL) throws -> String {try backupEngine.retainSelection(source)}
    public func backupShareURL(request:String) throws -> (String,URL) {try backupEngine.shareURL(request)}
    public func finishBackupShare(operationID:String,result:String) throws {try backupEngine.finishShare(operationID,result:result)}
}
