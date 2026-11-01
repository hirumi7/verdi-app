import Foundation

/// Installation-local projection. Never exported with customer content.
final class ReminderLedger {
    let db:SQLiteDatabase
    let path:URL
    static let statements=[
        "CREATE TABLE plan(slot INTEGER PRIMARY KEY CHECK(slot=1),dataset TEXT NOT NULL,revision INTEGER NOT NULL,hash TEXT NOT NULL,requests TEXT NOT NULL,result TEXT NOT NULL)",
        "CREATE TABLE submitted(dataset TEXT NOT NULL,head TEXT NOT NULL,revision INTEGER NOT NULL,settings INTEGER NOT NULL,fire TEXT NOT NULL,PRIMARY KEY(dataset,head))",
        "CREATE TABLE issued(id TEXT PRIMARY KEY NOT NULL,payload TEXT NOT NULL,fire TEXT NOT NULL,recorded TEXT NOT NULL)",
        "CREATE TABLE taps(id TEXT PRIMARY KEY NOT NULL,request_id TEXT NOT NULL UNIQUE,payload TEXT NOT NULL,created TEXT NOT NULL)"
    ]
    static var schema:CompiledSchema {CompiledSchema(applicationID:0x56524d31,version:1,statements:statements,validate:{sql in
        let actual=try sql.query("SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'")
        guard try Set(actual.map{try CoreSchema.text($0[0])})==Set(statements) else{throw StorageFailure.schemaMismatch}
    })}
    init(_ installation:URL,fault:((SQLiteBoundary)throws->Void)? = nil) throws {
        let root=installation.deletingLastPathComponent().appendingPathComponent(installation.lastPathComponent+"-reminders")
        try BackupIO.directory(root);try BackupIO.excludeFromOSBackup(root)
        let file=root.appendingPathComponent("state.sqlite")
        path=file
        db = FileManager.default.fileExists(atPath:file.path) ? try SQLiteDatabase.open(at:file,schema:Self.schema,controlProfile:true,fault:fault) : try SQLiteDatabase.create(at:file,schema:Self.schema,controlProfile:true,fault:fault)
        try BackupIO.protect(file);try BackupIO.flush(file)
    }
    deinit {try? db.close()}
    func recover() throws {try db.recoverControlConnection(at:path,schema:Self.schema)}
    func past(_ head:ReminderHead,context:ReminderContext,now:Date) throws -> Bool {
        try db.read {sql in
            !(try sql.query("SELECT 1 FROM submitted WHERE dataset=? AND head=? AND revision=? AND settings=? AND fire<=?",[.text(context.dataset),.text(head.headId),.integer(head.headRevision),.integer(context.preferences.revision),.text(ReminderPlan.instant(now))])).isEmpty
        }
    }
    func persist(_ groups:[ReminderGroup],context:ReminderContext,zone:String,now:Date) throws -> [ReminderRequest] {
        try db.transaction {sql in
            let semantic="[" + (try groups.map{try $0.ordered(dataset:context.dataset,settings:context.preferences.revision,zone:zone)}).joined(separator:",") + "]"
            // Include empty-plan identity: settings/dataset/zone still invalidate old taps.
            let hash=ReminderPlan.digest(context.dataset+"|\(try context.preferences.revision)|"+zone+semantic)
            let old=try sql.query("SELECT dataset,revision,hash FROM plan WHERE slot=1").first
            let revision:Int64
            if let old, old[0] == .text(context.dataset) {revision=try CoreSchema.integer(old[1])+(old[2] == .text(hash) ? 0:1)} else {revision=1}
            guard revision<=CoreSchema.maxRevision else{throw CoreRepositoryError("REVISION_EXHAUSTED")}
            let requests=try ReminderPlan.requests(groups,context:context,zone:zone,revision:revision)
            let encoded:CanonicalValue = .array(requests.map{.object(["id":.string($0.identifier),"payload":.string($0.payloadJSON),"fire":.string(ReminderPlan.instant($0.fireAt))])})
            try sql.execute("INSERT INTO plan VALUES(1,?,?,?,?,?) ON CONFLICT(slot) DO UPDATE SET dataset=excluded.dataset,revision=excluded.revision,hash=excluded.hash,requests=excluded.requests,result=excluded.result",[.text(context.dataset),.integer(revision),.text(hash),.text(encoded.json()),.text("null")])
            for request in requests {
                try sql.execute("INSERT INTO issued VALUES(?,?,?,?) ON CONFLICT(id) DO NOTHING",[.text(request.identifier),.text(request.payloadJSON),.text(ReminderPlan.instant(request.fireAt)),.text(ReminderPlan.instant(now))])
                for head in request.group.heads {
                    try sql.execute("INSERT INTO submitted VALUES(?,?,?,?,?) ON CONFLICT(dataset,head) DO UPDATE SET fire=CASE WHEN revision=excluded.revision AND settings=excluded.settings THEN min(fire,excluded.fire) ELSE excluded.fire END,revision=excluded.revision,settings=excluded.settings",[.text(context.dataset),.text(head.headId),.integer(head.headRevision),.integer(context.preferences.revision),.text(ReminderPlan.instant(request.fireAt))])
                }
            }
            try sql.execute("DELETE FROM issued WHERE fire<?",[.text(ReminderPlan.instant(now.addingTimeInterval(-7*86400)))])
            let current=Set(requests.map(\.identifier))
            let retained=try sql.query("SELECT id FROM issued ORDER BY recorded DESC,id DESC")
            var historical=0
            for row in retained {
                let id=try CoreSchema.text(row[0]);if current.contains(id) {continue}
                historical += 1
                if historical>512 {try sql.execute("DELETE FROM issued WHERE id=?",[.text(id)])}
            }
            try sql.execute("DELETE FROM submitted WHERE dataset!=? OR settings!=?",[.text(context.dataset),.integer(context.preferences.revision)])
            return requests
        }
    }
    func prune(_ valid:(String,Int64)throws->Bool) throws {
        var cursor=""
        while true {
            let rows=try db.read{try $0.query("SELECT head,revision FROM submitted WHERE head>? ORDER BY head LIMIT 256",[.text(cursor)])}
            if rows.isEmpty {break}
            for row in rows {
                let id=try CoreSchema.text(row[0]);cursor=id
                if try !valid(id,CoreSchema.integer(row[1])) {try db.transaction{try $0.execute("DELETE FROM submitted WHERE head=?",[.text(id)])}}
            }
        }
    }
    func result(_ value:CanonicalValue) throws {try db.transaction{try $0.execute("UPDATE plan SET result=? WHERE slot=1",[.text(value.json())])}}
    func lastResult(dataset:String) throws -> CanonicalValue {
        try db.read{sql in guard let row=try sql.query("SELECT result FROM plan WHERE dataset=?",[.text(dataset)]).first else{return .null};return try CanonicalParser.parse(CoreSchema.text(row[0]))}
    }
    func retainTap(requestID:String,payload:String,now:Date) throws {
        let bounded=payload.utf8.count<=8192 ? payload:"null"
        try db.transaction{sql in
            try sql.execute("DELETE FROM taps WHERE created<?",[.text(ReminderPlan.instant(now.addingTimeInterval(-7*86400)))])
            try sql.execute("INSERT INTO taps VALUES(?,?,?,?) ON CONFLICT(request_id) DO NOTHING",[.text(UUID().uuidString.lowercased()),.text(String(requestID.prefix(100))),.text(bounded),.text(ReminderPlan.instant(now))])
            try sql.execute("DELETE FROM taps WHERE id IN (SELECT id FROM taps ORDER BY created DESC,id DESC LIMIT -1 OFFSET 32)")
        }
    }
    func tap(now:Date) throws -> [SQLValue]? {
        try db.transaction{sql in
            try sql.execute("DELETE FROM taps WHERE created<?",[.text(ReminderPlan.instant(now.addingTimeInterval(-7*86400)))])
            return try sql.query("SELECT id,request_id,payload FROM taps ORDER BY created,id LIMIT 1").first
        }
    }
    func issued(_ id:String,payload:String) throws -> Bool {try db.read{try !$0.query("SELECT 1 FROM issued WHERE id=? AND payload=?",[.text(id),.text(payload)]).isEmpty}}
    func acknowledge(_ id:String) throws {try CoreSchema.uuid(id);try db.transaction{try $0.execute("DELETE FROM taps WHERE id=?",[.text(id)])}}
}
