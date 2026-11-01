import Foundation

extension CoreRepository {
    func reminderDatabase() throws -> SQLiteDatabase {
        guard !replacementAdmissionClosed,let db=database,!sessionID.isEmpty else{throw CoreRepositoryError("BUSY")}
        if reminderRecoveryRequired {
            try? db.close()
            database=try Self.openDatabase(directory.appendingPathComponent("core.sqlite"),fault:fault,expectedDataset:datasetID)
            reminderRecoveryRequired=false;previews.removeAll();grants.removeAll()
        }
        return database!
    }
    func reminderContext() throws -> ReminderContext {
        try queue.sync {
            let db=try reminderDatabase()
            return try db.read{sql in
                let meta=try sql.query("SELECT dataset_id,collection_revision FROM metadata")[0]
                let settings=try CanonicalParser.parse(CoreSchema.text(sql.query("SELECT payload_json FROM user_settings WHERE slot=1")[0][0]))
                try BackupSettings.validate(settings)
                return ReminderContext(dataset:try CoreSchema.text(meta[0]),collection:try CoreSchema.integer(meta[1]),settings:settings,savedSchedule:try !sql.query("SELECT 1 FROM routines LIMIT 1").isEmpty)
            }
        }
    }
    func reminderMatches(_ context:ReminderContext) throws -> Bool {
        let current=try reminderContext()
        return current.dataset==context.dataset && current.collection==context.collection && current.revision==context.revision
    }
    func reminderGroups(_ context:ReminderContext,ledger:ReminderLedger,budget:Int,at now:Date,zone:TimeZone) throws -> ReminderAccumulator {
        try queue.sync {
            let db=try reminderDatabase(), p=try context.preferences
            return try db.read{sql in
                guard datasetID==context.dataset,try sql.query("SELECT collection_revision FROM metadata")[0][0] == .integer(context.collection),try sql.query("SELECT revision FROM user_settings")[0][0] == .integer(context.revision) else{throw CoreRepositoryError("STALE")}
                var result=ReminderAccumulator(budget:budget), date="",id="",lastDate="",lastFire:Date?
                while true {
                    let rows=try sql.query("SELECT h.id,h.revision,h.next_check FROM heads h JOIN routines r ON r.id=h.routine_id JOIN plants p ON p.id=r.plant_id WHERE r.state='active' AND p.archived=0 AND (h.next_check>? OR (h.next_check=? AND h.id>?)) ORDER BY h.next_check,h.id LIMIT 256",[.text(date),.text(date),.text(id)])
                    if rows.isEmpty {break}
                    for row in rows {
                        id=try CoreSchema.text(row[0]);date=try CoreSchema.text(row[2])
                        let head=ReminderHead(headId:id,headRevision:try CoreSchema.integer(row[1]))
                        if date != lastDate {lastDate=date;lastFire=try ReminderPlan.fire(date,preferences:p,zone:zone)}
                        if try lastFire! <= now || ledger.past(head,context:context,now:now) {result.past += 1;continue}
                        result.add(head,fire:lastFire!)
                    }
                }
                result.flush()
                try ledger.prune{id,revision in try self.reminderHeadCurrent(sql,id,revision)}
                return result
            }
        }
    }
    func reminderHeadCurrent(_ sql:SQLiteSession,_ id:String,_ revision:Int64) throws -> Bool {
        try !sql.query("SELECT 1 FROM heads h JOIN routines r ON r.id=h.routine_id JOIN plants p ON p.id=r.plant_id WHERE h.id=? AND h.revision=? AND r.state='active' AND p.archived=0",[.text(id),.integer(revision)]).isEmpty
    }
    func reminderClear(_ context:ReminderContext) throws {
        try queue.sync {
            let db=try reminderDatabase()
            do {try db.transaction{sql in
                guard datasetID==context.dataset,try sql.query("SELECT collection_revision FROM metadata")[0][0] == .integer(context.collection),try sql.query("SELECT revision FROM user_settings")[0][0] == .integer(context.revision) else{return}
                try sql.execute("DELETE FROM outbox WHERE dirty_revision=?",[.integer(context.collection)])
            }} catch StorageFailure.unknownOutcome {reminderRecoveryRequired=true;throw CoreRepositoryError("UNKNOWN_OUTCOME")}
        }
    }
    func reminderSettings(_ request:String,resolve:Bool) throws -> CanonicalValue {
        try queue.sync {
            guard request.utf8.count<=4096 else{throw CoreRepositoryError("PLAN_LIMIT")}
            let args=try CoreSchema.object(CanonicalParser.parse(request))
            guard Set(args.keys)==Set(["operationId","datasetId","expectedRevision","values"]) else{throw CoreRepositoryError("FIELD_INVALID")}
            let id=try CoreSchema.string(args["operationId"]),dataset=try CoreSchema.string(args["datasetId"])
            try CoreSchema.uuid(id);try CoreSchema.uuid(dataset)
            let hash=try CanonicalCommand.hash(.object(args)),db=try reminderDatabase()
            guard dataset==datasetID else{throw CoreRepositoryError("DATASET_CHANGED")}
            if let receipt=try db.read({try self.receipt($0,id,hash:hash)}) {return .object(["committed":.boolean(true),"result":receipt])}
            if resolve {return .object(["committed":.boolean(false)])}
            do {
                let result=try db.transaction {sql -> CanonicalValue in
                    if try !sql.query("SELECT 1 FROM intents WHERE id=?",[.text(id)]).isEmpty {throw CoreRepositoryError("COMMAND_ID_REUSED")}
                    var settings=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(sql.query("SELECT payload_json FROM user_settings WHERE slot=1")[0][0])))
                    let expected=try CoreSchema.number(args["expectedRevision"]),oldRevision=try CoreSchema.number(settings["revision"])
                    guard expected==oldRevision else{throw CoreRepositoryError("REVISION_CONFLICT")}
                    var values=try CoreSchema.object(args["values"]),old=try CoreSchema.object(settings["reminders"])
                    guard Set(values.keys)==Set(["enabled","preferredMinute","quietStartMinute","quietEndMinute"]) else{throw CoreRepositoryError("FIELD_INVALID")}
                    let reminderRevision=try CoreSchema.number(old.removeValue(forKey:"settingsRevision"))
                    let changed=try CanonicalCommand.hash(.object(old)) != CanonicalCommand.hash(.object(values))
                    values["settingsRevision"] = .integer(reminderRevision+(changed ? 1:0));settings["reminders"] = .object(values);settings["revision"] = .integer(oldRevision+1)
                    try BackupSettings.validate(.object(settings))
                    try sql.execute("UPDATE user_settings SET revision=?,payload_json=? WHERE slot=1",[.integer(oldRevision+1),.text(CanonicalValue.object(settings).json())])
                    try sql.execute("UPDATE metadata SET collection_revision=collection_revision+1,storage_revision=storage_revision+1 WHERE slot=1")
                    try sql.execute("INSERT INTO outbox SELECT 1,collection_revision FROM metadata WHERE slot=1 ON CONFLICT(slot) DO UPDATE SET dirty_revision=excluded.dirty_revision")
                    let revision=try CoreSchema.integer(sql.query("SELECT collection_revision FROM metadata")[0][0])
                    let result:CanonicalValue = .object(["commandId":.string(id),"datasetId":.string(dataset),"collectionRevision":.integer(revision),"primaryId":.null,"primaryType":.null,"resourceIds":.array([]),"newRevisions":.object([:]),"notices":.array([]),"replayed":.boolean(false)])
                    try sql.execute("INSERT INTO intents VALUES(?,?,?,NULL,'committed')",[.text(id),.text("SetReminderSettings"),.text(hash)])
                    try sql.execute("INSERT INTO receipts VALUES(?,?,?,NULL,0)",[.text(id),.text(hash),.text(result.json())])
                    return result
                }
                reminderInvalidated?()
                return .object(["committed":.boolean(true),"result":result])
            } catch StorageFailure.unknownOutcome {reminderRecoveryRequired=true;throw CoreRepositoryError("UNKNOWN_OUTCOME")}
        }
    }
    func reminderTapValid(_ value:CanonicalValue) throws -> Bool {
        try queue.sync {
            let db=try reminderDatabase()
            guard let v=value.object,Set(v.keys)==Set(["version","datasetId","planRevision","settingsRevision","heads"]),v["version"]?.integer==1,v["datasetId"]?.text==datasetID,let revision=v["planRevision"]?.integer,(1...CoreSchema.maxRevision).contains(revision),let heads=v["heads"]?.array,(1...16).contains(heads.count) else{return false}
            return try db.read{sql in
                let settings=try CanonicalParser.parse(CoreSchema.text(sql.query("SELECT payload_json FROM user_settings")[0][0]))
                guard settings.object?["reminders"]?.object?["settingsRevision"]?.integer==v["settingsRevision"]?.integer else{return false}
                var seen=Set<String>()
                for head in heads {
                    guard let h=head.object,Set(h.keys)==Set(["headId","headRevision"]),let id=h["headId"]?.text,let rev=h["headRevision"]?.integer,seen.insert(id).inserted else{return false}
                    try CoreSchema.uuid(id)
                    if try !reminderHeadCurrent(sql,id,rev) {return false}
                }
                return true
            }
        }
    }
}
