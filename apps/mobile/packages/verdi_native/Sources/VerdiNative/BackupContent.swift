import Foundation

/// Portable content validation is separate from commands and the receiving clock.
enum BackupContent {
    static let profile = "custom_core_v1"
    static func rows(_ sql: SQLiteSession, _ table: String, _ work: ([SQLValue]) throws -> Void) throws {
        let columns = CoreSchema.columns[table]!.joined(separator:",")
        var cursor = ""
        while let row = try sql.query("SELECT \(columns) FROM \(table) WHERE id>? ORDER BY id LIMIT 1",[.text(cursor)]).first {
            cursor = try CoreSchema.text(row[0]); try work(row)
        }
    }
    static func counts(_ db: SQLiteDatabase) throws -> CanonicalValue {
        try db.read { sql in
            var result = [String:CanonicalValue]()
            for (key,query) in [("activePlants","SELECT count(*) FROM plants WHERE archived=0"),("archivedPlants","SELECT count(*) FROM plants WHERE archived=1"),("events","SELECT count(*) FROM care_events"),("journalEntries","SELECT count(*) FROM journal_entries"),("photos","SELECT count(*) FROM photos")] {
                result[key] = CoreSchema.canonical(try sql.query(query)[0][0])
            }
            return .object(result)
        }
    }
    static func export(_ db: SQLiteDatabase, to root: URL, mediaRoot: URL, index: BackupIndex, instant: String, cancel: () throws -> Void) throws {
        let output = try BackupWriter(root.appendingPathComponent("data.json"),limit:512*1024*1024)
        try db.read { sql in
            let revision = try CoreSchema.integer(sql.query("SELECT collection_revision FROM metadata")[0][0])
            let settings = try CanonicalParser.parse(CoreSchema.text(sql.query("SELECT payload_json FROM user_settings WHERE slot=1")[0][0]))
            try BackupSettings.validate(settings)
            try output.write("{\"schemaVersion\":2,\"profile\":\"\(profile)\",\"collectionRevision\":\(revision),\"settings\":\(try settings.json()),\"tables\":{")
            for (i,table) in CoreSchema.tables.sorted().enumerated() {
                if i > 0 {try output.write(",")}; try output.write("\"\(table)\":[")
                var first = true
                try rows(sql,table) { row in
                    try cancel(); try validateRow(table,row)
                    if !first {try output.write(",")}; first = false
                    try output.write(CoreSchema.vector(row).json())
                }
                try output.write("]")
            }
            try output.write("}}")
        }
        try output.finish()
        let files = try MediaFiles(root:mediaRoot)
        try db.read { sql in
            try rows(sql,"photos") { row in
                try cancel(); let path = try CoreSchema.text(row[4]), info = try files.inspect(path)
                try checkPhoto(row,info)
                try index.database.transaction { try $0.execute("INSERT INTO files VALUES(?,?,?,?,?)",[row[0],row[4],row[5],row[6],row[7]]) }
            }
        }
        let data = try BackupIO.hash(output.url,limit:512*1024*1024,cancel:cancel), counts = try counts(db)
        let catalog = try db.read { try $0.query("SELECT version FROM catalog_head").first?.first?.stringValue ?? "unavailable" }
        let manifest = try BackupWriter(root.appendingPathComponent("manifest.json"),limit:16*1024*1024)
        let prefix: [String:CanonicalValue] = ["format":.string("verdi-backup"),"formatVersion":.integer(2),"dataSchemaVersion":.integer(2),"profile":.string(profile),"createdAt":.string(instant),"appVersion":.string("verdi-development-2"),"catalogVersion":.string(catalog),"data":.object(["path":.string("data.json"),"sha256":.string(data.0),"bytes":.integer(data.1)]),"counts":counts]
        let encoded = try CanonicalValue.object(prefix).json()
        try manifest.write(String(encoded.dropLast())+",\"files\":[")
        var first = true
        try index.eachFile { row in
            try cancel(); if !first {try manifest.write(",")};first = false
            try manifest.write(CanonicalValue.object(["photoId":CoreSchema.canonical(row[0]),"path":CoreSchema.canonical(row[1]),"sha256":CoreSchema.canonical(row[2]),"bytes":CoreSchema.canonical(row[3]),"mime":CoreSchema.canonical(row[4])]).json())
        }
        try manifest.write("]}");try manifest.finish()
    }
    static func importData(root: URL, index: BackupIndex, dataset: String, instant: String, cancel: @escaping () throws -> Void) throws -> SQLiteDatabase {
        let manifestReader = try BackupJSONReader(root.appendingPathComponent("manifest.json"),limit:16*1024*1024,cancel:cancel)
        var manifest = [String:CanonicalValue](), hasFiles = false
        try manifestReader.object { key in
            if key == "files" {
                hasFiles = true
                try index.database.transaction { sql in
                    try manifestReader.array {
                        let f = try CoreSchema.object(manifestReader.value(depth:2))
                        try BackupIO.require(Set(f.keys) == Set(["photoId","path","sha256","bytes","mime"]))
                        let id = try CoreSchema.string(f["photoId"]), path = try CoreSchema.string(f["path"]), hash = try CoreSchema.string(f["sha256"]), bytes = try CoreSchema.number(f["bytes"]), mime = try CoreSchema.string(f["mime"])
                        try CoreSchema.uuid(id); try BackupIO.canonicalMedia(path)
                        let ext = ["image/png":"png","image/jpeg":"jpg","image/heic":"heic"][mime]
                        try BackupIO.require(ext != nil && BackupIO.validHash(hash) && bytes > 0 && bytes <= 67108864 && path == "media/\(id)/\(hash).\(ext ?? "")")
                        try sql.execute("INSERT INTO files VALUES(?,?,?,?,?)",[.text(id),.text(path),.text(hash),.integer(bytes),.text(mime)])
                    }
                }
            } else { manifest[key] = try manifestReader.value(depth:1) }
        }
        try manifestReader.end()
        try BackupIO.require(hasFiles && Set(manifest.keys) == Set(["format","formatVersion","dataSchemaVersion","profile","createdAt","appVersion","catalogVersion","data","counts"]))
        try BackupIO.require(manifest["format"]?.text == "verdi-backup")
        try BackupIO.require(manifest["formatVersion"]?.integer == 2 && manifest["dataSchemaVersion"]?.integer == 2 && manifest["profile"]?.text == profile,"BACKUP_VERSION_UNSUPPORTED")
        try instantValue(CoreSchema.string(manifest["createdAt"]))
        for key in ["appVersion","catalogVersion"] { try text(CoreSchema.string(manifest[key]),max:80,required:true) }
        let data = try CoreSchema.object(manifest["data"])
        try BackupIO.require(Set(data.keys) == Set(["path","sha256","bytes"]) && data["path"]?.text == "data.json")
        let actual = try BackupIO.hash(root.appendingPathComponent("data.json"),limit:512*1024*1024,cancel:cancel)
        try BackupIO.require(data["sha256"]?.text == actual.0 && data["bytes"]?.integer == actual.1,"BACKUP_HASH_MISMATCH")
        let db = try SQLiteDatabase.create(at:root.appendingPathComponent("core.sqlite"),schema:CoreSchema.schema(dataset:dataset,instant:instant))
        do {
            let reader = try BackupJSONReader(root.appendingPathComponent("data.json"),limit:512*1024*1024,cancel:cancel)
            try db.importTransaction { sql in
                var seen = Set<String>(), tables = Set<String>()
                try reader.object { key in
                    seen.insert(key)
                    switch key {
                    case "schemaVersion": try BackupIO.require(try reader.value().integer == 2,"BACKUP_VERSION_UNSUPPORTED")
                    case "profile": try BackupIO.require(try reader.value().text == profile,"BACKUP_VERSION_UNSUPPORTED")
                    case "collectionRevision":
                        let revision = try reader.value(); try BackupSettings.revision(revision)
                        try sql.execute("UPDATE metadata SET collection_revision=?",[try CoreSchema.scalar(revision)])
                    case "settings":
                        let settings = try reader.value(); try BackupSettings.validate(settings)
                        try sql.execute("UPDATE user_settings SET revision=?,payload_json=? WHERE slot=1",[try CoreSchema.scalar(settings.object!["revision"]!),.text(try settings.json())])
                    case "tables":
                        try reader.object { table in
                            try BackupIO.require(CoreSchema.tables.contains(table)); tables.insert(table)
                            try reader.array {
                                let value = try reader.value(depth:3), row = try CoreSchema.array(value).map(CoreSchema.scalar)
                                try validateRow(table,row)
                                try sql.execute("INSERT INTO \(table) VALUES(\(Array(repeating:"?",count:row.count).joined(separator:",")))",row)
                                if !CoreSchema.linkedTables.contains(table) {
                                    let kind = table == "plant_drafts" ? "draft" : table == "journal_drafts" ? "journalDraft" : table == "media_drafts" ? "mediaDraft" : "entity"
                                    // Unique reservations also enforce cross-kind IDs, without importing authority.
                                    try sql.execute("INSERT INTO reservations VALUES(?,?,?,1)",[row[0],.text(kind),.text(dataset)])
                                }
                            }
                        }
                    default: throw CoreRepositoryError("BACKUP_SCHEMA_INVALID")
                    }
                }
                try reader.end()
                try BackupIO.require(seen == Set(["schemaVersion","profile","collectionRevision","settings","tables"]) && tables == Set(CoreSchema.tables))
                try validateGraph(sql,cancel:cancel)
            }
            let expectedCounts = try CoreSchema.object(manifest["counts"]), actualCounts = try counts(db)
            try BackupIO.require(try CoreSchema.same(.object(expectedCounts),actualCounts),"BACKUP_REFERENCE_INVALID")
            let files = try MediaFiles(root:root)
            try db.read { sql in
                try rows(sql,"photos") { row in
                    try cancel()
                    let f = try index.database.read { try $0.query("SELECT id,path,hash,bytes,mime FROM files WHERE id=?",[row[0]]).first }
                    try BackupIO.require(f == [row[0],row[4],row[5],row[6],row[7]],"BACKUP_REFERENCE_INVALID")
                    try checkPhoto(row,files.inspect(CoreSchema.text(row[4])))
                }
            }
            let count = try index.database.read { try CoreSchema.integer($0.query("SELECT count(*) FROM files")[0][0]) }
            try BackupIO.require(count == actualCounts.object?["photos"]?.integer,"BACKUP_REFERENCE_INVALID")
            try BackupIO.require(try index.database.read {try $0.query("SELECT path FROM entries WHERE path NOT IN ('manifest.json','data.json') AND NOT EXISTS(SELECT 1 FROM files WHERE files.path=entries.path COLLATE BINARY) LIMIT 1").isEmpty},"BACKUP_REFERENCE_INVALID")
            try restorePreparations(db,files:files,instant:instant)
            return db
        } catch { try? db.close(); throw error }
    }
    static func text(_ value: String, max: Int, required: Bool = false) throws {
        try BackupIO.require(value.count <= max && !value.unicodeScalars.contains{$0.value == 0} && (!required || !value.isEmpty))
    }
    static func instantValue(_ value: String) throws {
        try BackupIO.require(value.range(of:"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}([0-9]{3})?Z$",options:.regularExpression) != nil)
        try BackupIO.require(value.count != 27 || !value.hasSuffix("000Z"))
        try CoreRegistry.validDate(String(value.prefix(10)))
        let parts = value.dropFirst(11).prefix(8).split(separator:":").compactMap{Int($0)}
        try BackupIO.require(parts.count == 3 && parts[0] <= 23 && parts[1] <= 59 && parts[2] <= 59)
    }
    static func validateRow(_ table: String, _ row: [SQLValue]) throws {
        guard let columns = CoreSchema.columns[table] else {throw CoreRepositoryError("BACKUP_SCHEMA_INVALID")}
        try BackupIO.require(row.count == columns.count)
        let bytes = try CanonicalCommand.bytes(CoreSchema.vector(row)).count
        try BackupIO.require(bytes <= 2*1024*1024,"BACKUP_LIMIT")
        for (i,value) in row.enumerated() {
            if value == .null { try BackupIO.require(CoreSchema.nullableColumns[table]?.contains(i) == true); continue }
            if CoreSchema.integerColumns[table]?.contains(i) == true { _ = try CoreSchema.integer(value) }
            else {
                let string = try CoreSchema.text(value); try BackupIO.require(!string.utf8.contains(0))
                if columns[i] == "id" || columns[i].hasSuffix("_id") && !["species_id"].contains(columns[i]) {try CoreSchema.uuid(string)}
                if CoreSchema.instantColumns[table]?.contains(i) == true {try instantValue(string)}
            }
        }
        if let i = CoreSchema.revisions[table] {try BackupSettings.revision(CoreSchema.canonical(row[i]))}
        func string(_ i:Int) throws -> String {try CoreSchema.text(row[i])}
        func date(_ i:Int) throws {if row[i] != .null {try CoreRegistry.validDate(string(i))}}
        func json(_ i:Int) throws -> CanonicalValue {try CanonicalParser.parse(string(i),limit:2*1024*1024)}
        switch table {
        case "plants":
            for (i,max,required) in [(2,60,true),(3,40,false),(4,2000,false),(5,160,true)] {try text(string(i),max:max,required:required)}
        case "routines": try text(string(4),max:60,required:true);try date(8);try date(10)
        case "heads":try date(3);try date(4)
        case "care_events":try date(6);try text(string(5),max:60,required:true);try text(string(9),max:128,required:true)
        case "event_corrections":
            try date(3);try date(6)
            for i in [4,7] {try BackupIO.require(["actual_care","checked_not_needed","skipped"].contains(try string(i)))}
            try BackupIO.require(["correction","void","undo"].contains(try string(11)))
        case "routine_changes":
            try date(5);try text(string(7),max:128,required:true)
            try BackupIO.require(["interval","speciesApply","override","pause","resume","retire","archive","restore","undo"].contains(try string(4)))
            for i in [8,9] {try validateHead(json(i))}
        case "plant_drafts":
            let envelope = try CoreSchema.object(json(5));try BackupIO.require(Set(envelope.keys) == Set(["version","fields"]) && envelope["version"]?.integer == 1)
            try CoreRegistry.validatePayload("SaveDraft",["draftId":CoreSchema.canonical(row[0]),"expectedRevision":CoreSchema.canonical(row[1]),"mode":CoreSchema.canonical(row[2]),"plantId":CoreSchema.canonical(row[3]),"basePlantRevision":CoreSchema.canonical(row[4]),"rawFields":envelope["fields"]!,"photoIds":.array([])])
        case "plant_catalog":
            _=try CatalogPackage.matches(CoreSchema.canonical(row[1]),"^[A-Za-z0-9_-]{1,128}$")
            let selection = try CoreSchema.object(json(3))
            try CatalogPackage.keys(selection,["catalogVersion","speciesNameSnapshot","suggestions"])
            _=try CatalogPackage.matches(selection["catalogVersion"],"^[a-z0-9][a-z0-9._-]{0,79}$")
            try BackupIO.require(selection["catalogVersion"]?.text == string(2))
            _=try CatalogPackage.text(selection["speciesNameSnapshot"],160);try CatalogPackage.suggestions(selection["suggestions"])
        case "suggestion_snapshots":
            _=try CatalogPackage.matches(CoreSchema.canonical(row[3]),"^[A-Za-z0-9_-]{1,128}$")
            _=try CatalogPackage.matches(CoreSchema.canonical(row[4]),"^[a-z0-9][a-z0-9._-]{0,79}$")
            try BackupIO.require(["water","fertilize","mist","repot","rotate"].contains(try string(5)) && ["day","week","month","year"].contains(try string(7)))
            try text(string(8),max:120,required:true);try text(string(9),max:500,required:true)
        case "journal_entries":
            try date(3);try text(string(4),max:2000)
            let ids = try CoreRegistry.mediaIDs(json(5));try BackupIO.require(!ids.isEmpty || !(try string(4)).isEmpty)
        case "journal_drafts":
            try CoreRegistry.validateMediaPayload("SaveJournalDraft",["draftId":CoreSchema.canonical(row[0]),"expectedRevision":CoreSchema.canonical(row[1]),"plantId":CoreSchema.canonical(row[2]),"entryId":CoreSchema.canonical(row[3]),"baseEntryRevision":CoreSchema.canonical(row[4]),"rawFields":try json(5),"readyPhotoIds":try json(6)])
        case "media_drafts":
            try CoreRegistry.validateMediaPayload("SaveMediaDraft",["draftId":CoreSchema.canonical(row[0]),"expectedRevision":CoreSchema.canonical(row[1]),"plantId":CoreSchema.canonical(row[2]),"photoId":CoreSchema.canonical(row[3]),"basePhotoRevision":CoreSchema.canonical(row[4]),"readyPhotoIds":try json(5)])
            try BackupIO.require(try CoreRegistry.storedIDs(row[5]).count <= 1)
        case "photos":
            _=try CoreRegistry.originalPath(row);try date(10)
            if row[12] != .null {try BackupIO.require(BackupIO.validHash(string(12)))}
        default:break
        }
    }
    static func validateHead(_ value: CanonicalValue) throws {
        let h = try CoreSchema.object(value), version = h["version"]?.integer
        var keys: Set<String> = ["version","headId","intervalCount","intervalUnit","anchor","firstCheckAnchor","firstCheckDate","nextCheck","overrideDate","status","archived"]
        if version == 2 {keys.formUnion(["originalSuggestionId","appliedSuggestionId"])}
        try BackupIO.require([1,2].contains(version) && Set(h.keys) == keys)
        try CoreSchema.uuid(CoreSchema.string(h["headId"]))
        for key in ["anchor","nextCheck"] {try CoreRegistry.validDate(CoreSchema.string(h[key]))}
        for key in ["firstCheckDate","overrideDate"] where h[key]?.isNull != true {try CoreRegistry.validDate(CoreSchema.string(h[key]))}
        try BackupIO.require((1...9999).contains(try CoreSchema.number(h["intervalCount"])) && ["day","week","month","year"].contains(h["intervalUnit"]?.text ?? "") && ["active","paused","retired"].contains(h["status"]?.text ?? ""))
        try BackupSettings.boolean(h["archived"]);try BackupSettings.boolean(h["firstCheckAnchor"])
        if version == 2 {try CoreSchema.uuid(CoreSchema.string(h["appliedSuggestionId"]))}
        if version == 2 {for key in ["originalSuggestionId","appliedSuggestionId"] where h[key]?.isNull != true {try CoreSchema.uuid(CoreSchema.string(h[key]))}}
    }
    static func validateGraph(_ sql: SQLiteSession, cancel: () throws -> Void) throws {
        func rejectRows(_ query:String) throws {try BackupIO.require(try sql.query(query+" LIMIT 1").isEmpty,"BACKUP_REFERENCE_INVALID")}
        try rejectRows("SELECT r.id FROM routines r LEFT JOIN heads h ON h.routine_id=r.id WHERE h.id IS NULL")
        try rejectRows("SELECT e.id FROM care_events e JOIN routines r ON r.id=e.routine_id WHERE e.plant_id!=r.plant_id OR e.care_kind!=r.care_kind OR e.care_label!=r.label")
        try rejectRows("SELECT c.id FROM routine_changes c JOIN routines r ON r.id=c.routine_id WHERE c.plant_id!=r.plant_id")
        try rejectRows("SELECT s.id FROM suggestion_snapshots s JOIN routines r ON r.id=s.routine_id WHERE s.plant_id!=r.plant_id OR s.care_kind!=r.care_kind")
        try rejectRows("SELECT l.id FROM routine_suggestions l JOIN suggestion_snapshots s ON s.id=l.applied_id LEFT JOIN suggestion_snapshots o ON o.id=l.original_id WHERE s.routine_id!=l.id OR (o.id IS NOT NULL AND o.routine_id!=l.id)")
        try rejectRows("SELECT d.id FROM journal_drafts d JOIN journal_entries e ON e.id=d.entry_id WHERE d.plant_id!=e.plant_id")
        try rejectRows("SELECT d.id FROM media_drafts d JOIN photos p ON p.id=d.photo_id WHERE d.plant_id!=p.plant_id OR p.plant_id IS NULL")
        try rejectRows("SELECT c.id FROM plant_covers c JOIN photos p ON p.id=c.photo_id WHERE c.id!=p.plant_id OR p.plant_id IS NULL")
        try rows(sql,"care_events") { event in
            try cancel();var before = Array(event[6...7])+[SQLValue.integer(0)], sequence:Int64 = 1
            while let c = try sql.query("SELECT sequence,before_date,before_outcome,before_voided,after_date,after_outcome,after_voided FROM event_corrections WHERE event_id=? AND sequence>=? ORDER BY sequence LIMIT 1",[event[0],.integer(sequence)]).first {
                try BackupIO.require(c[0] == .integer(sequence) && Array(c[1...3]) == before,"BACKUP_REFERENCE_INVALID")
                before = Array(c[4...6]);sequence += 1
            }
            try BackupIO.require(event[3] == .integer(sequence),"BACKUP_REFERENCE_INVALID")
        }
        try rows(sql,"plant_catalog") { row in
            let p = try CoreRegistry.requiredRow(sql,"plants",CoreSchema.text(row[0])), s = try CanonicalParser.parse(CoreSchema.text(row[3]))
            try BackupIO.require(p[5].stringValue == s.object?["speciesNameSnapshot"]?.text && p[6] == .text("unknown") && p[7] == .text("unknown"),"BACKUP_REFERENCE_INVALID")
        }
        try rows(sql,"photos") { row in
            try cancel()
            if row[2] != .null {try BackupIO.require(try CoreRegistry.draftRow(sql,CoreSchema.text(row[2])) != nil,"BACKUP_REFERENCE_INVALID")}
        }
        for table in ["journal_entries","journal_drafts","media_drafts","plant_drafts"] {
            try rows(sql,table) { row in
                try cancel()
                if table == "plant_drafts" {
                    let f = try CanonicalParser.parse(CoreSchema.text(row[5])).object?["fields"]
                    let owned = try sql.query("SELECT id FROM photos WHERE draft_id=? ORDER BY id",[row[0]]).map{CoreSchema.canonical($0[0])}
                    try CoreRegistry.validatePayload("SaveDraft",["draftId":CoreSchema.canonical(row[0]),"expectedRevision":CoreSchema.canonical(row[1]),"mode":CoreSchema.canonical(row[2]),"plantId":CoreSchema.canonical(row[3]),"basePlantRevision":CoreSchema.canonical(row[4]),"rawFields":.object(try CoreSchema.object(f)),"photoIds":.array(owned)])
                    if let id = f?.object?["coverPhotoId"]?.text {
                        let p = try CoreRegistry.requiredRow(sql,"photos",id)
                        try BackupIO.require(p[2] == row[0] || (row[3] != .null && p[1] == row[3]),"BACKUP_REFERENCE_INVALID")
                    }
                    return
                }
                let journal = table == "journal_entries", draft = table == "journal_drafts", plant = row[journal ? 1:2]
                if journal || draft {
                    let value = try CanonicalParser.parse(CoreSchema.text(row[5])), ids = try CoreRegistry.mediaIDs(journal ? value:value.object?["selectedPhotoIds"])
                    for id in ids {
                        let p = try CoreRegistry.requiredRow(sql,"photos",id)
                        try BackupIO.require(p[1] == plant || (!journal && p[2] == row[0]),"BACKUP_REFERENCE_INVALID")
                    }
                }
                if !journal {
                    let ids = try CoreRegistry.storedIDs(row[draft ? 6:5])
                    let count = try CoreSchema.integer(sql.query("SELECT count(*) FROM photos WHERE draft_id=?",[row[0]])[0][0])
                    try BackupIO.require(count == ids.count,"BACKUP_REFERENCE_INVALID")
                    for id in ids {try BackupIO.require(try CoreRegistry.requiredRow(sql,"photos",id)[2] == row[0],"BACKUP_REFERENCE_INVALID")}
                }
            }
        }
    }
    static func checkPhoto(_ row:[SQLValue], _ info:MediaFileInfo) throws {
        try BackupIO.require(row[5] == .text(info.hash) && row[6] == .integer(info.bytes) && row[7] == .text(info.mime) && row[8] == .integer(info.width) && row[9] == .integer(info.height),"BACKUP_HASH_MISMATCH")
    }
    static func restorePreparations(_ db: SQLiteDatabase, files: MediaFiles, instant:String) throws {
        try db.transaction { sql in
            try rows(sql,"photos") { row in try sql.execute("INSERT INTO media_files VALUES(?,NULL,NULL,?)",[row[4],.text(instant)]) }
            try rows(sql,"media_drafts") { draft in
                guard let photo = try CoreRegistry.storedIDs(draft[5]).first else {return}
                let row = try CoreRegistry.requiredRow(sql,"photos",photo), prep = UUID().uuidString.lowercased(), selection = UUID().uuidString.lowercased()
                let path = "media/\(try CoreSchema.text(draft[3]))/\(try CoreSchema.text(row[5])).\((try CoreSchema.text(row[4]) as NSString).pathExtension)"
                try sql.execute("INSERT OR IGNORE INTO media_files VALUES(?,?,NULL,?)",[.text(path),.text(prep),.text(instant)])
                if !files.exists(path) {try files.copy(CoreSchema.text(row[4]),to:path)}
                try checkPhoto(row,files.inspect(path))
                let result: CanonicalValue = .object(["kind":.string("ready"),"preparationId":.string(prep),"draftRevision":CoreSchema.canonical(draft[1]),"photo":CoreSchema.vector(row)])
                let request:CanonicalValue = .object(["draftId":CoreSchema.canonical(draft[0]),"draftRevision":CoreSchema.canonical(draft[1]),"selectionId":.string(selection),"observedDate":CoreSchema.canonical(row[10])])
                try sql.execute("INSERT INTO media_preparations VALUES(?,?,?,?,?,?,?,?,'ready',NULL,?,?)",[.text(prep),.text(try CanonicalCommand.hash(request)),draft[0],draft[1],.text(selection),row[0],draft[2],row[10],.text(try result.json()),.text(instant)])
                try sql.execute("INSERT INTO media_selections VALUES(?,'restored','library','expired',?)",[.text(selection),.text(instant)])
                for (id,kind) in [(prep,"preparation"),(selection,"selection")] {try sql.execute("INSERT INTO reservations VALUES(?,?,?,1)",[.text(id),.text(kind),.text(prep)])}
            }
        }
    }
}
