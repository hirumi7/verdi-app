import Foundation

extension CoreRepository {
    func storeAttempt(_ request: String) throws -> StoreAttempt {
        try queue.sync {
            guard !replacementAdmissionClosed,let db=database,!sessionID.isEmpty else {throw CoreRepositoryError("BUSY")}
            let p=try CoreSchema.object(CanonicalParser.parse(request))
            guard Set(p.keys) == Set(["intentId","datasetId","commandId","payloadHash"]),p["datasetId"]?.text == datasetID else {throw CoreRepositoryError("DATASET_CHANGED")}
            let intent=try CoreSchema.string(p["intentId"]);try CoreSchema.uuid(intent)
            let id=p["commandId"]?.text,hash=p["payloadHash"]?.text
            guard (id == nil) == (hash == nil),id != nil || (p["commandId"]?.isNull == true && p["payloadHash"]?.isNull == true) else {throw CoreRepositoryError("FIELD_INVALID")}
            var draftID:String?,draftRevision:Int64?
            if let id,let hash {
                try CoreSchema.uuid(id)
                try db.read { sql in
                    let rows=try sql.query("SELECT type,hash,body,status FROM intents WHERE id=?",[.text(id)])
                    guard let row=rows.first,row[1] == .text(hash),row[3] == .text("pending") else {throw CoreRepositoryError("NOT_ELIGIBLE")}
                    let frozen=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[2])))
                    let payload=try CoreSchema.object(frozen["normalisedPayload"])
                    switch try CoreSchema.text(row[0]) {
                    case "SavePlant":
                        let draft=try CoreSchema.string(payload["draftId"]),revision=try CoreSchema.number(payload["draftRevision"])
                        let rows=try sql.query("SELECT revision,mode FROM plant_drafts WHERE id=?",[.text(draft)])
                        guard rows.first == [.integer(revision),.text("add")] else {throw CoreRepositoryError("DRAFT_CONFLICT")}
                        draftID=draft;draftRevision=revision
                    case "RestorePlant":
                        let plant=try CoreSchema.string(payload["plantId"]),revision=try CoreSchema.number(payload["plantRevision"])
                        let rows=try sql.query("SELECT revision,archived FROM plants WHERE id=?",[.text(plant)])
                        guard rows.first == [.integer(revision),.integer(1)] else {throw CoreRepositoryError("STALE_TARGET")}
                    case "CreateCustomCareType": break
                    case "CreateRoutine":
                        guard payload["careKind"]?.text == "custom" else {throw CoreRepositoryError("NOT_ELIGIBLE")}
                        let plant=try CoreSchema.string(payload["plantId"]),revision=try CoreSchema.number(payload["plantRevision"])
                        guard try sql.query("SELECT revision,archived FROM plants WHERE id=?",[.text(plant)]).first == [.integer(revision),.integer(0)] else {throw CoreRepositoryError("STALE_TARGET")}
                        let type=try CoreSchema.string(payload["customTypeId"]),typeRevision=try CoreSchema.number(payload["customTypeRevision"])
                        guard try sql.query("SELECT revision,retired FROM custom_care_types WHERE id=?",[.text(type)]).first == [.integer(typeRevision),.integer(0)] else {throw CoreRepositoryError("STALE_TARGET")}
                    default:throw CoreRepositoryError("NOT_ELIGIBLE")
                    }
                }
            }
            return StoreAttempt(intentID:intent,datasetID:datasetID,commandID:id,payloadHash:hash,draftID:draftID,draftRevision:draftRevision,phase:"prepared",continuationAbandoned:false)
        }
    }
}
