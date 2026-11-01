import Foundation

extension CoreRegistry {
    static func validatePlantMedia(_ sql:SQLiteSession,_ p:CorePlan,_ d:[CoreDelta],draft:[SQLValue],plant:String?) throws {
        let id=try CoreSchema.text(draft[0]),fields=try CoreSchema.object(CoreSchema.object(CanonicalParser.parse(CoreSchema.text(draft[5])))["fields"]),cover=plant == nil ? nil:fields["coverPhotoId"]?.text
        let owned=try sql.query("SELECT id FROM photos WHERE draft_id=?",[.text(id)]).map{try CoreSchema.text($0[0])},changes=d.filter{$0.table=="photos"}
        try require(Set(changes.map(\.id))==Set(owned))
        for photo in changes {
            if photo.id==cover {
                try require(photo.action=="update" && photo.values[1] == .text(plant!) && photo.values[2] == .null)
                for i in 4...13 {try require(photo.values[i]==photo.before![i])}
            } else {try require(photo.action=="delete")}
        }
        let covers=d.filter{$0.table=="plant_covers"}
        guard let plant else{try require(covers.isEmpty);return}
        let old=try CoreSchema.row(sql,"plant_covers",plant)
        if let cover {
            let photo=try requiredRow(sql,"photos",cover)
            try require(photo[1] == .text(plant) || photo[2] == .text(id))
            if old?[1] == .text(cover) {try require(covers.isEmpty)}
            else {try require(covers.count==1 && covers[0].id==plant && covers[0].action==(old==nil ? "insert":"update") && covers[0].values[1] == .text(cover))}
        } else if old != nil {try require(covers.count==1 && covers[0].id==plant && covers[0].action=="delete")}
        else {try require(covers.isEmpty)}
    }
    static func ownedMediaDrafts(_ sql:SQLiteSession,_ plant:String,_ table:String) throws -> CanonicalValue {
        try require(["journal_drafts","media_drafts"].contains(table))
        return .array(try sql.query("SELECT id,revision FROM \(table) WHERE plant_id=? ORDER BY id",[.text(plant)]).map{.object(["draftId":CoreSchema.canonical($0[0]),"revision":CoreSchema.canonical($0[1])])})
    }
    static func mediaDeleteGuards(_ sql:SQLiteSession,_ delta:CoreDelta,_ guards:[CanonicalValue]) throws {
        let plant=delta.id,journal=try ownedMediaDrafts(sql,plant,"journal_drafts"),media=try ownedMediaDrafts(sql,plant,"media_drafts")
        let count=try CoreSchema.integer(sql.query("SELECT count(*) FROM journal_entries WHERE plant_id=?",[.text(plant)])[0][0])
        let photos=try CoreSchema.integer(sql.query("SELECT count(*) FROM photos WHERE plant_id=? OR draft_id IN (SELECT id FROM plant_drafts WHERE plant_id=? UNION SELECT id FROM journal_drafts WHERE plant_id=? UNION SELECT id FROM media_drafts WHERE plant_id=?)",Array(repeating:.text(plant),count:4))[0][0])
        if delta.raw.count==10 {
            try require(count==0 && photos==0 && journal.array!.isEmpty && media.array!.isEmpty && (try sql.query("SELECT id FROM media_preparations WHERE plant_id=?",[.text(plant)])).isEmpty,"PREVIEW_STALE")
        } else {
            try require([14,15].contains(delta.raw.count) && delta.raw[10].integer==count && delta.raw[11].integer==photos && (try CoreSchema.same(delta.raw[12],journal)) && (try CoreSchema.same(delta.raw[13],media)),"PREVIEW_STALE")
        }
        let mappings=try CoreSchema.integer(sql.query("SELECT count(*) FROM routine_custom_types l JOIN routines r ON r.id=l.id WHERE r.plant_id=?",[.text(plant)])[0][0])
        try require(delta.raw.count==15 ? delta.raw[14].integer==mappings : mappings==0,"PREVIEW_STALE")
        let all=(try ownedDrafts(sql,plant).array! + journal.array! + media.array!).sorted{($0.object?["draftId"]?.text ?? "")<($1.object?["draftId"]?.text ?? "")}
        try require(try CoreSchema.same(.array(guards),.array(all)),"PREVIEW_STALE")
    }
}

extension CoreRegistry {
    /// Binds operational preparation state and empty draft sets without making
    /// unrelated draft autosaves invalidate a content confirmation.
    static func mediaPreviewFingerprint(_ sql:SQLiteSession,_ p:CorePlan) throws -> String {
        var drafts:Set<String>=[],parts:[CanonicalValue]=[]
        if let id=p.payload["draftId"]?.text {drafts.insert(id)}
        if p.type=="DeletePlant",let id=p.payload["plantId"]?.text {
            for table in draftTables {for row in try sql.query("SELECT id,revision FROM \(table) WHERE plant_id=? ORDER BY id",[.text(id)]) {drafts.insert(try CoreSchema.text(row[0]));parts.append(CoreSchema.vector(row))}}
        }
        if p.type=="DeleteJournalEntry",let id=p.payload["entryId"]?.text {
            for row in try sql.query("SELECT id,revision FROM journal_drafts WHERE entry_id=? ORDER BY id",[.text(id)]) {drafts.insert(try CoreSchema.text(row[0]));parts.append(CoreSchema.vector(row))}
        }
        if p.type=="DeletePhoto",let id=p.payload["photoId"]?.text {
            for row in try sql.query("SELECT id,revision FROM media_drafts WHERE photo_id=? ORDER BY id",[.text(id)]) {parts.append(CoreSchema.vector(row))}
            // Referencing raw draft changes are independently bound by plan hashes.
            for guardValue in try CoreSchema.array(p.body["draftGuards"]) {if let id=guardValue.object?["draftId"]?.text{drafts.insert(id)}}
        }
        for id in drafts.sorted() {
            for row in try sql.query("SELECT id,state,draft_revision,result_json FROM media_preparations WHERE draft_id=? ORDER BY id",[.text(id)]) {parts.append(CoreSchema.vector(row))}
        }
        return try CanonicalCommand.hash(.array(parts))
    }
}
