import Foundation

extension SQLValue {
    var stringValue: String? { if case .text(let s)=self {return s};return nil }
}
extension CoreRegistry {
    static func validatedText(_ value: CanonicalValue?, max: Int, required: Bool = false, trim: Bool = true) throws -> String {
        guard let value else {throw CoreRepositoryError("PLAN_INVALID")}
        let raw=try CoreSchema.rawText(value),text=trim ? trimLikeDart(raw):raw
        try require(text.count<=max && !text.unicodeScalars.contains{$0.value==0} && (!required || !text.isEmpty));return text
    }
    static func validateCatalogSelection(_ sql: SQLiteSession, plant: CoreDelta, fields: [String:CanonicalValue], changes: [CoreDelta]) throws -> CanonicalValue? {
        let old=try CoreSchema.row(sql,"plant_catalog",plant.id)
        guard fields["identityKind"]?.text == "catalog" else {
            try require(changes.count == (old == nil ? 0:1))
            if let change=changes.first {try require(change.action=="delete" && change.id==plant.id)}
            return nil
        }
        let id=try CoreSchema.string(fields["speciesId"]),selection=fields["catalogSelection"]!,m=try CoreSchema.object(selection),version=try CoreSchema.string(m["catalogVersion"])
        let vector:[SQLValue]=[.text(plant.id),.text(id),.text(version),.text(try selection.json())]
        if old == vector {try require(changes.isEmpty);return selection}
        guard try sql.query("SELECT version FROM catalog_head").first?[0] == .text(version),
              let row=try sql.query("SELECT entry_json FROM catalog_entries WHERE version=? AND catalog_id=?",[.text(version),.text(id)]).first else {throw CoreRepositoryError("CATALOG_SELECTION_STALE")}
        let entry=try CanonicalParser.parse(CoreSchema.text(row[0]))
        do {_=try CatalogPackage.entry(entry)} catch {throw CoreRepositoryError("CATALOG_SELECTION_STALE")}
        try require(entry.object?["id"]?.text==id && entry.object?["lifecycle"]?.text=="active" && (try CoreSchema.same(selection,CatalogPackage.selection(entry,version:version))),"CATALOG_SELECTION_STALE")
        try require(changes.count==1 && changes[0].id==plant.id && changes[0].values==vector && changes[0].action==(old==nil ? "insert":"update"))
        return selection
    }
    static func validateSuggestion(_ changes: [CoreDelta],snapshotID: String,routine: [SQLValue],plant: String,fields: [String:CanonicalValue],suggestion: CanonicalValue,original: SQLValue?,adding: Bool) throws {
        let id=try CoreSchema.text(routine[0]), selection=try CoreSchema.object(fields["catalogSelection"]),s=try CoreSchema.object(suggestion),interval=try CoreSchema.object(s["interval"])
        guard let row=changes.first(where:{$0.table=="suggestion_snapshots" && $0.id==snapshotID}),let link=changes.first(where:{$0.table=="routine_suggestions" && $0.id==id}) else {throw CoreRepositoryError("PLAN_INVALID")}
        let expected:[SQLValue]=[.text(snapshotID),.text(id),.text(plant),.text(try CoreSchema.string(fields["speciesId"])),.text(try CoreSchema.string(selection["catalogVersion"])),routine[3],.integer(try CoreSchema.number(interval["count"])),.text(try CoreSchema.string(interval["unit"])),.text(try CoreSchema.string(s["sourceLabel"])),.text(try CoreSchema.string(s["context"]))]
        try require(row.action=="insert" && Array(row.values.prefix(10))==expected)
        try require(link.values==[.text(id),adding ? .text(snapshotID):original ?? .null,.text(snapshotID)])
        try require(link.action == (link.before==nil ? "insert":"update"))
    }
}
