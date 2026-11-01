import Foundation

extension CoreRepository {
    func beginOptimizationPreparation(_ db:SQLiteDatabase,job:String,photo:String) throws -> CanonicalValue {
        try CoreSchema.uuid(job);try CoreSchema.uuid(photo)
        let session=sessionID,photoID=UUID().uuidString.lowercased()
        var work:([SQLValue],[SQLValue])?
        let status=try db.transaction {sql -> CanonicalValue in
            try optimizationRunning(sql,job)
            let target=try optimizationTarget(sql,job,photo),prep=try CoreSchema.text(target[7]),draft=try CoreSchema.text(target[5])
            try CoreRegistry.require(target[9] == .text("pending"),"NOT_ELIGIBLE")
            let source=try optimizationSource(sql,target)
            if try sql.query("SELECT id FROM media_preparations WHERE id=?",[target[7]]).first != nil {return try photoPreparation(sql,prep)}
            guard let row=try CoreSchema.row(sql,"media_drafts",draft),row[1] == .integer(1),row[2]==source[1],row[3]==source[0],row[4]==source[3],try CoreRegistry.storedIDs(row[5]).isEmpty else{throw CoreRepositoryError("DRAFT_CONFLICT")}
            try CoreRegistry.require(try receipt(sql,CoreSchema.text(target[6]),hash:nil) != nil,"MEDIA_NOT_READY")
            for (id,kind) in [(prep,"preparation"),(photoID,"photo")] {
                try CoreRegistry.require(try sql.query("SELECT id FROM reservations WHERE id=?",[.text(id)]).isEmpty && id != datasetID,"COMMAND_ID_REUSED")
                try sql.execute("INSERT INTO reservations VALUES(?,?,?,0)",[.text(id),.text(kind),.text(prep)])
            }
            let request:CanonicalValue = .object(["jobId":.string(job),"photoId":.string(photo),"sourceHash":CoreSchema.canonical(source[5]),"longEdge":.integer(1280),"jpegQualityPercent":.integer(85)])
            try sql.execute("INSERT INTO media_preparations VALUES(?,?,?,1,?,?,?,?,'copying',NULL,NULL,?)",[target[7],.text(try CanonicalCommand.hash(request)),target[5],.text(job),.text(photoID),source[1],source[10],.text(mediaClock())])
            try registerMediaPath(sql,"staging/\(prep).optimized",preparation:prep)
            work=(target,source)
            return try photoPreparation(sql,prep)
        }
        guard let work,let files=mediaFiles else{return status}
        let target=work.0,source=work.1,prep=try CoreSchema.text(target[7]),draft=try CoreSchema.text(target[5])
        let lease=UUID().uuidString.lowercased();platformLeases[lease]=datasetID
        mediaWorker.async { [self] in
            defer {queue.sync{_ = platformLeases.removeValue(forKey:lease)};cleanupMedia()}
            do {
                let bytes=try PhotoOptimizer.render(files,CoreRegistry.originalPath(source),expectedHash:CoreSchema.text(source[5]))
                let staging="staging/\(prep).optimized"
                try files.writeGeneratedImage(bytes,to:staging)
                let info=try files.inspect(staging),path="media/\(photoID)/\(info.hash).jpg",replacement="media/\(photo)/\(info.hash).jpg"
                try queue.sync {
                    guard sessionID==session,let current=database else{throw CoreRepositoryError("SESSION_INVALID")}
                    try current.transaction {sql in
                        try optimizationRunning(sql,job);_ = try optimizationSource(sql,target)
                        try CoreRegistry.require(try sql.query("SELECT state FROM media_preparations WHERE id=?",[.text(prep)]).first?[0] == .text("copying"),"NOT_ELIGIBLE")
                        try registerMediaPath(sql,path,preparation:prep);try registerMediaPath(sql,replacement,preparation:prep)
                    }
                }
                try files.publish(staging,to:path)
                if files.exists(replacement) {try CoreRegistry.require(try files.inspect(replacement).hash==info.hash,"MEDIA_INVALID")}
                else {try files.copy(path,to:replacement)}
                try queue.sync {
                    guard sessionID==session,let current=database else{throw CoreRepositoryError("SESSION_INVALID")}
                    try current.transaction {sql in
                        try optimizationRunning(sql,job);_ = try optimizationSource(sql,target)
                        try CoreRegistry.require(try sql.query("SELECT state FROM media_preparations WHERE id=?",[.text(prep)]).first?[0] == .text("copying"),"NOT_ELIGIBLE")
                        let d=try CoreRegistry.requiredRow(sql,"media_drafts",draft)
                        try CoreRegistry.require(d[1] == .integer(1) && d[2]==source[1] && d[3]==source[0] && d[4]==source[3] && (try CoreRegistry.storedIDs(d[5])).isEmpty,"DRAFT_CONFLICT")
                        let row:[SQLValue]=[.text(photoID),.null,.text(draft),.integer(1),.text(path),.text(info.hash),.integer(info.bytes),.text(info.mime),.integer(info.width),.integer(info.height),source[10],source[11],source[5],.text(mediaClock())]
                        try sql.execute("INSERT INTO photos VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",row)
                        try attachPreparedPhoto(sql,draft,photoID,1)
                        let result:CanonicalValue = .object(["kind":.string("ready"),"preparationId":.string(prep),"draftRevision":.integer(2),"photo":CoreSchema.vector(row)])
                        try sql.execute("UPDATE media_preparations SET state='ready',result_json=? WHERE id=?",[.text(try result.json()),.text(prep)])
                        try sql.execute("UPDATE reservations SET used=1 WHERE id IN (?,?)",[.text(prep),.text(photoID)])
                        try sql.execute("UPDATE metadata SET storage_revision=storage_revision+1")
                        try CoreRegistry.validateMediaGraph(sql)
                    }
                }
            } catch {
                queue.sync {
                    guard sessionID==session,let current=database else{return}
                    pendingMediaFailures[prep]=(session,(error as? CoreRepositoryError)?.code ?? "IO_FAILURE")
                    try? persistMediaFailures(current)
                }
            }
        }
        return status
    }
}
