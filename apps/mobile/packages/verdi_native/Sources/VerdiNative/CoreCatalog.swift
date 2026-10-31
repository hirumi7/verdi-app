import Foundation

extension CoreRepository {
    func installCatalog(_ db: SQLiteDatabase) throws {
        guard let provider=catalogProvider else {throw CoreRepositoryError("CATALOG_MISSING")}
        let package=try CatalogPackage(provider())
        try db.transaction { sql in
            let head=try sql.query("SELECT version,manifest_json FROM catalog_head")
            if head.first?[0] == .text(package.version) {
                try CatalogPackage.require(head[0][1] == .text(try package.manifest.json()))
                let rows=try sql.query("SELECT catalog_id,entry_json FROM catalog_entries WHERE version=?",[.text(package.version)])
                let entries=Dictionary(uniqueKeysWithValues:package.entries.map {($0.object!["id"]!.text!,$0)})
                try CatalogPackage.require(rows.count==entries.count)
                for row in rows {guard let expected=entries[try CoreSchema.text(row[0])] else {throw CoreRepositoryError("CATALOG_INVALID")};try CatalogPackage.require(row[1] == .text(try expected.json()))}
                return
            }
            try CatalogPackage.require(try sql.query("SELECT catalog_id FROM catalog_entries WHERE version=? LIMIT 1",[.text(package.version)]).isEmpty)
            for entry in package.entries {
                let e=entry.object!,id=e["id"]!.text!
                let previous=try sql.query("SELECT entry_json FROM catalog_entries WHERE catalog_id=?",[.text(id)])
                for row in previous {
                    let old=try CanonicalParser.parse(CoreSchema.text(row[0])).object!
                    if try !CoreSchema.same(.object(old),entry) {try CatalogPackage.require(e["entryVersion"]!.integer! > old["entryVersion"]!.integer!)}
                }
                try sql.execute("INSERT OR IGNORE INTO catalog_identity VALUES(?,?)",[.text(id),.text(e["scientificName"]!.text!)])
                try sql.execute("INSERT INTO catalog_entries VALUES(?,?,?)",[.text(package.version),.text(id),.text(try entry.json())])
            }
            try sql.execute("INSERT INTO catalog_head VALUES(1,?,?) ON CONFLICT(slot) DO UPDATE SET version=excluded.version,manifest_json=excluded.manifest_json",[.text(package.version),.text(try package.manifest.json())])
        }
        catalogLimitation=nil
    }
    func tryCatalog(_ db: SQLiteDatabase) {
        for _ in 0..<2 {
            do {try installCatalog(db);return}
            catch {catalogLimitation="CATALOG_UNAVAILABLE"}
        }
    }
    func catalogValue(_ raw: String) throws -> CanonicalValue {
        do {return try CanonicalParser.parse(raw)} catch {throw CoreRepositoryError("CATALOG_UNAVAILABLE")}
    }
    func catalogMeta(_ sql: SQLiteSession) throws -> CanonicalValue {
        let head=try sql.query("SELECT version,manifest_json FROM catalog_head")
        guard let row=head.first else {return .object(["version":.null,"manifest":.null,"limitation":.string("CATALOG_UNAVAILABLE")])}
        let manifest=try catalogValue(CoreSchema.text(row[1]))
        do {
            let m=try CoreSchema.object(manifest)
            try CatalogPackage.manifestStructure(m)
            try CatalogPackage.require(m["catalogVersion"]?.text==row[0].stringValue)
        } catch {throw CoreRepositoryError("CATALOG_UNAVAILABLE")}
        return .object(["version":CoreSchema.canonical(row[0]),"manifest":manifest,"limitation":catalogLimitation.map(CanonicalValue.string) ?? .null])
    }
    func catalogRows(_ sql: SQLiteSession,_ args: [String:CanonicalValue]) throws -> CanonicalValue {
        let version=try CoreSchema.string(args["version"])
        guard try sql.query("SELECT version FROM catalog_head").first?[0] == .text(version) else {throw CoreRepositoryError("CATALOG_CHANGED")}
        let after=args["after"]?.text ?? ""
        let rows=try sql.query("SELECT catalog_id,entry_json FROM catalog_entries WHERE version=? AND catalog_id>? ORDER BY catalog_id LIMIT 201",[.text(version),.text(after)])
        var entries:[CanonicalValue]=[];var bytes=0
        for row in rows.prefix(200) {
            let raw=try CoreSchema.text(row[1]);try CatalogPackage.require(raw.utf8.count<=256*1024)
            if bytes+raw.utf8.count>1536*1024 {break};bytes+=raw.utf8.count
            var value=try catalogValue(raw)
            guard value.object?["id"]?.text == row[0].stringValue else {throw CoreRepositoryError("CATALOG_UNAVAILABLE")}
            do { _=try CatalogPackage.entry(value) }
            catch {
                // A formerly known safety label is not trustworthy without its
                // scoped evidence. Broader invalid content stays unavailable.
                if var e=value.object, var t=e["toxicity"]?.object, t["value"]?.text != "unknown" {
                    t["value"] = .string("unknown");t["animalScope"] = .array([]);t["sourceRefs"] = .array([])
                    t["qualification"] = .string("Toxicity evidence needs review. Unknown does not mean safe to ingest.")
                    e["toxicity"] = .object(t);value = .object(e)
                    do {_=try CatalogPackage.entry(value)} catch {throw CoreRepositoryError("CATALOG_UNAVAILABLE")}
                    catalogLimitation="CATALOG_UNAVAILABLE"
                } else {throw CoreRepositoryError("CATALOG_UNAVAILABLE")}
            }
            entries.append(value)
        }
        return .object(["entries":.array(entries),"nextCursor":entries.count<rows.count ? entries.last?.object?["id"] ?? .null:.null])
    }
}
