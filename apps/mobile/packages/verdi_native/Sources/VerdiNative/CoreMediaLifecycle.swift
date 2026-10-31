import Foundation

extension CoreRepository {
    func finishMediaMutations(_ sql:SQLiteSession,_ plan:CorePlan,_ changes:[CoreDelta]) throws {
        for d in changes where d.table=="photos" && d.before != nil {
            let old=d.before!
            if d.action=="delete" || (d.action=="update" && old[4] != d.values[4]) {
                try sql.execute("INSERT OR IGNORE INTO media_cleanup VALUES(?,?)",[old[4],.text(mediaClock())])
            }
            if old[2] != .null && (d.action=="delete" || d.values[2] == .null) {
                let consumed = d.action != "delete" || plan.type=="ReplacePhoto"
                try tombstonePreparation(sql,photo:d.id,state:consumed ? "consumed":"deleted")
            } else if d.action=="delete" {try tombstonePreparation(sql,photo:d.id,state:"deleted")}
        }
        for d in changes where CoreRegistry.draftTables.contains(d.table) && d.action=="delete" {
            for row in try sql.query("SELECT photo_id FROM media_preparations WHERE draft_id=? AND state='copying'",[.text(d.id)]) {try tombstonePreparation(sql,photo:CoreSchema.text(row[0]),state:"deleted")}
        }
    }
    func tombstonePreparation(_ sql:SQLiteSession,photo:String,state:String) throws {
        for row in try sql.query("SELECT id,draft_revision,result_json FROM media_preparations WHERE photo_id=? AND state NOT IN ('deleted','consumed')",[.text(photo)]) {
            var revision=try CoreSchema.integer(row[1])
            if row[2] != .null {let result=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[2])));revision=result["draftRevision"]?.integer ?? revision}
            let result:CanonicalValue = .object(["kind":.string(state),"preparationId":CoreSchema.canonical(row[0]),"photoId":.string(photo),"draftRevision":.integer(revision)])
            try sql.execute("UPDATE media_preparations SET state=?,observed_date=NULL,plant_id=NULL,error_code=NULL,result_json=? WHERE id=?",[.text(state),.text(try result.json()),row[0]])
            try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE preparation_id=?",[.text(mediaClock()),row[0]])
        }
    }
    public func mediaPreview(photoID:String,completion:@escaping(Result<Data,Error>)->Void) {
        mediaWorker.async { [self] in
            do {
                let pair:(MediaFiles,String)=try queue.sync {
                    guard let db=database,let files=mediaFiles else{throw CoreRepositoryError("SESSION_INVALID")}
                    let path=try db.read{sql -> String in try CoreRegistry.originalPath(CoreRegistry.requiredRow(sql,"photos",photoID))}
                    return (files,path)
                }
                completion(.success(try pair.0.preview(pair.1)))
            } catch {completion(.failure(error))}
        }
    }
    /// The leased original copy is only shared after explicit UI confirmation.
    /// It is independent of managed originals and removed by the OS-sheet owner.
    public func exportOriginal(photoID:String,revision:Int64,completion:@escaping(Result<URL,Error>)->Void) {
        mediaWorker.async { [self] in
            do {
                let pair:(MediaFiles,String)=try queue.sync {
                    guard let db=database,let files=mediaFiles else{throw CoreRepositoryError("SESSION_INVALID")}
                    let path=try db.read{sql -> String in
                        let p=try CoreRegistry.requiredRow(sql,"photos",photoID)
                        try CoreRegistry.require(p[1] != .null && p[3] == .integer(revision),"STALE_TARGET")
                        return try CoreRegistry.originalPath(p)
                    };return(files,path)
                }
                let ext=(pair.1 as NSString).pathExtension,path="exports/\(UUID().uuidString.lowercased()).\(ext)"
                let session=try queue.sync { () throws -> String in
                    guard let db=database,!sessionID.isEmpty else{throw CoreRepositoryError("SESSION_INVALID")}
                    try db.transaction {sql in try registerMediaPath(sql,path);try sql.execute("INSERT INTO media_cleanup VALUES(?,?)",[.text(path),.text(mediaClock())])}
                    exportLeases[path]=now().addingTimeInterval(86400);return sessionID
                }
                do {try pair.0.copy(pair.1,to:path)
                    try queue.sync {
                        guard sessionID==session,let db=database else{throw CoreRepositoryError("SESSION_INVALID")}
                        try db.read{sql in let row=try CoreRegistry.requiredRow(sql,"photos",photoID);try CoreRegistry.require(row[3] == .integer(revision),"STALE_TARGET")}
                    }
                } catch {queue.sync{_ = exportLeases.removeValue(forKey:path)};cleanupMedia();throw error}
                completion(.success(pair.0.root.appendingPathComponent(path)))
            } catch {completion(.failure(error))}
        }
    }
    public func releaseExport(_ url:URL) {
        mediaWorker.async { [self] in
            guard let files=mediaFiles,url.deletingLastPathComponent()==files.root.appendingPathComponent("exports") else{return}
            queue.sync {_ = exportLeases.removeValue(forKey:"exports/"+url.lastPathComponent)}
            cleanupMedia()
        }
    }
}

extension CoreRepository {
    func validateNewPhotoLinks(_ sql:SQLiteSession,_ plan:CorePlan,_ changes:[CoreDelta]) throws {
        guard let files=mediaFiles else{throw CoreRepositoryError("SESSION_INVALID")}
        for change in changes {
            var selected:[String]=[],previous:[String]=[]
            if change.table=="plant_covers" && change.action != "delete" {
                selected=[try CoreSchema.text(change.values[1])]
                if let old=change.before {previous=[try CoreSchema.text(old[1])]}
            } else if change.table=="journal_entries" && change.action != "delete" {
                selected=try CoreRegistry.storedIDs(change.values[5])
                if let old=change.before {previous=try CoreRegistry.storedIDs(old[5])}
            }
            for id in selected where !previous.contains(id) {
                let photo=try CoreRegistry.requiredRow(sql,"photos",id)
                guard files.exists(try CoreRegistry.originalPath(photo)) else{throw CoreRepositoryError("MEDIA_MISSING")}
            }
        }
    }
}
