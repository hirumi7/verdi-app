import Foundation

public struct CoreRepositoryError: Error {
    public let code: String
    init(_ code: String) { self.code = code }
}

// All identifiers and SQL are compiled here. The channel never supplies SQL.
enum CoreSchema {
    static let maxRevision: Int64 = 9_007_199_254_740_991
    static let tables = ["plants", "routines", "heads", "care_events", "event_corrections", "routine_changes", "plant_drafts", "plant_catalog", "suggestion_snapshots", "routine_suggestions"]
    static let linkedTables: Set<String> = ["plant_catalog","routine_suggestions"]
    static let columns: [String: [String]] = [
        "plant_catalog": ["id","species_id","catalog_version","selection_json"],
        "suggestion_snapshots": ["id","routine_id","plant_id","species_id","catalog_version","care_kind","interval_count","interval_unit","source_label","context","captured_at"],
        "routine_suggestions": ["id","original_id","applied_id"],
        "plants": ["id","revision","name","location","notes","custom_species","light","toxicity","archived","created_at","updated_at"],
        "routines": ["id","plant_id","revision","care_kind","label","state","interval_count","interval_unit","anchor_date","first_check_anchor","first_check_date","created_at","updated_at"],
        "heads": ["id","routine_id","revision","next_check","override_date"],
        "care_events": ["id","plant_id","routine_id","revision","care_kind","care_label","original_date","original_outcome","recorded_at","recorded_zone","command_id"],
        "event_corrections": ["id","event_id","sequence","before_date","before_outcome","before_voided","after_date","after_outcome","after_voided","corrected_at","command_id","reason"],
        "routine_changes": ["id","plant_id","routine_id","command_id","kind","change_date","changed_at","recorded_zone","before_json","after_json"],
        "plant_drafts": ["id","revision","mode","plant_id","base_plant_revision","raw_fields_json","created_at","updated_at"],
    ]
    static let integerColumns: [String: Set<Int>] = ["suggestion_snapshots":[6],"plant_catalog":[],"routine_suggestions":[],"plants":[1,8],"routines":[2,6,9],"heads":[2],"care_events":[3],"event_corrections":[2,5,8],"routine_changes":[],"plant_drafts":[1,4]]
    static let nullableColumns: [String: Set<Int>] = ["routine_suggestions":[1],"routines":[10],"heads":[4],"plant_drafts":[3,4]]
    static let instantColumns: [String: Set<Int>] = ["suggestion_snapshots":[10],"plants":[9,10],"routines":[11,12],"care_events":[8],"event_corrections":[9],"routine_changes":[6],"plant_drafts":[6,7]]
    static let revisions = ["plants":1,"routines":2,"heads":2,"care_events":3,"plant_drafts":1]
    // The only fields a row update can change. Recording history is immutable.
    static let mutable: [String: Set<Int>] = ["plant_catalog":[1,2,3],"routine_suggestions":[2],"plants":[1,2,3,4,5,6,7,8,10],"routines":[2,5,6,7,8,9,10,12],"heads":[2,3,4],"care_events":[3],"plant_drafts":[1,4,5,7]]
    static let legacyDefinitions = [
        "CREATE TABLE metadata(slot INTEGER PRIMARY KEY CHECK(slot=1),dataset_id TEXT NOT NULL UNIQUE,profile TEXT NOT NULL CHECK(profile='custom_core_v1'),collection_revision INTEGER NOT NULL CHECK(collection_revision BETWEEN 1 AND 9007199254740991),storage_revision INTEGER NOT NULL CHECK(storage_revision BETWEEN 1 AND 9007199254740991),created_at TEXT NOT NULL)",
        "CREATE TABLE plants(id TEXT PRIMARY KEY NOT NULL,revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),name TEXT NOT NULL,location TEXT NOT NULL,notes TEXT NOT NULL,custom_species TEXT NOT NULL,light TEXT NOT NULL CHECK(light IN ('unknown','low','medium','brightIndirect','direct')),toxicity TEXT NOT NULL CHECK(toxicity IN ('unknown','toxic','nonToxic')),archived INTEGER NOT NULL CHECK(archived IN (0,1)),created_at TEXT NOT NULL,updated_at TEXT NOT NULL)",
        "CREATE TABLE routines(id TEXT PRIMARY KEY NOT NULL,plant_id TEXT NOT NULL REFERENCES plants(id),revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),care_kind TEXT NOT NULL CHECK(care_kind IN ('water','fertilize','mist','repot','rotate')),label TEXT NOT NULL,state TEXT NOT NULL CHECK(state IN ('active','paused','retired')),interval_count INTEGER NOT NULL CHECK(interval_count BETWEEN 1 AND 9999),interval_unit TEXT NOT NULL CHECK(interval_unit IN ('day','week','month','year')),anchor_date TEXT NOT NULL,first_check_anchor INTEGER NOT NULL CHECK(first_check_anchor IN (0,1)),first_check_date TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)",
        "CREATE UNIQUE INDEX current_kind ON routines(plant_id,care_kind) WHERE state!='retired'",
        "CREATE TABLE heads(id TEXT PRIMARY KEY NOT NULL,routine_id TEXT NOT NULL UNIQUE REFERENCES routines(id),revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),next_check TEXT NOT NULL,override_date TEXT)",
        "CREATE TABLE care_events(id TEXT PRIMARY KEY NOT NULL,plant_id TEXT NOT NULL REFERENCES plants(id),routine_id TEXT NOT NULL REFERENCES routines(id),revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),care_kind TEXT NOT NULL,care_label TEXT NOT NULL,original_date TEXT NOT NULL,original_outcome TEXT NOT NULL CHECK(original_outcome IN ('actual_care','checked_not_needed','skipped')),recorded_at TEXT NOT NULL,recorded_zone TEXT NOT NULL,command_id TEXT NOT NULL)",
        "CREATE TABLE event_corrections(id TEXT PRIMARY KEY NOT NULL,event_id TEXT NOT NULL REFERENCES care_events(id),sequence INTEGER NOT NULL CHECK(sequence BETWEEN 1 AND 9007199254740991),before_date TEXT NOT NULL,before_outcome TEXT NOT NULL,before_voided INTEGER NOT NULL CHECK(before_voided IN (0,1)),after_date TEXT NOT NULL,after_outcome TEXT NOT NULL,after_voided INTEGER NOT NULL CHECK(after_voided IN (0,1)),corrected_at TEXT NOT NULL,command_id TEXT NOT NULL,reason TEXT NOT NULL,UNIQUE(event_id,sequence))",
        "CREATE TABLE routine_changes(id TEXT PRIMARY KEY NOT NULL,plant_id TEXT NOT NULL REFERENCES plants(id),routine_id TEXT NOT NULL REFERENCES routines(id),command_id TEXT NOT NULL,kind TEXT NOT NULL,change_date TEXT NOT NULL,changed_at TEXT NOT NULL,recorded_zone TEXT NOT NULL,before_json TEXT NOT NULL,after_json TEXT NOT NULL)",
        "CREATE TABLE plant_drafts(id TEXT PRIMARY KEY NOT NULL,revision INTEGER NOT NULL CHECK(revision BETWEEN 1 AND 9007199254740991),mode TEXT NOT NULL CHECK(mode IN ('add','edit')),plant_id TEXT REFERENCES plants(id),base_plant_revision INTEGER CHECK(base_plant_revision BETWEEN 1 AND 9007199254740991),raw_fields_json TEXT NOT NULL,created_at TEXT NOT NULL,updated_at TEXT NOT NULL,CHECK((mode='add' AND plant_id IS NULL AND base_plant_revision IS NULL) OR (mode='edit' AND plant_id IS NOT NULL AND base_plant_revision IS NOT NULL)))",
        "CREATE UNIQUE INDEX add_draft ON plant_drafts(mode) WHERE mode='add'",
        "CREATE UNIQUE INDEX edit_draft ON plant_drafts(plant_id) WHERE mode='edit'",
        "CREATE TABLE intents(id TEXT PRIMARY KEY NOT NULL,type TEXT NOT NULL,hash TEXT NOT NULL,body TEXT,status TEXT NOT NULL CHECK(status IN ('pending','committed','abandoned')),CHECK((status='pending' AND body IS NOT NULL) OR (status!='pending' AND body IS NULL)))",
        "CREATE TABLE reservations(id TEXT PRIMARY KEY NOT NULL,kind TEXT NOT NULL,command_id TEXT NOT NULL,used INTEGER NOT NULL CHECK(used IN (0,1)))",
        "CREATE TABLE receipts(id TEXT PRIMARY KEY NOT NULL REFERENCES intents(id),hash TEXT NOT NULL,result TEXT NOT NULL,undo_context TEXT,undone INTEGER NOT NULL CHECK(undone IN (0,1)))",
        "CREATE TABLE outbox(slot INTEGER PRIMARY KEY CHECK(slot=1),dirty_revision INTEGER NOT NULL)",
    ]
    static let catalogDefinitions = [
        "CREATE TABLE catalog_head(slot INTEGER PRIMARY KEY CHECK(slot=1),version TEXT NOT NULL,manifest_json TEXT NOT NULL)",
        "CREATE TABLE catalog_entries(version TEXT NOT NULL,catalog_id TEXT NOT NULL,entry_json TEXT NOT NULL,PRIMARY KEY(version,catalog_id))",
        "CREATE TABLE catalog_identity(catalog_id TEXT PRIMARY KEY NOT NULL,first_identity TEXT NOT NULL)",
        "CREATE TABLE plant_catalog(id TEXT PRIMARY KEY NOT NULL REFERENCES plants(id),species_id TEXT NOT NULL,catalog_version TEXT NOT NULL,selection_json TEXT NOT NULL)",
        "CREATE TABLE suggestion_snapshots(id TEXT PRIMARY KEY NOT NULL,routine_id TEXT NOT NULL REFERENCES routines(id),plant_id TEXT NOT NULL REFERENCES plants(id),species_id TEXT NOT NULL,catalog_version TEXT NOT NULL,care_kind TEXT NOT NULL,interval_count INTEGER NOT NULL CHECK(interval_count BETWEEN 1 AND 9999),interval_unit TEXT NOT NULL,source_label TEXT NOT NULL,context TEXT NOT NULL,captured_at TEXT NOT NULL)",
        "CREATE TABLE routine_suggestions(id TEXT PRIMARY KEY NOT NULL REFERENCES routines(id),original_id TEXT REFERENCES suggestion_snapshots(id),applied_id TEXT NOT NULL REFERENCES suggestion_snapshots(id))",
    ]
    static let definitions = legacyDefinitions + catalogDefinitions
    static func schema(dataset: String? = nil, instant: String = "", version: Int32 = 2) -> CompiledSchema {
        let expected = version == 1 ? legacyDefinitions : definitions
        return CompiledSchema(applicationID: 0x56435231, version: version,
            statements: expected + (dataset.map { ["INSERT INTO metadata VALUES(1,'\($0)','custom_core_v1',1,1,'\(instant)')"] } ?? [])) { sql in
            let metadata = try sql.query("SELECT slot,dataset_id,profile,collection_revision,storage_revision FROM metadata")
            guard metadata.count == 1, metadata[0][0] == .integer(1), metadata[0][2] == .text("custom_core_v1") else { throw StorageFailure.integrityFailure }
            try uuid(text(metadata[0][1]))
            let actual = try sql.query("SELECT sql FROM sqlite_schema WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'")
            guard try Set(actual.map { try text($0[0]) }) == Set(expected) else { throw StorageFailure.schemaMismatch }
        }
    }
    static func row(_ sql: SQLiteSession, _ table: String, _ id: String) throws -> [SQLValue]? {
        guard let names = columns[table] else { throw CoreRepositoryError("PLAN_INVALID") }
        return try sql.query("SELECT \(names.joined(separator: ",")) FROM \(table) WHERE id=?", [.text(id)]).first
    }
    static func uuid(_ value: String) throws {
        guard value.count == 36, value == value.lowercased(), UUID(uuidString: value) != nil else { throw CoreRepositoryError("FIELD_INVALID") }
    }
    static func text(_ value: SQLValue) throws -> String { guard case .text(let v) = value else { throw StorageFailure.integrityFailure }; return v }
    static func integer(_ value: SQLValue) throws -> Int64 { guard case .integer(let v) = value else { throw StorageFailure.integrityFailure }; return v }
    static func canonical(_ value: SQLValue) -> CanonicalValue {
        switch value { case .null: return .null; case .integer(let v): return .integer(v); case .text(let v): return .string(v) }
    }
    static func vector(_ row: [SQLValue]) -> CanonicalValue { .array(row.map(canonical)) }
    static func rowHash(_ row: [SQLValue]) throws -> String { try CanonicalCommand.hash(vector(row)) }
    static func rawText(_ value: CanonicalValue) throws -> String {
        guard let units = value.units else { throw CoreRepositoryError("PLAN_INVALID") }
        let text = String(utf16CodeUnits: units, count: units.count)
        guard Array(text.utf16) == units else { throw CoreRepositoryError("PLAN_INVALID") }
        return text
    }
    static func scalar(_ value: CanonicalValue) throws -> SQLValue {
        if value.isNull { return .null }; if let n = value.integer { return .integer(n) }
        return .text(try rawText(value))
    }
    static func object(_ value: CanonicalValue?) throws -> [String: CanonicalValue] {
        guard let result = value?.object else { throw CoreRepositoryError("PLAN_INVALID") }; return result
    }
    static func string(_ value: CanonicalValue?) throws -> String {
        guard let result = value?.text else { throw CoreRepositoryError("PLAN_INVALID") }; return result
    }
    static func number(_ value: CanonicalValue?) throws -> Int64 {
        guard let result = value?.integer else { throw CoreRepositoryError("PLAN_INVALID") }; return result
    }
    static func array(_ value: CanonicalValue?) throws -> [CanonicalValue] {
        guard let result = value?.array else { throw CoreRepositoryError("PLAN_INVALID") }; return result
    }
    static func same(_ a: CanonicalValue?, _ b: CanonicalValue?) throws -> Bool {
        guard let a, let b else { return a == nil && b == nil }
        return try CanonicalCommand.bytes(a) == CanonicalCommand.bytes(b)
    }
}
