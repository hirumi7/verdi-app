import Foundation
import XCTest
import SQLite3
import ZIPFoundation
@testable import VerdiNative

extension CoreRepositoryTests {
    func testAddedCatalogRoutineMatchesNativeAndRetainsSuggestion() throws {
        try useCatalogFixture("added-catalog-routine-v5")
        for i in steps.indices {try execute(i);try open();try verifyRows(i)}
        XCTAssertEqual(try allRows("suggestion_snapshots").count,1)
    }

    func loadCustom(unicode:Bool = false) throws -> StoreAuthority {
        let file=try XCTUnwrap(Bundle.module.url(forResource:unicode ? "custom-unicode-v5":"custom-storage-v5",withExtension:"json",subdirectory:"Fixtures"))
        steps=try CoreSchema.array(CoreSchema.object(CanonicalParser.parse(String(contentsOf:file).trimmingCharacters(in:.whitespacesAndNewlines)))["steps"]).map(CoreSchema.object)
        let authority=StoreAuthority(configuration:storeTestConfig,installation:"custom-test",cache:TestStoreCache())
        repo.storeAuthority=authority;try authority.accept(storeEvidence(10));return authority
    }
    func customPlan(_ index:Int,_ authority:StoreAuthority) throws -> [String:CanonicalValue] {
        var p=try plan(index)
        if p["accessRevision"]?.isNull == false {p["accessRevision"] = .integer(authority.withCapability{$0.revision})}
        return try rehash(p)
    }
    func customExecute(_ index:Int,_ authority:StoreAuthority) throws {
        let p=try preview(customPlan(index,authority)),reply=try call("commit",["plan":.object(p)])
        if let ack=reply.object?["acknowledgementId"],!ack.isNull {_=try call("acknowledge",["commandId":p["commandId"]!,"acknowledgementId":ack])}
        try verifyRows(index)
    }
    func testCustomLifecycleParityReopenRenameHistoryAndDelete() throws {
        let authority=try loadCustom()
        for i in steps.indices {
            try customExecute(i,authority)
            if i != 7 {try open();try verifyRows(i)} // Undo must keep its live eight-second lease.
        }
        XCTAssertEqual(try allRows("custom_care_types").count,1)
        XCTAssertEqual(try allRows("routine_custom_types"),[])
    }
    func testCustomNativeGateRollbackLostReplyAndRetainedFreeEdits() throws {
        let authority=try loadCustom()
        try customExecute(0,authority);try customExecute(1,authority)
        try authority.accept(storeEvidence(20,revoked:true))
        let denied=try customPlan(2,authority)
        assertCode("PRO_REQUIRED"){_=try preview(denied)}
        XCTAssertEqual(try allRows("custom_care_types"),[])
        try authority.accept(storeEvidence(30,original:"2"))
        let accepted=try preview(customPlan(2,authority));failure = .beforeCommit
        XCTAssertThrowsError(try call("commit",["plan":.object(accepted)]))
        XCTAssertEqual(try allRows("custom_care_types"),[])
        try customExecute(2,authority)
        let routine=try preview(customPlan(3,authority));failure = .afterCommit
        XCTAssertThrowsError(try call("commit",["plan":.object(routine)]))
        try open();try verifyRows(3)
        // Same command retry resolves the committed receipt and cannot duplicate.
        _=try call("commit",["plan":.object(try customPlan(3,authority))]);try verifyRows(3)
        try authority.accept(storeEvidence(40,revoked:true,original:"2"))
        try customExecute(4,authority);try customExecute(5,authority)
        XCTAssertEqual(try allRows("care_events").map{$0[5]},[.text("Clean leaves"),.text("Dust leaves")])
    }
    func testCustomBackupRoundtripAndMalformedMappingRetainCurrent() throws {
        defer{removeBackupSidecars()}
        let authority=try loadCustom()
        for i in 0...10 {try customExecute(i,authority)}
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))})
        let (_,zip)=try exportBackup()
        let invalid=try alteredBackup(zip){data in var t=data["tables"]!.object!;t["routine_custom_types"] = .array([]);data["tables"] = .object(t)}
        let selection=try repo.retainBackupSelection(source:invalid),bad=UUID().uuidString.lowercased()
        _=try backup("startImport",["operationId":.string(bad),"selectionHandle":.string(selection)])
        XCTAssertEqual(try awaitBackup(bad).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table])}
        let (id,preview)=try previewBackup(zip)
        XCTAssertEqual(preview.object?["formatVersion"]?.integer,3)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
    }
    func testFormat2BackupImportsWithEmptyCustomTables() throws {
        defer{removeBackupSidecars()}
        for i in 0..<19 {try execute(i)}
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))})
        let (_,zip)=try exportBackup()
        let legacy=try alteredBackup(zip,manifestMutation:{m in
            m["formatVersion"] = .integer(2);m["dataSchemaVersion"] = .integer(2)
            var counts=m["counts"]!.object!;counts.removeValue(forKey:"customCareTypes");m["counts"] = .object(counts)
        }) {data in
            data["schemaVersion"] = .integer(2)
            var tables=data["tables"]!.object!;tables.removeValue(forKey:"custom_care_types");tables.removeValue(forKey:"routine_custom_types");data["tables"] = .object(tables)
        }
        let (id,preview)=try previewBackup(legacy)
        XCTAssertEqual(preview.object?["formatVersion"]?.integer,2)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
    }
    func testCustomMigrationFailuresDuringRebuildRollbackEveryOldRow() throws {
        for i in 0..<19 {try execute(i)}
        _=try call("close")
        let url=directory.appendingPathComponent("core.sqlite")
        var raw:OpaquePointer?;XCTAssertEqual(sqlite3_open(url.path,&raw),SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw,"BEGIN; \(legacyRoutinesDDL()) PRAGMA user_version=4; COMMIT;",nil,nil,nil),SQLITE_OK);sqlite3_close(raw)
        var old=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:4))
        let names=try old.read{try $0.query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").map{try CoreSchema.text($0[0])}}
        let before=try old.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}};try old.close()
        for index in 0...CoreSchema.customMigration.count {
            var broken=CoreSchema.customMigration;broken.insert("SELECT nonexistent_column FROM metadata",at:index)
            XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(),upgradeFrom:CoreSchema.schema(version:4),migrationStatements:broken,rebuildTables:true))
            old=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:4))
            XCTAssertEqual(try old.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}},before,"failure after \(index) statements")
            try old.close()
        }
        try open();XCTAssertEqual(try repo.database!.diagnostics().foreignKeys,1)
    }
    func testCustomUnicodeRenameBackupPreservesExactHistoricalLabels() throws {
        defer{removeBackupSidecars()}
        let authority=try loadCustom(unicode:true)
        for i in 0...10 {try customExecute(i,authority)}
        let events=try allRows("care_events"),types=try allRows("custom_care_types")
        XCTAssertEqual(events[0][5],.text("\u{200B}Feed"));XCTAssertEqual(events[1][5],.text("\u{200B}Dust"))
        let (_,zip)=try exportBackup(),(id,preview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertEqual(try allRows("care_events"),events);XCTAssertEqual(try allRows("custom_care_types"),types)
    }
    func testCustomLabelsUseDartWhitespaceForBackup() throws {
        let label="\u{200B}Feed"
        XCTAssertEqual(try CoreRegistry.validatedText(.string("\u{FEFF}"+label+"\u{FEFF}"),max:24,required:true),label)
        try BackupContent.validateRow("custom_care_types",[.text(UUID().uuidString.lowercased()),.integer(1),.text(label),.integer(0)])
        XCTAssertThrowsError(try BackupContent.validateRow("custom_care_types",[.text(UUID().uuidString.lowercased()),.integer(1),.text("\u{FEFF}"+label),.integer(0)]))
    }
    func testV3AndV4MigrationPreserveAllRowsAndFrozenDelete() throws {
        for version:Int32 in [3,4] {
            // Make a real old-schema file from retained rows, including draft, audits, and a frozen delete.
            if version == 4 {try tearDownWithError();try setUpWithError()}
            for i in 0...24 {try execute(i)}
            let pending=try plan(25),url=directory.appendingPathComponent("core.sqlite")
            _=try call("close")
            var raw:OpaquePointer?;XCTAssertEqual(sqlite3_open(url.path,&raw),SQLITE_OK)
            let sql="BEGIN; \(legacyRoutinesDDL()) \(version == 3 ? "DROP TABLE user_settings;":"") PRAGMA user_version=\(version); COMMIT;"
            XCTAssertEqual(sqlite3_exec(raw,sql,nil,nil,nil),SQLITE_OK);sqlite3_close(raw)
            let old=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:version))
            let names=try old.read{try $0.query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name").map{try CoreSchema.text($0[0])}}
            let before=try old.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}};try old.close()
            try open()
            XCTAssertEqual(try repo.database!.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}},before)
            let body=try call("pendingBody",["commandId":pending["commandId"]!])
            XCTAssertEqual(body.object?["payloadHash"]?.text,pending["payloadHash"]?.text)
            try execute(25)
        }
    }
}
