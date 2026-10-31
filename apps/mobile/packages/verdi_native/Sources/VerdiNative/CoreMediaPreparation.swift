import Foundation

extension CoreRepository {
    func mediaClock()->String {CoreClockFrame.capture(now(),zone:zone()).instant}
    func registerMediaPath(_ sql:SQLiteSession,_ path:String,preparation:String?=nil,selection:String?=nil) throws {
        if let preparation,let old=try sql.query("SELECT preparation_id FROM media_files WHERE relative_path=?",[.text(path)]).first,old[0] != .null,old[0] != .text(preparation) {
            let active=try sql.query("SELECT state FROM media_preparations WHERE id=?",[old[0]]).first?[0]
            try CoreRegistry.require(active != .text("copying") && active != .text("ready"),"MEDIA_BUSY")
        }
        try sql.execute("INSERT INTO media_files VALUES(?,?,?,?) ON CONFLICT(relative_path) DO UPDATE SET preparation_id=COALESCE(excluded.preparation_id,media_files.preparation_id)",[.text(path),preparation.map(SQLValue.text) ?? .null,selection.map(SQLValue.text) ?? .null,.text(mediaClock())])
    }
    /// Called while the OS callback still owns its temporary source URL.
    public func retainMediaSelection(source:URL,kind:String) throws -> String {
        let id=UUID().uuidString.lowercased(),path="selections/\(id).source"
        let context:(SQLiteDatabase,MediaFiles,String)=try queue.sync {
            guard ["camera","library"].contains(kind),let db=database,let files=mediaFiles,!sessionID.isEmpty else{throw CoreRepositoryError("SESSION_INVALID")}
            try db.transaction {sql in
                try registerMediaPath(sql,path,selection:id)
                try sql.execute("INSERT INTO media_selections VALUES(?,?,?,'copying',?)",[.text(id),.text(path),.text(kind),.text(mediaClock())])
            }
            return (db,files,sessionID)
        }
        do {
            try mediaWorker.sync {try context.1.importSelection(source,to:path)}
            try queue.sync {
                guard sessionID==context.2 else{throw CoreRepositoryError("SESSION_INVALID")}
                try context.0.transaction {try $0.execute("UPDATE media_selections SET state='ready' WHERE id=?",[.text(id)])}
            }
            return id
        } catch {
            queue.sync {if sessionID==context.2 {try? context.0.transaction {sql in
                try sql.execute("UPDATE media_selections SET state='failed' WHERE id=?",[.text(id)])
                try sql.execute("INSERT OR IGNORE INTO media_cleanup VALUES(?,?)",[.text(path),.text(mediaClock())])
            }}}
            throw error
        }
    }
    func recoverMedia(_ db:SQLiteDatabase) throws {
        try db.transaction {sql in
            for row in try sql.query("SELECT id,draft_revision FROM media_preparations WHERE state='copying'") {
                let result:CanonicalValue = .object(["kind":.string("failed"),"preparationId":CoreSchema.canonical(row[0]),"code":.string("IO_FAILURE"),"draftRevision":CoreSchema.canonical(row[1])])
                try sql.execute("UPDATE media_preparations SET state='failed',error_code='IO_FAILURE',result_json=? WHERE id=?",[.text(try result.json()),row[0]])
            }
            try sql.execute("UPDATE media_selections SET state='failed' WHERE state='copying'")
            let expiry=CoreClockFrame.capture(now().addingTimeInterval(-86400),zone:zone()).instant
            try sql.execute("UPDATE media_selections SET state='expired' WHERE created_at<?",[.text(expiry)])
            try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE preparation_id IN (SELECT id FROM media_preparations WHERE state IN ('failed','deleted','consumed')) OR selection_id IN (SELECT id FROM media_selections WHERE state IN ('expired','failed'))",[.text(mediaClock())])
        }
    }
    func persistMediaFailures(_ db:SQLiteDatabase) throws {
        for (id,failure) in pendingMediaFailures {
            guard failure.session==sessionID else{pendingMediaFailures.removeValue(forKey:id);continue}
            try db.transaction {sql in
                if let row=try sql.query("SELECT draft_revision FROM media_preparations WHERE id=? AND state='copying'",[.text(id)]).first {
                    let result:CanonicalValue = .object(["kind":.string("failed"),"preparationId":.string(id),"code":.string(failure.code),"draftRevision":CoreSchema.canonical(row[0])])
                    try sql.execute("UPDATE media_preparations SET state='failed',error_code=?,result_json=? WHERE id=?",[.text(failure.code),.text(try result.json()),.text(id)])
                    try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE preparation_id=?",[.text(mediaClock()),.text(id)])
                }
            }
            pendingMediaFailures.removeValue(forKey:id)
        }
    }
    func photoPreparation(_ sql:SQLiteSession,_ id:String) throws -> CanonicalValue {
        let rows=try sql.query("SELECT state,result_json,draft_revision FROM media_preparations WHERE id=?",[.text(id)])
        guard let row=rows.first else{throw CoreRepositoryError("NOT_FOUND")}
        if row[0] == .text("copying") {return .object(["kind":.string("copying"),"preparationId":.string(id),"completedBytes":.integer(0)])}
        return try CanonicalParser.parse(CoreSchema.text(row[1]))
    }
    /// Starts worker work and returns durable status immediately. Polling never
    /// mistakes a transport timeout for a failed attachment.
    func beginPhotoPreparation(_ args:[String:CanonicalValue],_ db:SQLiteDatabase) throws -> CanonicalValue {
        let keys:Set<String>=["sessionId","datasetId","draftId","draftRevision","preparationId","selectionId","observedDate"]
        try CoreRegistry.require(Set(args.keys)==keys && args["datasetId"]?.text==datasetID,"DATASET_CHANGED")
        let draftID=try CoreSchema.string(args["draftId"]),prepID=try CoreSchema.string(args["preparationId"]),selectionID=try CoreSchema.string(args["selectionId"]),date=try CoreSchema.string(args["observedDate"]),revision=try CoreSchema.number(args["draftRevision"])
        for id in [draftID,prepID,selectionID] {try CoreSchema.uuid(id)}
        try CoreRegistry.validDate(date)
        var hashed=args;hashed.removeValue(forKey:"sessionId");let hash=try CanonicalCommand.hash(.object(hashed)),photoID=UUID().uuidString.lowercased(),session=sessionID
        var work:(String,String,String?)?
        let status=try db.transaction {sql -> CanonicalValue in
            if let old=try sql.query("SELECT request_hash FROM media_preparations WHERE id=?",[.text(prepID)]).first {
                try CoreRegistry.require(old[0] == .text(hash),"COMMAND_ID_REUSED");return try photoPreparation(sql,prepID)
            }
            try CoreRegistry.require(date<=CoreClockFrame.capture(now(),zone:zone()).today,"FUTURE_OBSERVATION_DATE")
            guard let draft=try CoreRegistry.draftRow(sql,draftID),draft[1] == .integer(revision) else{throw CoreRepositoryError("STALE_TARGET")}
            try CoreRegistry.require(try sql.query("SELECT id FROM media_preparations WHERE draft_id=? AND state='copying'",[.text(draftID)]).isEmpty,"MEDIA_BUSY")
            guard let selection=try sql.query("SELECT relative_path,source_kind,state,created_at FROM media_selections WHERE id=?",[.text(selectionID)]).first,selection[2] == .text("ready"),try CoreSchema.text(selection[3])>CoreClockFrame.capture(now().addingTimeInterval(-86400),zone:zone()).instant else{throw CoreRepositoryError("MEDIA_SELECTION_EXPIRED")}
            let journal=try CoreSchema.row(sql,"journal_drafts",draftID),media=try CoreSchema.row(sql,"media_drafts",draftID),plant=try CoreSchema.row(sql,"plant_drafts",draftID)
            let plantID=journal?[2] ?? media?[2] ?? plant?[3] ?? .null
            if let media {try CoreRegistry.require(try CoreRegistry.storedIDs(media[5]).isEmpty,"MEDIA_NOT_READY")}
            for (id,kind) in [(prepID,"preparation"),(photoID,"photo")] {
                try CoreRegistry.require(id != datasetID && (try sql.query("SELECT id FROM reservations WHERE id=?",[.text(id)])).isEmpty,"FIELD_INVALID")
                try sql.execute("INSERT INTO reservations VALUES(?,?,?,0)",[.text(id),.text(kind),.text(prepID)])
            }
            try sql.execute("INSERT INTO media_preparations VALUES(?,?,?,?,?,?,?,?, 'copying',NULL,NULL,?)",[.text(prepID),.text(hash),.text(draftID),.integer(revision),.text(selectionID),.text(photoID),plantID,.text(date),.text(mediaClock())])
            let staging="staging/\(prepID).copy";try registerMediaPath(sql,staging,preparation:prepID)
            work=(try CoreSchema.text(selection[0]),try CoreSchema.text(selection[1]),media.map{try? CoreSchema.text($0[3])} ?? nil)
            return try photoPreparation(sql,prepID)
        }
        guard let work,let files=mediaFiles else{return status}
        mediaWorker.async { [self] in
            let staging="staging/\(prepID).copy"
            do {
                try files.copy(work.0,to:staging);let info=try files.inspect(staging),path="media/\(photoID)/\(info.hash).\(info.ext)"
                let replacement=work.2.map{"media/\($0)/\(info.hash).\(info.ext)"}
                try queue.sync {
                    guard sessionID==session,let current=database else{throw CoreRepositoryError("SESSION_INVALID")}
                    try current.transaction {sql in
                        try CoreRegistry.require(try sql.query("SELECT state FROM media_preparations WHERE id=?",[.text(prepID)]).first?[0] == .text("copying"),"NOT_ELIGIBLE")
                        try registerMediaPath(sql,path,preparation:prepID)
                        if let replacement {try registerMediaPath(sql,replacement,preparation:prepID)}
                    }
                }
                try files.publish(staging,to:path)
                if let replacement {
                    // Identical bytes already retained at the same immutable path
                    // need no overwrite; verify the hash before reusing them.
                    if files.exists(replacement) {try CoreRegistry.require(try files.inspect(replacement).hash==info.hash,"MEDIA_INVALID")}
                    else {try files.copy(path,to:replacement)}
                }
                try queue.sync {
                    guard sessionID==session,let current=database else{throw CoreRepositoryError("SESSION_INVALID")}
                    try current.transaction {sql in
                        try CoreRegistry.require(try sql.query("SELECT state FROM media_preparations WHERE id=?",[.text(prepID)]).first?[0] == .text("copying"),"NOT_ELIGIBLE")
                        guard let draft=try CoreRegistry.draftRow(sql,draftID),draft[1] == .integer(revision) else{throw CoreRepositoryError("STALE_TARGET")}
                        let photo:[SQLValue]=[.text(photoID),.null,.text(draftID),.integer(1),.text(path),.text(info.hash),.integer(info.bytes),.text(info.mime),.integer(info.width),.integer(info.height),.text(date),.text(work.1),.null,.text(mediaClock())]
                        try sql.execute("INSERT INTO photos VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",photo)
                        try attachPreparedPhoto(sql,draftID,photoID,revision)
                        let result:CanonicalValue = .object(["kind":.string("ready"),"preparationId":.string(prepID),"draftRevision":.integer(revision+1),"photo":CoreSchema.vector(photo)])
                        try sql.execute("UPDATE media_preparations SET state='ready',result_json=? WHERE id=?",[.text(try result.json()),.text(prepID)])
                        try sql.execute("UPDATE media_selections SET state='expired' WHERE id=?",[.text(selectionID)])
                        try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE selection_id=?",[.text(mediaClock()),.text(selectionID)])
                        try sql.execute("UPDATE reservations SET used=1 WHERE id IN (?,?)",[.text(prepID),.text(photoID)])
                        try sql.execute("UPDATE metadata SET storage_revision=storage_revision+1")
                        try CoreRegistry.validateMediaGraph(sql)
                    }
                }
            } catch {
                queue.sync {
                    guard sessionID==session,let current=database else{return}
                    pendingMediaFailures[prepID]=(session,(error as? CoreRepositoryError)?.code ?? "IO_FAILURE")
                    // Keep the failure in memory if disk-full also prevents its
                    // durable transition. Status/Retry persists it before reading.
                    try? persistMediaFailures(current)
                }
            }
            cleanupMedia()
        }
        return status
    }
    func attachPreparedPhoto(_ sql:SQLiteSession,_ draftID:String,_ photoID:String,_ revision:Int64) throws {
        if let row=try CoreSchema.row(sql,"journal_drafts",draftID) {
            var fields=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[5])))
            fields["selectedPhotoIds"] = .array((try CoreRegistry.mediaIDs(fields["selectedPhotoIds"])+[photoID]).map(CanonicalValue.string))
            let ready=try CoreRegistry.storedIDs(row[6])+[photoID]
            try CoreRegistry.validateMediaPayload("SaveJournalDraft",["draftId":.string(draftID),"expectedRevision":.integer(revision+1),"plantId":CoreSchema.canonical(row[2]),"entryId":CoreSchema.canonical(row[3]),"baseEntryRevision":CoreSchema.canonical(row[4]),"rawFields":.object(fields),"readyPhotoIds":.array(ready.map(CanonicalValue.string))])
            try sql.execute("UPDATE journal_drafts SET revision=?,raw_fields_json=?,ready_photo_ids_json=?,updated_at=? WHERE id=?",[.integer(revision+1),.text(try CanonicalValue.object(fields).json()),.text(try CanonicalValue.array(ready.map(CanonicalValue.string)).json()),.text(mediaClock()),.text(draftID)])
        } else if let row=try CoreSchema.row(sql,"media_drafts",draftID) {
            let ready=try CoreRegistry.storedIDs(row[5])+[photoID]
            try sql.execute("UPDATE media_drafts SET revision=?,ready_photo_ids_json=?,updated_at=? WHERE id=?",[.integer(revision+1),.text(try CanonicalValue.array(ready.map(CanonicalValue.string)).json()),.text(mediaClock()),.text(draftID)])
        } else {
            let row=try CoreRegistry.requiredRow(sql,"plant_drafts",draftID)
            var envelope=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[5]))),fields=try CoreSchema.object(envelope["fields"])
            fields["coverPhotoId"] = .string(photoID);envelope["fields"] = .object(fields)
            let ids=try sql.query("SELECT id FROM photos WHERE draft_id=? ORDER BY id",[.text(draftID)]).map{CoreSchema.canonical($0[0])}
            try CoreRegistry.validatePayload("SaveDraft",["draftId":.string(draftID),"expectedRevision":.integer(revision+1),"mode":CoreSchema.canonical(row[2]),"plantId":CoreSchema.canonical(row[3]),"basePlantRevision":CoreSchema.canonical(row[4]),"rawFields":.object(fields),"photoIds":.array(ids)])
            try sql.execute("UPDATE plant_drafts SET revision=?,raw_fields_json=?,updated_at=? WHERE id=?",[.integer(revision+1),.text(try CanonicalValue.object(envelope).json()),.text(mediaClock()),.text(draftID)])
        }
    }
    /// Runs on the sole media worker. Read/export operations use the same worker,
    /// so files cannot disappear during a bounded read or leased export copy.
    func cleanupMedia() {
        guard let files=mediaFiles else{return}
        let paths:[String]=queue.sync {
            guard let db=database else{return []}
            return (try? db.transaction{sql in
                let expiry=CoreClockFrame.capture(now().addingTimeInterval(-86400),zone:zone()).instant
                try sql.execute("UPDATE media_selections SET state='expired' WHERE created_at<? AND state='ready'",[.text(expiry)])
                try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE selection_id IN (SELECT id FROM media_selections WHERE state IN ('expired','failed'))",[.text(mediaClock())])
                return try sql.query("SELECT relative_path FROM media_cleanup").map{try CoreSchema.text($0[0])}
            }) ?? []
        }
        for path in paths {
            let allowed:Bool=queue.sync {
                exportLeases=exportLeases.filter{$0.value>now()}
                guard let db=database,exportLeases[path]==nil else{return false}
                return (try? db.read{sql in
                    try sql.query("SELECT id FROM photos WHERE content_path=?",[.text(path)]).isEmpty && sql.query("SELECT f.relative_path FROM media_files f JOIN media_preparations p ON p.id=f.preparation_id WHERE f.relative_path=? AND p.state IN ('copying','ready')",[.text(path)]).isEmpty && sql.query("SELECT id FROM media_selections WHERE relative_path=? AND state IN ('copying','ready')",[.text(path)]).isEmpty
                }) ?? false
            }
            if !allowed{continue}
            do {try files.remove(path);queue.sync {if let db=database {try? db.transaction{sql in try sql.execute("DELETE FROM media_cleanup WHERE relative_path=?",[.text(path)]);try sql.execute("DELETE FROM media_files WHERE relative_path=?",[.text(path)])}}}}
            catch { /* Durable cleanup task remains for the next retry. */ }
        }
    }
}
