import Foundation

struct OptimizationPreview {
    let dataset:String, plant:String, rows:[[SQLValue]], created:TimeInterval
}

extension CoreRepository {
    static let optimizationOperations:Set<String> = ["previewOptimization","startOptimization","getOptimizationJob","latestOptimizationJob","prepareOptimizationPhoto","finishOptimizationTarget","stopOptimization"]
    static let optimizationFailures:Set<String> = ["FIELD_INVALID","STALE_TARGET","DRAFT_CONFLICT","NOT_FOUND","MEDIA_UNSUPPORTED","MEDIA_INVALID","MEDIA_MISSING","MEDIA_TOO_LARGE","MEDIA_NOT_READY","IO_FAILURE","DISK_FULL","NOT_ELIGIBLE"]
    func optimizationTarget(_ sql:SQLiteSession,_ job:String,_ photo:String) throws -> [SQLValue] {
        try CoreSchema.uuid(job);try CoreSchema.uuid(photo)
        guard let row=try sql.query("SELECT * FROM optimization_targets WHERE job_id=? AND photo_id=?",[.text(job),.text(photo)]).first else{throw CoreRepositoryError("NOT_FOUND")}
        return row
    }
    func optimizationRunning(_ sql:SQLiteSession,_ job:String) throws {
        try CoreRegistry.require(try sql.query("SELECT state FROM optimization_jobs WHERE id=?",[.text(job)]).first?[0] == .text("running"),"NOT_ELIGIBLE")
    }
    func optimizationSource(_ sql:SQLiteSession,_ target:[SQLValue]) throws -> [SQLValue] {
        let photo=try CoreRegistry.requiredRow(sql,"photos",CoreSchema.text(target[2]))
        try CoreRegistry.require(photo[1] != .null && photo[3]==target[3] && photo[5]==target[4],"STALE_TARGET")
        return photo
    }
    func optimizationStatus(_ sql:SQLiteSession,_ id:String) throws -> CanonicalValue {
        try CoreSchema.uuid(id)
        guard let job=try sql.query("SELECT plant_id,state FROM optimization_jobs WHERE id=?",[.text(id)]).first else{throw CoreRepositoryError("NOT_FOUND")}
        let results=try sql.query("SELECT * FROM optimization_targets WHERE job_id=? ORDER BY ordinal",[.text(id)]).map { r -> CanonicalValue in
            var item:[String:CanonicalValue]=[:]
            for (key,index) in [("photoId",2),("photoRevision",3),("draftId",5),("draftCommandId",6),("preparationId",7),("replaceCommandId",8),("state",9),("code",10)] {item[key]=CoreSchema.canonical(r[index])}
            return .object(item)
        }
        return .object(["jobId":.string(id),"plantId":CoreSchema.canonical(job[0]),"state":CoreSchema.canonical(job[1]),"results":.array(results),"cancelAllowed":.boolean(job[1] == .text("running"))])
    }
    func abandonOptimizationChildren(_ sql:SQLiteSession,_ row:[SQLValue]) throws {
        for index in [6,8] {
            try sql.execute("UPDATE intents SET body=NULL,status='abandoned' WHERE id=? AND status='pending'",[row[index]])
            let id=try CoreSchema.text(row[index]);previews=previews.filter{$0.value.command != id}
        }
        if let prep=try sql.query("SELECT draft_revision FROM media_preparations WHERE id=? AND state='copying'",[row[7]]).first {
            let result:CanonicalValue = .object(["kind":.string("failed"),"preparationId":CoreSchema.canonical(row[7]),"code":.string("NOT_ELIGIBLE"),"draftRevision":CoreSchema.canonical(prep[0])])
            try sql.execute("UPDATE media_preparations SET state='failed',error_code='NOT_ELIGIBLE',result_json=? WHERE id=?",[.text(try result.json()),row[7]])
            try sql.execute("INSERT OR IGNORE INTO media_cleanup SELECT relative_path,? FROM media_files WHERE preparation_id=?",[.text(mediaClock()),row[7]])
        }
    }
    func optimizationSucceeded(_ sql:SQLiteSession,_ row:[SQLValue]) throws -> Bool {
        // This child ID is accepted only for its compiled replacement payload.
        guard try receipt(sql,CoreSchema.text(row[8]),hash:nil) != nil else{return false}
        try sql.execute("UPDATE optimization_targets SET state='succeeded',code=NULL WHERE job_id=? AND ordinal=?",[row[0],row[1]])
        return true
    }
    func stopOptimization(_ sql:SQLiteSession,_ id:String,_ reason:String) throws -> CanonicalValue {
        let status=try optimizationStatus(sql,id)
        if status.object?["state"]?.text != "running" {return status}
        for row in try sql.query("SELECT * FROM optimization_targets WHERE job_id=? AND state='pending' ORDER BY ordinal",[.text(id)]) {
            if try !optimizationSucceeded(sql,row) {
                try abandonOptimizationChildren(sql,row)
                try sql.execute("UPDATE optimization_targets SET state='not_attempted',code=NULL WHERE job_id=? AND ordinal=?",[row[0],row[1]])
            }
        }
        try sql.execute("UPDATE optimization_jobs SET state=? WHERE id=?",[.text(reason),.text(id)])
        return try optimizationStatus(sql,id)
    }
    func recoverOptimizations(_ db:SQLiteDatabase) throws {
        try db.transaction {sql in
            for row in try sql.query("SELECT id FROM optimization_jobs WHERE state='running'") {_ = try stopOptimization(sql,CoreSchema.text(row[0]),"interrupted")}
        }
        platformLeases=platformLeases.filter{!$0.key.hasPrefix("optimization/")}
    }
    func optimizationCall(_ operation:String,_ args:[String:CanonicalValue],_ db:SQLiteDatabase) throws -> CanonicalValue {
        switch operation {
        case "previewOptimization":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","datasetId","plantId","targets","longEdge","jpegQualityPercent"]) && args["datasetId"]?.text==datasetID,"DATASET_CHANGED")
            try CoreRegistry.require(args["longEdge"]?.integer==1280 && args["jpegQualityPercent"]?.integer==85,"FIELD_INVALID")
            let plant=try CoreSchema.string(args["plantId"]),targets=try CoreSchema.array(args["targets"])
            try CoreSchema.uuid(plant);try CoreRegistry.require((1...200).contains(targets.count),"FIELD_INVALID")
            let rows=try db.read {sql -> [[SQLValue]] in
                _ = try CoreRegistry.requiredRow(sql,"plants",plant)
                try CoreRegistry.require(try sql.query("SELECT id FROM optimization_jobs WHERE state='running'").isEmpty,"MEDIA_BUSY")
                var ids=Set<String>()
                return try targets.map { value in
                    let t=try CoreSchema.object(value),id=try CoreSchema.string(t["photoId"]),revision=try CoreSchema.number(t["photoRevision"])
                    try CoreSchema.uuid(id);try CoreRegistry.require(Set(t.keys)==Set(["photoId","photoRevision"]) && revision>0 && ids.insert(id).inserted,"FIELD_INVALID")
                    let row=try CoreRegistry.requiredRow(sql,"photos",id)
                    try CoreRegistry.require(row[1] == .text(plant) && row[3] == .integer(revision),"STALE_TARGET")
                    try CoreRegistry.require(try sql.query("SELECT id FROM media_drafts WHERE photo_id=?",[.text(id)]).isEmpty,"DRAFT_CONFLICT")
                    return row
                }
            }
            optimizationPreviews=optimizationPreviews.filter{elapsed()>=$0.value.created && elapsed()-$0.value.created<600}
            if optimizationPreviews.count>=8,let oldest=optimizationPreviews.min(by:{$0.value.created<$1.value.created})?.key {optimizationPreviews.removeValue(forKey:oldest)}
            let token=UUID().uuidString.lowercased();optimizationPreviews[token]=OptimizationPreview(dataset:datasetID,plant:plant,rows:rows,created:elapsed())
            return .object(["previewToken":.string(token),"longEdge":.integer(1280),"jpegQualityPercent":.integer(85),"targets":.array(rows.map{r in .object(["photoId":CoreSchema.canonical(r[0]),"photoRevision":CoreSchema.canonical(r[3]),"observedDate":CoreSchema.canonical(r[10]),"width":CoreSchema.canonical(r[8]),"height":CoreSchema.canonical(r[9]),"byteCount":CoreSchema.canonical(r[6])])})])
        case "startOptimization":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","datasetId","jobId","previewToken"]) && args["datasetId"]?.text==datasetID,"DATASET_CHANGED")
            let id=try CoreSchema.string(args["jobId"]),token=try CoreSchema.string(args["previewToken"]);try CoreSchema.uuid(id);try CoreSchema.uuid(token)
            var input=args;input.removeValue(forKey:"sessionId");input["longEdge"] = .integer(1280);input["jpegQualityPercent"] = .integer(85);let hash=try CanonicalCommand.hash(.object(input))
            let result=try db.transaction {sql -> CanonicalValue in
                if let old=try sql.query("SELECT request_hash FROM optimization_jobs WHERE id=?",[.text(id)]).first {
                    try CoreRegistry.require(old[0] == .text(hash),"COMMAND_ID_REUSED");return try optimizationStatus(sql,id)
                }
                guard let p=optimizationPreviews[token],p.dataset==datasetID,elapsed()>=p.created,elapsed()-p.created<600 else{throw CoreRepositoryError("PREVIEW_STALE")}
                try CoreRegistry.require(try sql.query("SELECT id FROM optimization_jobs WHERE state='running'").isEmpty,"MEDIA_BUSY")
                try CoreRegistry.require(try optimizationIdentityFree(sql,id),"COMMAND_ID_REUSED")
                for row in p.rows {
                    try CoreRegistry.require(try CoreSchema.row(sql,"photos",CoreSchema.text(row[0]))==row,"PREVIEW_STALE")
                    try CoreRegistry.require(try sql.query("SELECT id FROM media_drafts WHERE photo_id=?",[row[0]]).isEmpty,"DRAFT_CONFLICT")
                }
                try sql.execute("INSERT INTO optimization_jobs VALUES(?,?,?,?, 'running',?)",[.text(id),.text(p.plant),.text(hash),.text(try CanonicalValue.object(["longEdge":.integer(1280),"jpegQualityPercent":.integer(85),"targets":.array(p.rows.map{.object(["photoId":CoreSchema.canonical($0[0]),"photoRevision":CoreSchema.canonical($0[3])])})]).json()),.text(mediaClock())])
                for (index,row) in p.rows.enumerated() {
                    var ids:[String]=[]
                    while ids.count<4 {let candidate=UUID().uuidString.lowercased();if !ids.contains(candidate),try optimizationIdentityFree(sql,candidate){ids.append(candidate)}}
                    try sql.execute("INSERT INTO optimization_targets VALUES(?,?,?,?,?,?,?,?,?,'pending',NULL)",[.text(id),.integer(Int64(index)),row[0],row[3],row[5]]+ids.map(SQLValue.text))
                }
                return try optimizationStatus(sql,id)
            }
            optimizationPreviews.removeValue(forKey:token)
            if result.object?["state"]?.text=="running" {platformLeases["optimization/"+id]=datasetID}
            return result
        case "getOptimizationJob":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","jobId"]),"FIELD_INVALID")
            return try db.read{try optimizationStatus($0,CoreSchema.string(args["jobId"]))}
        case "latestOptimizationJob":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","plantId"]),"FIELD_INVALID")
            let plant=try CoreSchema.string(args["plantId"]);try CoreSchema.uuid(plant)
            return try db.read {sql in
                guard let row=try sql.query("SELECT id FROM optimization_jobs WHERE plant_id=? ORDER BY rowid DESC LIMIT 1",[.text(plant)]).first else{return .null}
                return try optimizationStatus(sql,CoreSchema.text(row[0]))
            }
        case "prepareOptimizationPhoto":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","jobId","photoId"]),"FIELD_INVALID")
            return try beginOptimizationPreparation(db,job:CoreSchema.string(args["jobId"]),photo:CoreSchema.string(args["photoId"]))
        case "finishOptimizationTarget":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","jobId","photoId","code"]),"FIELD_INVALID")
            let job=try CoreSchema.string(args["jobId"]),photo=try CoreSchema.string(args["photoId"]),code=args["code"]
            try CoreRegistry.require(code?.isNull==true || Self.optimizationFailures.contains(code?.text ?? ""),"FIELD_INVALID")
            let result=try db.transaction {sql -> CanonicalValue in
                let t=try optimizationTarget(sql,job,photo)
                if t[9] != .text("pending") {return try optimizationStatus(sql,job)}
                try optimizationRunning(sql,job)
                if try !optimizationSucceeded(sql,t) {
                    guard let failure=code?.text else{throw CoreRepositoryError("RECOVERY_REQUIRED")}
                    try abandonOptimizationChildren(sql,t)
                    try sql.execute("UPDATE optimization_targets SET state='failed',code=? WHERE job_id=? AND photo_id=?",[.text(failure),.text(job),.text(photo)])
                }
                if try sql.query("SELECT photo_id FROM optimization_targets WHERE job_id=? AND state='pending'",[.text(job)]).isEmpty {try sql.execute("UPDATE optimization_jobs SET state='complete' WHERE id=?",[.text(job)])}
                return try optimizationStatus(sql,job)
            }
            if result.object?["state"]?.text != "running" {platformLeases.removeValue(forKey:"optimization/"+job)}
            return result
        case "stopOptimization":
            try CoreRegistry.require(Set(args.keys)==Set(["sessionId","jobId","reason"]) && ["cancelled","interrupted"].contains(args["reason"]?.text ?? ""),"FIELD_INVALID")
            let job=try CoreSchema.string(args["jobId"])
            let result=try db.transaction{try stopOptimization($0,job,CoreSchema.string(args["reason"]))}
            platformLeases.removeValue(forKey:"optimization/"+job)
            return result
        default: throw CoreRepositoryError("PROTOCOL_INCOMPATIBLE")
        }
    }
    func optimizationLedgerReserved(_ sql:SQLiteSession,_ id:String) throws -> Bool {
        if try !sql.query("SELECT id FROM optimization_jobs WHERE id=?",[.text(id)]).isEmpty {return true}
        return try !sql.query("SELECT job_id FROM optimization_targets WHERE draft_id=? OR draft_command_id=? OR preparation_id=? OR replace_command_id=?",Array(repeating:.text(id),count:4)).isEmpty
    }
    func optimizationIdentityFree(_ sql:SQLiteSession,_ id:String) throws -> Bool {
        guard id != datasetID,try sql.query("SELECT id FROM reservations WHERE id=?",[.text(id)]).isEmpty,
              try sql.query("SELECT id FROM optimization_jobs WHERE id=?",[.text(id)]).isEmpty else{return false}
        return try sql.query("SELECT job_id FROM optimization_targets WHERE draft_id=? OR draft_command_id=? OR preparation_id=? OR replace_command_id=?",Array(repeating:.text(id),count:4)).isEmpty
    }
    func guardOptimizationCommand(_ sql:SQLiteSession,id:String,type:String,payload:[String:CanonicalValue],allocated:[String]=[]) throws {
        let owned=try sql.query("SELECT t.* FROM optimization_targets t WHERE draft_command_id=? OR replace_command_id=?",[.text(id),.text(id)]).first
        if let t=owned {
            if try receipt(sql,id,hash:nil) != nil {return}
            try optimizationRunning(sql,CoreSchema.text(t[0]));try CoreRegistry.require(t[9] == .text("pending"),"NOT_ELIGIBLE")
            let draft=try CoreSchema.text(t[5]),source=try optimizationSource(sql,t)
            if t[6] == .text(id) {
                try CoreRegistry.require(type=="SaveMediaDraft" && payload["draftId"]?.text==draft && (try CoreSchema.same(payload["photoId"],CoreSchema.canonical(t[2]))) && (try CoreSchema.same(payload["basePhotoRevision"],CoreSchema.canonical(t[3]))) && (try CoreSchema.same(payload["plantId"],CoreSchema.canonical(source[1]))) && payload["expectedRevision"]?.isNull==true && payload["readyPhotoIds"]?.array?.isEmpty==true,"FIELD_INVALID")
            } else {
                try CoreRegistry.require(type=="ReplacePhoto" && (try CoreSchema.same(payload["photoId"],CoreSchema.canonical(t[2]))) && (try CoreSchema.same(payload["photoRevision"],CoreSchema.canonical(t[3]))) && payload["draftId"]?.text==draft && (try CoreSchema.same(payload["preparationId"],CoreSchema.canonical(t[7]))),"FIELD_INVALID")
            }
        } else {
            try CoreRegistry.require(try !optimizationLedgerReserved(sql,id),"COMMAND_ID_REUSED")
        }
        for candidate in allocated {try CoreRegistry.require(try !optimizationLedgerReserved(sql,candidate),"COMMAND_ID_REUSED")}
        if ["SaveDraft","SaveJournalDraft","SaveMediaDraft"].contains(type),let draft=payload["draftId"]?.text,try optimizationLedgerReserved(sql,draft) {
            let child = type=="SaveMediaDraft" && owned?[5] == .text(draft) && owned?[6] == .text(id)
            let existing = try sql.query("SELECT d.id FROM media_drafts d JOIN optimization_targets t ON t.draft_id=d.id JOIN optimization_jobs j ON j.id=t.job_id WHERE d.id=? AND j.state!='running'",[.text(draft)]).first != nil
            try CoreRegistry.require(child || (type=="SaveMediaDraft" && existing),"COMMAND_ID_REUSED")
        }
        if let draft=payload["draftId"]?.text,let t=try sql.query("SELECT t.*,j.state FROM optimization_targets t JOIN optimization_jobs j ON j.id=t.job_id WHERE t.draft_id=?",[.text(draft)]).first {
            if t[11] == .text("running") {try CoreRegistry.require(owned != nil && owned![0]==t[0] && owned![2]==t[2],"MEDIA_BUSY")}
            else if type=="SaveMediaDraft",payload["expectedRevision"]?.isNull==true {throw CoreRepositoryError("COMMAND_ID_REUSED")}
        }
        if let prep=payload["preparationId"]?.text,let row=try sql.query("SELECT t.replace_command_id,j.state FROM optimization_targets t JOIN optimization_jobs j ON j.id=t.job_id WHERE preparation_id=?",[.text(prep)]).first {try CoreRegistry.require(row[0] == .text(id) || row[1] != .text("running"),"MEDIA_BUSY")}
    }
    func guardOrdinaryPreparation(_ sql:SQLiteSession,_ draft:String,_ prep:String) throws {
        try CoreRegistry.require(try !optimizationLedgerReserved(sql,prep),"COMMAND_ID_REUSED")
        try CoreRegistry.require(try sql.query("SELECT t.job_id FROM optimization_targets t JOIN optimization_jobs j ON j.id=t.job_id WHERE t.draft_id=? AND j.state='running'",[.text(draft)]).isEmpty,"MEDIA_BUSY")
    }
}
