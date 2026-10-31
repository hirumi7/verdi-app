import Foundation

extension CoreRegistry {
    static let mediaCommands: Set<String> = ["SaveJournalDraft","SaveMediaDraft","SaveJournalEntry","DiscardJournalDraft","DiscardMediaDraft","RebaseJournalDraft","RebaseMediaDraft","DeleteJournalEntry","DeletePhoto","UpdatePhotoObservation","ReplacePhoto"]
    static let draftCommands: Set<String> = ["SaveDraft","DiscardDraft","SaveJournalDraft","SaveMediaDraft","DiscardJournalDraft","DiscardMediaDraft","RebaseJournalDraft","RebaseMediaDraft"]
    static let draftTables = ["plant_drafts","journal_drafts","media_drafts"]
    static func draftRow(_ sql: SQLiteSession,_ id: String) throws -> [SQLValue]? {
        var result: [SQLValue]?
        for table in draftTables { if let row=try CoreSchema.row(sql,table,id) {try require(result == nil);result=row} }
        return result
    }
    static func mediaIDs(_ value: CanonicalValue?) throws -> [String] {
        let ids=try CoreSchema.array(value).map {try CoreSchema.string($0)}
        try require(Set(ids).count==ids.count,"FIELD_INVALID")
        for id in ids {try CoreSchema.uuid(id)}
        return ids
    }
    static func storedIDs(_ value: SQLValue) throws -> [String] {try mediaIDs(CanonicalParser.parse(CoreSchema.text(value)))}
    static func validateMediaPayload(_ type: String,_ p: [String:CanonicalValue]) throws {
        try require(try CanonicalCommand.bytes(.object(p)).count<=1024*1024,"PLAN_LIMIT")
        var keys: Set<String>
        switch type {
        case "SaveJournalDraft":
            keys=["draftId","expectedRevision","plantId","entryId","baseEntryRevision","rawFields","readyPhotoIds"]
            let f=try CoreSchema.object(p["rawFields"])
            try require(Set(f.keys)==Set(["text","entryDate","selectedPhotoIds"]) && f["text"]?.units != nil && f["entryDate"]?.units != nil,"FIELD_INVALID")
            _=try mediaIDs(f["selectedPhotoIds"])
            try require((p["entryId"]?.isNull == true)==(p["baseEntryRevision"]?.isNull == true),"FIELD_INVALID")
        case "SaveMediaDraft": keys=["draftId","expectedRevision","plantId","photoId","basePhotoRevision","readyPhotoIds"]
        case "SaveJournalEntry": keys=["draftId","draftRevision"]
        case "DiscardJournalDraft","DiscardMediaDraft":
            keys=["draftId","draftRevision","confirmed"];try require(p["confirmed"]?.json()=="true","NOT_ELIGIBLE")
        case "RebaseJournalDraft","RebaseMediaDraft":keys=["draftId","draftRevision","targetRevision"]
        case "DeleteJournalEntry": keys=["entryId","entryRevision"]
        case "DeletePhoto":keys=["photoId","photoRevision"]
        case "UpdatePhotoObservation":keys=["photoId","photoRevision","observedDate"];try validDate(CoreSchema.string(p["observedDate"]))
        case "ReplacePhoto":keys=["photoId","photoRevision","preparationId","draftId","draftRevision"]
        default:throw CoreRepositoryError("FIELD_INVALID")
        }
        try require(Set(p.keys)==keys,"FIELD_INVALID")
        for key in ["draftId","plantId","entryId","photoId","preparationId"] where p[key] != nil && p[key]?.isNull != true {try CoreSchema.uuid(CoreSchema.string(p[key]))}
        for key in ["expectedRevision","draftRevision","entryRevision","photoRevision","baseEntryRevision","basePhotoRevision","targetRevision"] where p[key] != nil && p[key]?.isNull != true {
            let n=try CoreSchema.number(p[key]);try require(n>0 && n<=CoreSchema.maxRevision,"FIELD_INVALID")
        }
        if p["readyPhotoIds"] != nil {_=try mediaIDs(p["readyPhotoIds"])}
    }
    static func mediaScope(_ sql: SQLiteSession,_ p: CorePlan,_ d: [CoreDelta],allocated: [String],guards: [CanonicalValue],clock: CoreClockFrame) throws {
        func changes(_ table:String)->[CoreDelta]{d.filter{$0.table==table}}
        func only(_ names:Set<String>) throws {try require(d.allSatisfy{names.contains($0.table)})}
        func draft(_ table:String) throws -> [SQLValue] {
            let id=try CoreSchema.string(p.payload["draftId"]),row=try requiredRow(sql,table,id)
            try require(row[1] == .integer(try CoreSchema.number(p.payload["draftRevision"])),"STALE_TARGET")
            return row
        }
        func ready(_ id:String,_ requested:CanonicalValue?) throws {
            let actual=try sql.query("SELECT id FROM photos WHERE draft_id=? ORDER BY id",[.text(id)]).map{try CoreSchema.text($0[0])}
            try require(actual == mediaIDs(requested).sorted(),"DRAFT_CONFLICT")
        }
        func guardSet(_ expected:[String:CanonicalValue]) throws {
            let actual=try guards.reduce(into:[String:CanonicalValue]()){r,g in r[try CoreSchema.string(g.object?["draftId"])]=g.object?["revision"]}
            try require(try CoreSchema.same(.object(actual),.object(expected)))
        }
        try require(p.body["accessRevision"]?.isNull==true)
        switch p.type {
        case "SaveJournalDraft","SaveMediaDraft":
            let journal=p.type=="SaveJournalDraft",table=journal ? "journal_drafts":"media_drafts",id=try CoreSchema.string(p.payload["draftId"])
            try only([table]);try require(d.count==1 && d[0].id==id && d[0].action != "delete" && allocated.isEmpty)
            try guardSet([id:p.payload["expectedRevision"]!]);let v=d[0].values
            let plant=try CoreSchema.string(p.payload["plantId"]);_=try requiredRow(sql,"plants",plant)
            try require(v[2] == .text(plant) && v[3] == CoreSchema.scalar(p.payload[journal ? "entryId":"photoId"]!) && v[4] == CoreSchema.scalar(p.payload[journal ? "baseEntryRevision":"basePhotoRevision"]!))
            if let old=d[0].before {try require(v[4]==old[4],"DRAFT_CONFLICT")}
            if v[3] != .null {
                let target=try requiredRow(sql,journal ? "journal_entries":"photos",CoreSchema.text(v[3]));try require(target[1] == .text(plant))
            }
            if journal {try require(try CoreSchema.same(CanonicalParser.parse(CoreSchema.text(v[5])),p.payload["rawFields"]))}
            try require(try CoreSchema.same(CanonicalParser.parse(CoreSchema.text(v[journal ? 6:5])),p.payload["readyPhotoIds"]))
            try ready(id,p.payload["readyPhotoIds"])
        case "SaveJournalEntry":
            let row=try draft("journal_drafts"),id=try CoreSchema.text(row[0]),plant=try CoreSchema.text(row[2]),fields=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[5])))
            try guardSet([id:p.payload["draftRevision"]!]);try only(["journal_entries","journal_drafts","photos"])
            let entries=changes("journal_entries"),removed=changes("journal_drafts")
            try require(entries.count==1 && removed.count==1 && removed[0].id==id && removed[0].action=="delete")
            let e=entries[0],v=e.values,text=try validatedText(fields["text"],max:2000),date=try CoreSchema.string(fields["entryDate"]),ids=try mediaIDs(fields["selectedPhotoIds"])
            try validDate(date);try require(date<=clock.today,"FUTURE_OBSERVATION_DATE");try require(!text.isEmpty || !ids.isEmpty,"EMPTY_ENTRY")
            try require(v[1] == .text(plant) && v[3] == .text(date) && v[4] == .text(text) && (try storedIDs(v[5]))==ids)
            if row[3] == .null {try require(e.action=="insert" && allocated==[e.id] && ids.count<=1)}
            else {try require(e.action=="update" && e.values[0]==row[3] && e.before?[2]==row[4] && allocated.isEmpty,"DRAFT_CONFLICT")}
            try ready(id,CanonicalParser.parse(CoreSchema.text(row[6])))
            let owned=try sql.query("SELECT id FROM photos WHERE draft_id=?",[.text(id)]).map{try CoreSchema.text($0[0])}
            try require(Set(changes("photos").map(\.id))==Set(owned))
            for photo in changes("photos") {
                try require(photo.before?[2] == .text(id))
                if ids.contains(photo.id) {try require(photo.action=="update" && photo.values[1] == .text(plant) && photo.values[2] == .null);for i in 4...13 {try require(photo.values[i]==photo.before![i])}}
                else {try require(photo.action=="delete")}
            }
        case "DiscardJournalDraft","DiscardMediaDraft":
            let table=p.type=="DiscardJournalDraft" ? "journal_drafts":"media_drafts",row=try draft(table),id=try CoreSchema.text(row[0])
            try guardSet([id:p.payload["draftRevision"]!]);try only([table,"photos"]);try require(allocated.isEmpty && changes(table).count==1 && changes(table)[0].id==id && changes(table)[0].action=="delete")
            let owned=try sql.query("SELECT id FROM photos WHERE draft_id=?",[.text(id)]).map{try CoreSchema.text($0[0])}
            try require(Set(changes("photos").map(\.id))==Set(owned) && changes("photos").allSatisfy{$0.action=="delete"})
        case "RebaseJournalDraft","RebaseMediaDraft":
            let journal=p.type=="RebaseJournalDraft",table=journal ? "journal_drafts":"media_drafts",row=try draft(table),id=try CoreSchema.text(row[0])
            try guardSet([id:p.payload["draftRevision"]!]);try only([table]);try require(d.count==1 && d[0].action=="update" && d[0].id==id && allocated.isEmpty)
            let target=try requiredRow(sql,journal ? "journal_entries":"photos",CoreSchema.text(row[3])),revision=target[journal ? 2:3]
            try require(revision == .integer(try CoreSchema.number(p.payload["targetRevision"])) && d[0].values[4]==revision,"STALE_TARGET")
            for i in 5...(journal ? 7:6) {try require(d[0].values[i]==row[i])}
        case "DeleteJournalEntry":
            let id=try CoreSchema.string(p.payload["entryId"]),row=try requiredRow(sql,"journal_entries",id)
            try require(row[2] == .integer(try CoreSchema.number(p.payload["entryRevision"])),"STALE_TARGET")
            try only(["journal_entries","journal_drafts","photos"]);try require(allocated.isEmpty && changes("journal_entries").count==1 && changes("journal_entries")[0].id==id && d.allSatisfy{$0.action=="delete"})
            let drafts=try sql.query("SELECT id,revision FROM journal_drafts WHERE entry_id=?",[.text(id)])
            try guardSet(Dictionary(uniqueKeysWithValues:try drafts.map{(try CoreSchema.text($0[0]),CoreSchema.canonical($0[1]))}))
            let ids=try drafts.map{try CoreSchema.text($0[0])};try require(Set(changes("journal_drafts").map(\.id))==Set(ids))
            let owned=try sql.query("SELECT id FROM photos WHERE draft_id IN (SELECT id FROM journal_drafts WHERE entry_id=?)",[.text(id)]).map{try CoreSchema.text($0[0])}
            try require(Set(changes("photos").map(\.id))==Set(owned))
        default: try photoScope(sql,p,d,allocated:allocated,guards:guards,clock:clock)
        }
    }
    static func validateMediaGraph(_ sql:SQLiteSession) throws {
        for row in try sql.query("SELECT id,plant_id,draft_id FROM photos") {
            _=try originalPath(requiredRow(sql,"photos",CoreSchema.text(row[0])))
            if row[1] == .null {try require(row[2] != .null && (try draftRow(sql,CoreSchema.text(row[2]))) != nil)}
            else {try require(row[2] == .null)}
        }
        for table in ["journal_entries","journal_drafts"] {
            let rows=try sql.query(table=="journal_entries" ? "SELECT plant_id,NULL,photo_ids_json FROM journal_entries":"SELECT plant_id,id,raw_fields_json FROM journal_drafts")
            for row in rows {
                let value=try CanonicalParser.parse(CoreSchema.text(row[2]))
                let ids=try mediaIDs(table=="journal_entries" ? value:value.object?["selectedPhotoIds"])
                for id in ids {let p=try requiredRow(sql,"photos",id);try require(p[1]==row[0] || (row[1] != .null && p[2]==row[1]))}
            }
        }
        for row in try sql.query("SELECT c.id,p.plant_id FROM plant_covers c JOIN photos p ON p.id=c.photo_id") {try require(row[0]==row[1])}
        for table in ["journal_drafts","media_drafts"] {
            for row in try sql.query("SELECT id,ready_photo_ids_json FROM \(table)") {
                let actual=try sql.query("SELECT id FROM photos WHERE draft_id=? ORDER BY id",[row[0]]).map{try CoreSchema.text($0[0])}
                try require(actual == storedIDs(row[1]).sorted())
            }
        }
    }
}
