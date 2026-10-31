import Foundation
import XCTest
import SQLite3
@testable import VerdiNative

final class CoreRepositoryTests: XCTestCase {
    var directory: URL!
    var now = Date(timeIntervalSince1970:0)
    var ticks: TimeInterval = 100
    var failure: SQLiteBoundary?
    var blockWrites=false
    var repo: CoreRepository!
    var session = ""
    var dataset = ""
    var steps: [[String:CanonicalValue]] = []
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let file = try XCTUnwrap(Bundle.module.url(forResource:"core-storage-v3",withExtension:"json",subdirectory:"Fixtures"))
        let fixture = try CoreSchema.object(CanonicalParser.parse(String(contentsOf:file).trimmingCharacters(in:.whitespacesAndNewlines)))
        steps = try CoreSchema.array(fixture["steps"]).map(CoreSchema.object)
        now = try date(CoreSchema.string(steps[0]["instant"]))
        repo = CoreRepository(directory:directory,fault:{ [weak self] boundary in
            if self?.blockWrites == true && boundary == .beforeCommit {throw StorageFailure.unavailable}
            if self?.failure == boundary { self?.failure = nil; throw StorageFailure.unavailable }
        },now:{self.now},elapsed:{self.ticks},zone:{TimeZone(identifier:"Etc/UTC")!})
        try open()
    }
    override func tearDownWithError() throws {
        _ = try? call("close")
        if let directory { try? FileManager.default.removeItem(at:directory) }
        repo = nil
    }
    func date(_ value: String) throws -> Date {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime,.withFractionalSeconds]
        return try XCTUnwrap(f.date(from:value))
    }
    @discardableResult
    func call(_ op: String, _ values: [String:CanonicalValue] = [:]) throws -> CanonicalValue {
        var body = values
        if op != "open" { body["sessionId"] = .string(session) }
        return try CanonicalParser.parse(repo.call(operation:op,body:CanonicalValue.object(body).json()))
    }
    func open() throws {
        let result = try CoreSchema.object(call("open",["protocolVersion":.integer(1),"profile":.string("custom_core_v1")]))
        session = try CoreSchema.string(result["sessionId"]); dataset = try CoreSchema.string(result["datasetId"])
    }
    func plan(_ index: Int) throws -> [String:CanonicalValue] {
        now = try date(CoreSchema.string(steps[index]["instant"]))
        var intent = try CoreSchema.object(steps[index]["intent"]); intent["datasetId"] = .string(dataset)
        try call("freeze",["intent":.object(intent)])
        var plan = try CoreSchema.object(steps[index]["plan"])
        plan["sessionId"] = .string(session); plan["datasetId"] = .string(dataset)
        var result = try CoreSchema.object(plan["result"]); result["datasetId"] = .string(dataset); plan["result"] = .object(result)
        return try rehash(plan)
    }
    func rehash(_ original: [String:CanonicalValue]) throws -> [String:CanonicalValue] {
        var p = original; p.removeValue(forKey:"previewToken"); p.removeValue(forKey:"planHash")
        let hash = try CanonicalCommand.hash(.object(p)); p["previewToken"] = .null; p["planHash"] = .string(hash); return p
    }
    func preview(_ original: [String:CanonicalValue]) throws -> [String:CanonicalValue] {
        var p = original
        if CoreRegistry.needsPreview(try CoreSchema.string(p["commandType"])) {
            let result = try CoreSchema.object(call("preview",["plan":.object(p)])); p["previewToken"] = result["previewToken"]
        }
        return p
    }
    @discardableResult
    func execute(_ index: Int, verify: Bool = true) throws -> [String:CanonicalValue] {
        do {
            let p = try preview(plan(index))
            let reply = try CoreSchema.object(call("commit",["plan":.object(p)]))
            if let ack = reply["acknowledgementId"], !ack.isNull {
                let offer = try call("acknowledge",["commandId":p["commandId"]!,"acknowledgementId":ack])
                XCTAssertEqual(offer.object?["expiresInMilliseconds"]?.integer,8000)
            }
            if verify { try verifyRows(index) }
            return reply
        } catch { XCTFail("step \(index) \(steps[index]["intent"]?.object?["commandType"]?.text ?? "?"): \(error)"); throw error }
    }
    func allRows(_ table: String) throws -> [[SQLValue]] {
        let metadata = try CoreSchema.object(call("metadata")); var cursor: CanonicalValue = .null; var rows: [[SQLValue]] = []
        repeat {
            let page = try CoreSchema.object(call("readRows",["table":.string(table),"storageRevision":metadata["storageRevision"]!,"after":cursor]))
            rows += try CoreSchema.array(page["rows"]).map { try CoreSchema.array($0).map(CoreSchema.scalar) }
            cursor = page["nextCursor"]!
        } while !cursor.isNull
        return rows
    }
    func verifyRows(_ index: Int) throws {
        for table in CoreSchema.tables {
            let actual = try CanonicalCommand.hash(.array(allRows(table).map(CoreSchema.vector)))
            let expected=steps[index]["tableHashes"]?.object?[table]?.text
            if expected==nil && ["journal_entries","journal_drafts","media_drafts","photos","plant_covers"].contains(table) {XCTAssertEqual(try allRows(table),[],"historical fixture must have no media rows")}
            else {XCTAssertEqual(actual,expected,"step \(index), \(table)")}
        }
    }
    func testJournalCommandsMatchDartAndSurviveReopen() throws {
        let file=try XCTUnwrap(Bundle.module.url(forResource:"journal-storage-v3",withExtension:"json",subdirectory:"Fixtures"))
        steps=try CoreSchema.array(CoreSchema.object(CanonicalParser.parse(String(contentsOf:file).trimmingCharacters(in:.whitespacesAndNewlines)))["steps"]).map(CoreSchema.object)
        for index in steps.indices {try execute(index);try open();try verifyRows(index)}
    }
    func testPhotoPreparationPersistsOriginalAndAcknowledgedPlantDraft() throws {
        try execute(0)
        let draft=try CoreSchema.string(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["draftId"])
        let source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))
        let original=try Data(contentsOf:source),selection=try repo.retainMediaSelection(source:source,kind:"library"),prep=UUID().uuidString.lowercased()
        let args:[String:CanonicalValue] = ["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(prep),"selectionId":.string(selection),"observedDate":.string("2026-10-20")]
        try call("preparePhoto",args)
        var result:CanonicalValue = .null
        for _ in 0..<100 {result=try call("photoPreparation",["preparationId":.string(prep)]);if result.object?["kind"]?.text != "copying" {break};Thread.sleep(forTimeInterval:0.02)}
        XCTAssertEqual(result.object?["kind"]?.text,"ready")
        XCTAssertEqual(result.object?["draftRevision"]?.integer,2)
        let photo=try XCTUnwrap(result.object?["photo"]?.array),path=try CoreSchema.string(photo[4])
        XCTAssertTrue(path.hasPrefix("media/"))
        XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(path)),original)
        let saved=try allRows("photos"),drafts=try allRows("plant_drafts")
        try open();XCTAssertEqual(try allRows("photos"),saved);XCTAssertEqual(try allRows("plant_drafts"),drafts)
        XCTAssertEqual(try call("photoPreparation",["preparationId":.string(prep)]).json(),try result.json())
        XCTAssertEqual(try call("preparePhoto",args).json(),try result.json())
        var changed=args;changed["observedDate"] = .string("2026-10-19")
        assertCode("COMMAND_ID_REUSED"){_=try call("preparePhoto",changed)}
    }
    func testSelectionExpiryIsEnforcedWithoutRestart() throws {
        try execute(0)
        let source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))
        let selection=try repo.retainMediaSelection(source:source,kind:"library")
        now=now.addingTimeInterval(86401)
        let draft=try CoreSchema.string(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["draftId"])
        assertCode("MEDIA_SELECTION_EXPIRED"){_=try call("preparePhoto",["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(UUID().uuidString.lowercased()),"selectionId":.string(selection),"observedDate":.string("2026-10-20")])}
        XCTAssertEqual(try allRows("photos"),[])
    }
    func testPreparationFailureWriteCanRecoverWithoutSessionRestart() throws {
        try execute(0)
        let draft=try CoreSchema.string(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["draftId"])
        let source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))
        let selection=try repo.retainMediaSelection(source:source,kind:"library"),id=UUID().uuidString.lowercased()
        var failPublication=true
        repo.mediaWorker.sync {repo.mediaFiles=try! MediaFiles(root:directory,fault:{boundary in
            if boundary == .publish && failPublication {self.repo.queue.sync{self.blockWrites=true};throw CoreRepositoryError("IO_FAILURE")}
        })}
        var args:[String:CanonicalValue] = ["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(id),"selectionId":.string(selection),"observedDate":.string("2026-10-20")]
        try call("preparePhoto",args);repo.mediaWorker.sync{}
        XCTAssertThrowsError(try call("photoPreparation",["preparationId":.string(id)]))
        repo.queue.sync{blockWrites=false}
        XCTAssertEqual(try call("photoPreparation",["preparationId":.string(id)]).object?["kind"]?.text,"failed")
        XCTAssertEqual(try allRows("photos"),[])
        failPublication=false
        let retry=UUID().uuidString.lowercased();args["preparationId"] = .string(retry)
        try call("preparePhoto",args);repo.mediaWorker.sync{}
        XCTAssertEqual(try call("photoPreparation",["preparationId":.string(retry)]).object?["kind"]?.text,"ready")
        XCTAssertEqual(try allRows("photos").count,1)
    }
    func testJournalDeletePreviewRejectsAdvancedEditDraft() throws {
        let file=try XCTUnwrap(Bundle.module.url(forResource:"journal-storage-v3",withExtension:"json",subdirectory:"Fixtures"))
        steps=try CoreSchema.array(CoreSchema.object(CanonicalParser.parse(String(contentsOf:file).trimmingCharacters(in:.whitespacesAndNewlines)))["steps"]).map(CoreSchema.object)
        for i in 0..<9 {try execute(i)}
        let prepared=try preview(plan(9)),before=try allRows("journal_entries")
        try repo.queue.sync {try repo.database!.transaction{sql in try sql.execute("UPDATE journal_drafts SET revision=revision+1")}}
        XCTAssertThrowsError(try call("commit",["plan":.object(prepared)]))
        XCTAssertEqual(try allRows("journal_entries"),before)
        XCTAssertEqual(try allRows("journal_drafts").count,1)
    }
    func testExactV2MigrationPreservesAllRowsAndFrozenCommand() throws {
        try execute(0);_ = try plan(1);_ = try call("close")
        let url=directory.appendingPathComponent("core.sqlite")
        var raw:OpaquePointer?;XCTAssertEqual(sqlite3_open(url.path,&raw),SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw,"BEGIN; DROP TABLE user_settings; DROP TABLE plant_covers; DROP TABLE media_drafts; DROP TABLE journal_drafts; DROP TABLE journal_entries; DROP TABLE photos; DROP TABLE media_preparations; DROP TABLE media_selections; DROP TABLE media_files; DROP TABLE media_cleanup; PRAGMA user_version=2; COMMIT;",nil,nil,nil),SQLITE_OK)
        sqlite3_close(raw)
        let old=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:2))
        let tables=Array(CoreSchema.tables.filter{!["plant_covers","media_drafts","journal_drafts","journal_entries","photos"].contains($0)})+["metadata","intents","reservations","receipts","outbox"]
        let before=try old.read{sql in try tables.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}};try old.close()
        try open()
        XCTAssertEqual(try repo.queue.sync{try repo.database!.read{sql in try tables.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}}},before)
        try execute(1)
    }
    func seedSavedPhoto() throws -> (String,URL) {
        try execute(0);try execute(1)
        let plant=try CoreSchema.text(allRows("plants").first![0]),id=UUID().uuidString.lowercased()
        let files=try MediaFiles(root:directory),source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))
        try files.importSelection(source,to:"staging/test.copy")
        let info=try files.inspect("staging/test.copy"),path="media/\(id)/\(info.hash).png"
        try files.publish("staging/test.copy",to:path)
        try repo.queue.sync{try repo.database!.transaction{sql in
            try sql.execute("INSERT INTO photos VALUES(?,?,NULL,1,?,?,?,?,?,?,'2026-10-20','library',NULL,?)",[.text(id),.text(plant),.text(path),.text(info.hash),.integer(info.bytes),.text(info.mime),.integer(info.width),.integer(info.height),.text(repo.mediaClock())])
            try repo.registerMediaPath(sql,path)
        }}
        return(id,directory.appendingPathComponent(path))
    }
    func testExportLeaseSurvivesReconnectThenCleansAfterRelease() throws {
        let (photo,original)=try seedSavedPhoto(),done=expectation(description:"export")
        var result:Result<URL,Error>?
        repo.exportOriginal(photoID:photo,revision:1){result=$0;done.fulfill()};wait(for:[done],timeout:5)
        let url=try XCTUnwrap(result).get();XCTAssertEqual(try Data(contentsOf:url),try Data(contentsOf:original))
        try open();repo.mediaWorker.sync{}
        XCTAssertTrue(FileManager.default.fileExists(atPath:url.path))
        repo.releaseExport(url);repo.mediaWorker.sync{}
        XCTAssertFalse(FileManager.default.fileExists(atPath:url.path));XCTAssertTrue(FileManager.default.fileExists(atPath:original.path))
    }
    func testAbandonedExportExpiresAndOnlyKnownPathIsRemoved() throws {
        let (photo,original)=try seedSavedPhoto(),done=expectation(description:"export")
        var result:Result<URL,Error>?
        repo.exportOriginal(photoID:photo,revision:1){result=$0;done.fulfill()};wait(for:[done],timeout:5)
        let url=try XCTUnwrap(result).get(),unrelated=directory.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to:unrelated);now=now.addingTimeInterval(86401)
        try call("retryMediaCleanup");repo.mediaWorker.sync{}
        XCTAssertFalse(FileManager.default.fileExists(atPath:url.path));XCTAssertTrue(FileManager.default.fileExists(atPath:original.path));XCTAssertTrue(FileManager.default.fileExists(atPath:unrelated.path))
    }
    func assertCode(_ code: String, _ work: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try work(),file:file,line:line) { error in
            XCTAssertEqual((error as? CoreRepositoryError)?.code,code,file:file,line:line)
        }
    }
    func testV1PendingSaveAndDeleteSurviveMigrationWithEveryOldRow() throws {
        let legacyFile=try XCTUnwrap(Bundle.module.url(forResource:"core-storage-legacy-v1",withExtension:"json",subdirectory:"Fixtures"))
        let oldSteps=try CoreSchema.array(CoreSchema.object(CanonicalParser.parse(String(contentsOf:legacyFile).trimmingCharacters(in:.whitespacesAndNewlines)))["steps"]).map(CoreSchema.object)
        let tables=Array(CoreSchema.tables.prefix(7))+["metadata","intents","reservations","receipts","outbox"]
        for pending in [1,25] {
            for index in (pending==1 ? 0:2)..<pending {try execute(index)}
            var oldIntent=try CoreSchema.object(oldSteps[pending]["intent"]);oldIntent["datasetId"] = .string(dataset)
            try call("freeze",["intent":.object(oldIntent)])
            _=try call("close")
            let url=directory.appendingPathComponent("core.sqlite")
            var db=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema())
            let before=try db.read {sql in try tables.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}}
            // Exact original v1 DDL, actual persisted rows/frozen v1 payloads.
            try db.close()
            var raw: OpaquePointer?
            XCTAssertEqual(sqlite3_open(url.path,&raw),SQLITE_OK)
            defer {sqlite3_close(raw)}
            XCTAssertEqual(sqlite3_exec(raw,"BEGIN; DROP TABLE user_settings; DROP TABLE plant_covers; DROP TABLE media_drafts; DROP TABLE journal_drafts; DROP TABLE journal_entries; DROP TABLE photos; DROP TABLE media_preparations; DROP TABLE media_selections; DROP TABLE media_files; DROP TABLE media_cleanup; DROP TABLE routine_suggestions; DROP TABLE suggestion_snapshots; DROP TABLE plant_catalog; DROP TABLE catalog_head; DROP TABLE catalog_entries; DROP TABLE catalog_identity; PRAGMA user_version=1; COMMIT;",nil,nil,nil),SQLITE_OK)
            sqlite3_close(raw);raw=nil
            db=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:1));try db.close()
            XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(),upgradeFrom:CoreSchema.schema(version:1),migrationStatements:CoreSchema.catalogDefinitions+CoreSchema.mediaDefinitions,fault:{if $0 == .beforeCommit {throw StorageFailure.unavailable}}))
            db=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:1))
            XCTAssertEqual(try db.read {sql in try tables.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}},before);try db.close()
            XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(),upgradeFrom:CoreSchema.schema(version:1),migrationStatements:CoreSchema.catalogDefinitions+CoreSchema.mediaDefinitions,fault:{if $0 == .afterCommit {throw StorageFailure.unavailable}}))
            try open()
            db=try SQLiteDatabase.open(at:url,schema:CoreSchema.schema())
            XCTAssertEqual(try db.read {sql in try tables.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}},before);try db.close()
            XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:CoreSchema.schema(version:1)))
            let pendingBody=try call("pendingBody",["commandId":oldIntent["commandId"]!])
            XCTAssertEqual(try pendingBody.json(),try CanonicalValue.object(oldIntent).json())
            // Replan using v2 vectors, preserving exact v1 command identity/hash.
            XCTAssertEqual(steps[pending]["intent"]?.object?["payloadHash"]?.text,oldIntent["payloadHash"]?.text)
            try execute(pending)
            let receipt=try call("resolve",["commandId":oldIntent["commandId"]!,"payloadHash":oldIntent["payloadHash"]!])
            XCTAssertNotNil(receipt.object)
        }
    }
    func useCatalogFixture(_ fixtureName: String = "catalog-storage-v2") throws {
        _ = try call("close")
        try FileManager.default.removeItem(at:directory)
        let file=try XCTUnwrap(Bundle.module.url(forResource:fixtureName,withExtension:"json",subdirectory:"Fixtures"))
        let fixture=try CoreSchema.object(CanonicalParser.parse(String(contentsOf:file).trimmingCharacters(in:.whitespacesAndNewlines)))
        steps=try CoreSchema.array(fixture["steps"]).map(CoreSchema.object)
        now=try date(CoreSchema.string(steps[0]["instant"]))
        repo=CoreRepository(directory:directory,fault:{[weak self] b in if self?.failure==b {self?.failure=nil;throw StorageFailure.unavailable}},now:{self.now},elapsed:{self.ticks},zone:{TimeZone(identifier:"Etc/UTC")!},catalog:catalogBytes)
        try open()
        XCTAssertEqual(try call("catalogMeta").object?["version"]?.text,"verdi-2026-10-31.1")
    }
    func corruptCatalog(_ work: (SQLiteSession) throws -> Void) throws {
        _=try call("close")
        let db=try SQLiteDatabase.open(at:directory.appendingPathComponent("core.sqlite"),schema:CoreSchema.schema())
        try db.transaction(work);try db.close();try open()
    }
    func testRetainedInvalidGuideCannotGrantNewSelectionButCustomStillSaves() throws {
        try useCatalogFixture()
        try corruptCatalog {sql in
            let raw=try sql.query("SELECT entry_json FROM catalog_entries WHERE catalog_id='sp_epipremnum_aureum'")[0][0]
            var e=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(raw))),review=e["contentReview"]!.object!
            review["outcome"] = .string("pending");e["contentReview"] = .object(review)
            try sql.execute("UPDATE catalog_entries SET entry_json=? WHERE catalog_id='sp_epipremnum_aureum'",[.text(try CanonicalValue.object(e).json())])
        }
        try execute(0)
        assertCode("CATALOG_SELECTION_STALE") {_=try preview(plan(1))}
        try verifyRows(0)

    }
    func testMalformedCatalogMetadataDoesNotBlockCustomCommands() throws {
        let custom=steps
        try useCatalogFixture();steps=custom
        let originalManifest=try call("catalogMeta").object!["manifest"]!.object!
        var badAssets=originalManifest;badAssets["assets"] = .integer(1)
        var badArt=originalManifest;badArt["speciesArt"] = .array([.string("invalid")])
        for malformed in ["{", "{\"popularIds\":1}",try CanonicalValue.object(badAssets).json(),try CanonicalValue.object(badArt).json()] {
            try corruptCatalog {try $0.execute("UPDATE catalog_head SET manifest_json=?",[.text(malformed)])}
            assertCode("CATALOG_UNAVAILABLE") {_=try call("catalogMeta")}
        }
        try execute(0);try execute(1);try execute(2);try execute(3);try execute(4)
    }
    func testWrongEmbeddedCatalogIDCannotGrantNewSelection() throws {
        try useCatalogFixture()
        try corruptCatalog {sql in
            let row=try sql.query("SELECT entry_json FROM catalog_entries WHERE catalog_id='sp_epipremnum_aureum'")[0][0]
            var entry=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row)))
            entry["id"] = .string("wrong_id")
            try sql.execute("UPDATE catalog_entries SET entry_json=? WHERE catalog_id='sp_epipremnum_aureum'",[.text(try CanonicalValue.object(entry).json())])
        }
        try execute(0)
        assertCode("CATALOG_SELECTION_STALE") {_=try preview(plan(1))}
        try verifyRows(0)
    }
    func testUnsupportedRetainedToxicityIsUnknownAndWrongEmbeddedIDRejects() throws {
        try useCatalogFixture()
        try corruptCatalog {sql in
            let row=try sql.query("SELECT entry_json FROM catalog_entries WHERE catalog_id='sp_zamioculcas_zamiifolia'")[0][0]
            var e=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row))),t=e["toxicity"]!.object!
            t["value"] = .string("non-toxic");t["sourceRefs"] = .array([]);e["toxicity"] = .object(t)
            try sql.execute("UPDATE catalog_entries SET entry_json=? WHERE catalog_id='sp_zamioculcas_zamiifolia'",[.text(try CanonicalValue.object(e).json())])
        }
        let page=try call("catalogRows",["version":.string("verdi-2026-10-31.1"),"after":.null])
        let zz=page.object!["entries"]!.array!.first{$0.object?["id"]?.text=="sp_zamioculcas_zamiifolia"}!
        XCTAssertEqual(zz.object?["toxicity"]?.object?["value"]?.text,"unknown")
        XCTAssertEqual(try call("catalogMeta").object?["limitation"]?.text,"CATALOG_UNAVAILABLE")
        try corruptCatalog {sql in
            let row=try sql.query("SELECT entry_json FROM catalog_entries LIMIT 1")[0][0]
            var e=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row)));e["id"] = .string("wrong_id")
            try sql.execute("UPDATE catalog_entries SET entry_json=? WHERE entry_json=?",[.text(try CanonicalValue.object(e).json()),row])
        }
        assertCode("CATALOG_UNAVAILABLE") {_=try call("catalogRows",["version":.string("verdi-2026-10-31.1"),"after":.null])}
    }
    func testCatalogUpdateKeepsSavedRowsAndRejectsOldNewSelection() throws {
        try useCatalogFixture();try execute(0);try execute(1)
        let bytes=try catalogBytes()
        var manifest=try CoreSchema.object(CanonicalParser.package(String(decoding:bytes.manifest,as:UTF8.self))),entries=try CoreSchema.array(CanonicalParser.package(String(decoding:bytes.entries,as:UTF8.self)))
        let index=try XCTUnwrap(entries.firstIndex{$0.object?["id"]?.text=="sp_epipremnum_aureum"})
        var e=entries[index].object!;e["commonName"] = .string("Reviewed rename fixture");e["entryVersion"] = .integer(2);entries[index] = .object(e)
        let raw=try CanonicalCommand.bytes(.array(entries));manifest["catalogVersion"] = .string("verdi-test-update.2");manifest["entriesSha256"] = .string(CatalogPackage.digest(raw))
        let next=try BundledCatalogBytes(manifest:CanonicalCommand.bytes(.object(manifest)),entries:raw,assets:bytes.assets)
        _=try call("close")
        repo=CoreRepository(directory:directory,fault:nil,now:{self.now},zone:{TimeZone(identifier:"Etc/UTC")!},catalog:{next})
        try open();try verifyRows(1)
        XCTAssertEqual(try call("catalogMeta").object?["version"]?.text,"verdi-test-update.2")
        try execute(2)
        assertCode("CATALOG_SELECTION_STALE") {_=try preview(plan(3))}
        try verifyRows(2)
    }
    func testCatalogSharedReplayAndReopen() throws {
        try useCatalogFixture()
        for index in steps.indices {
            try execute(index)
            if index+1 == steps.count || steps[index+1]["intent"]?.object?["commandType"]?.text != "Undo" {try open()}
            try verifyRows(index)
        }
    }
    func testUnknownSeedApplyKeepsHeadAndStillCommitsItsGuardedResult() throws {
        try useCatalogFixture("catalog-unknown-v2")
        for index in 0...2 {try execute(index)}
        let heads=try allRows("heads")
        try execute(3)
        XCTAssertEqual(try allRows("heads"),heads)
        XCTAssertEqual(try allRows("suggestion_snapshots").count,2)
        try open();try verifyRows(3)
    }
    func testCatalogApplyRejectsForgedOverrideAndRollsBackAtomically() throws {
        try useCatalogFixture();try execute(0);try execute(1);try execute(2)
        let good=try plan(3)
        var bad=good, statements=try CoreSchema.array(good["statements"])
        for i in statements.indices {
            var s=try CoreSchema.object(statements[i]);if s["key"]?.text=="heads.update" {
                var values=try CoreSchema.array(s["values"]);values[4] = .string("2030-01-01");s["values"] = .array(values);statements[i] = .object(s)
            }
        }
        bad["statements"] = .array(statements)
        assertCode("PLAN_INVALID") {_ = try preview(rehash(bad))}
        failure = .beforeCommit
        let p=try preview(good)
        XCTAssertThrowsError(try call("commit",["plan":.object(p)]))
        try open();try verifyRows(2)
        _=try call("commit",["plan":.object(try preview(plan(3)))])
        try verifyRows(3)
    }
    func testAllCommandsMatchDartRowsAndSurviveReopen() throws {
        for index in steps.indices {
            try execute(index)
            if [3,10,18,24,27].contains(index) { try open(); try verifyRows(index) }
        }
        XCTAssertEqual(Set(steps.compactMap{$0["intent"]?.object?["commandType"]?.text}),CoreRegistry.commands.subtracting(CoreRegistry.mediaCommands))
    }
    func testAtomicRollbackAndLostReplyResolveWithoutDuplicate() throws {
        let p = try plan(0)
        failure = .beforeCommit
        assertCode("STORAGE_UNAVAILABLE") { _ = try call("commit",["plan":.object(p)]) }
        XCTAssertTrue(try allRows("plant_drafts").isEmpty)
        XCTAssertTrue(try call("resolve",["commandId":p["commandId"]!]).isNull)
        failure = .afterCommit
        assertCode("UNKNOWN_OUTCOME") { _ = try call("commit",["plan":.object(p)]) }
        try open()
        let receipt = try call("resolve",["commandId":p["commandId"]!])
        XCTAssertEqual(try receipt.object?["replayed"]?.json(),"true")
        XCTAssertEqual(try allRows("plant_drafts").count,1)
        try verifyRows(0)
    }
    func testPendingFreezeReopenPreservesBodyIDsAndRawDraft() throws {
        let p = try plan(0), id = p["commandId"]!
        let before = try call("pendingBody",["commandId":id]).json()
        try open()
        XCTAssertEqual(try call("pendingBody",["commandId":id]).json(),before)
        XCTAssertTrue(try allRows("plant_drafts").isEmpty)
        try execute(0)
        XCTAssertTrue(try CoreSchema.array(CoreSchema.object(call("pending"))["items"]).isEmpty)
        try execute(1)
        var retry = p; retry["sessionId"] = .string(session); retry = try rehash(retry)
        let result = try call("commit",["plan":.object(retry)])
        XCTAssertEqual(try result.object?["result"]?.object?["replayed"]?.json(),"true")
        XCTAssertTrue(result.object?["acknowledgementId"]?.isNull == true)
    }
    func testForgedPlanAndPreviewDateCannotChangeRows() throws {
        try execute(0); let p = try plan(1)
        var bad = p; bad["accessRevision"] = .null; bad = try rehash(bad)
        assertCode("PREVIEW_STALE") { _ = try preview(bad) }
        var forged = try preview(p)
        var result = try CoreSchema.object(forged["result"]); result["primaryId"] = .string(UUID().uuidString.lowercased()); forged["result"] = .object(result)
        let token = forged["previewToken"]; forged = try rehash(forged); forged["previewToken"] = token
        assertCode("PREVIEW_STALE") { _ = try call("commit",["plan":.object(forged)]) }
        let reviewed = try preview(p); now = now.addingTimeInterval(86400)
        assertCode("PREVIEW_STALE") { _ = try call("commit",["plan":.object(reviewed)]) }
        XCTAssertTrue(try allRows("plants").isEmpty); try verifyRows(0)
    }
    func testUndoNativeDeadlineAndAcknowledgementCannotRenew() throws {
        for index in 0...3 { try execute(index) }
        let p = try preview(plan(4)), reply = try CoreSchema.object(call("commit",["plan":.object(p)]))
        let ack = reply["acknowledgementId"]!
        let args = ["commandId":p["commandId"]!,"acknowledgementId":ack]
        XCTAssertEqual(try call("acknowledge",args).object?["expiresInMilliseconds"]?.integer,8000)
        ticks += 7.999
        let remaining = try call("acknowledge",args).object?["expiresInMilliseconds"]?.integer
        XCTAssertNotNil(remaining); XCTAssertLessThanOrEqual(remaining!,1)
        let undo = try plan(5); ticks = 108
        assertCode("UNDO_EXPIRED") { _ = try call("commit",["plan":.object(undo)]) }
        XCTAssertTrue(try call("acknowledge",args).isNull)
        try verifyRows(4)
        try open()
        XCTAssertTrue(try call("acknowledge",args).isNull)
    }
    func testUndoOneMillisecondBeforeExpirySucceedsAndBackgroundInvalidates() throws {
        for index in 0...4 { try execute(index) }
        ticks += 7.999; try execute(5)
        try execute(6); let original = steps[6]["intent"]!.object!["commandId"]!
        repo.invalidateUndo()
        XCTAssertNil(repo.grants[original.text!])
    }
    func testMissingInitializedDatabaseNeverResets() throws {
        try execute(0); try call("close")
        try FileManager.default.removeItem(at:directory.appendingPathComponent("core.sqlite"))
        assertCode("STORAGE_UNAVAILABLE") { try open() }
        XCTAssertFalse(FileManager.default.fileExists(atPath:directory.appendingPathComponent("core.sqlite").path))
    }
    func draftPlan(fields: [String:CanonicalValue], draftID: String, expected: Int64?) throws -> [String:CanonicalValue] {
        let id=UUID().uuidString.lowercased()
        var payload=try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"])
        payload["draftId"] = .string(draftID); payload["expectedRevision"] = expected.map(CanonicalValue.integer) ?? .null; payload["rawFields"] = .object(fields)
        let hash=try CanonicalCommand.commandHash(type:"SaveDraft",payload:payload)
        let intent: CanonicalValue = .object(["commandId":.string(id),"datasetId":.string(dataset),"commandType":.string("SaveDraft"),"normalisedPayload":.object(payload),"payloadHash":.string(hash),"allocatedIds":.array([])])
        try call("freeze",["intent":intent])
        var p=try CoreSchema.object(steps[0]["plan"]), statement=try CoreSchema.object(CoreSchema.array(p["statements"])[0])
        var values=try CoreSchema.array(statement["values"])
        let old=try allRows("plant_drafts").first { $0[0] == .text(draftID) }
        values[0] = .string(draftID); values[1] = .integer((expected ?? 0)+1)
        values[5] = .string(try CanonicalValue.object(["version":.integer(1),"fields":.object(fields)]).json())
        if let old { values[6]=CoreSchema.canonical(old[6]) }
        statement["values"] = .array(values); statement["key"] = .string(expected == nil ? "plant_drafts.insert" : "plant_drafts.update")
        statement["beforeHash"] = try old.map { .string(try CoreSchema.rowHash($0)) } ?? .null
        p["sessionId"] = .string(session); p["datasetId"] = .string(dataset); p["commandId"] = .string(id); p["normalisedPayload"] = .object(payload); p["payloadHash"] = .string(hash)
        p["draftGuards"] = .array([.object(["draftId":.string(draftID),"revision":expected.map(CanonicalValue.integer) ?? .null])]); p["statements"] = .array([.object(statement)])
        var result=try CoreSchema.object(p["result"]); result["commandId"] = .string(id); result["datasetId"] = .string(dataset); result["primaryId"] = .string(draftID); result["resourceIds"] = .array([.string(draftID)]); result["newRevisions"] = .object([draftID:.integer((expected ?? 0)+1)])
        p["result"] = .object(result); return try rehash(p)
    }
    func testLargeEscapedDraftAndSameInstantUpdatePersistExactly() throws {
        var fields=try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["rawFields"])
        let raw=String(repeating:"\\",count:510000)
        fields["notes"] = .string(raw); fields["name"] = .utf16([0xd800])
        let id=UUID().uuidString.lowercased()
        for expected: Int64? in [nil,1] {
            let p=try draftPlan(fields:fields,draftID:id,expected:expected)
            XCTAssertLessThan(try CanonicalValue.object(p).json().utf8.count,4*1024*1024)
            try call("commit",["plan":.object(p)])
            let row=try XCTUnwrap(allRows("plant_drafts").first)
            let stored=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[5])))
            XCTAssertTrue(try CoreSchema.same(stored["fields"],.object(fields)))
            XCTAssertEqual(row[1],.integer((expected ?? 0)+1))
        }
    }
    func testMalformedDraftCannotFreezeOrPoisonStartup() throws {
        var intent=try CoreSchema.object(steps[0]["intent"]), payload=try CoreSchema.object(intent["normalisedPayload"])
        var fields=try CoreSchema.object(payload["rawFields"]); fields["notes"] = .object(["wrong":.string("type")]); payload["rawFields"] = .object(fields)
        intent["datasetId"] = .string(dataset); intent["normalisedPayload"] = .object(payload); intent["payloadHash"] = .string(try CanonicalCommand.commandHash(type:"SaveDraft",payload:payload))
        assertCode("FIELD_INVALID") { try call("freeze",["intent":.object(intent)]) }
        try open(); XCTAssertTrue(try allRows("plant_drafts").isEmpty)
        XCTAssertTrue(try CoreSchema.array(CoreSchema.object(call("pending"))["items"]).isEmpty)
    }
    func testCanonicalRawTextIsByteExactAndBOMTrimmingMatchesDart() throws {
        XCTAssertFalse(try CoreSchema.same(.string("\u{00e9}"),.string("e\u{0301}")))
        XCTAssertNotEqual(SQLValue.text("\u{00e9}"),SQLValue.text("e\u{0301}"))
        XCTAssertEqual(CoreRegistry.trimLikeDart("\u{feff}Fern\u{feff}"),"Fern")
        var fields=try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["rawFields"])
        fields["name"] = .string("\u{00e9}")
        var p=try draftPlan(fields:fields,draftID:UUID().uuidString.lowercased(),expected:nil)
        var statement=try CoreSchema.object(CoreSchema.array(p["statements"])[0]), values=try CoreSchema.array(statement["values"])
        fields["name"] = .string("e\u{0301}")
        values[5] = .string(try CanonicalValue.object(["version":.integer(1),"fields":.object(fields)]).json()); statement["values"] = .array(values)
        p["statements"] = .array([.object(statement)]); p=try rehash(p)
        assertCode("PLAN_INVALID") { try call("commit",["plan":.object(p)]) }
        XCTAssertTrue(try allRows("plant_drafts").isEmpty)
    }
    func testNewEditDraftAfterDeletePreviewBlocksDeletion() throws {
        for index in 0...24 { try execute(index) }
        let p=try preview(plan(25)), plant=try CoreSchema.string(p["normalisedPayload"]?.object?["plantId"])
        let plantRevision=try CoreSchema.number(p["normalisedPayload"]?.object?["plantRevision"])
        // Another acknowledged edit-draft transaction changes no collection revision.
        try repo.database!.transaction { sql in
            let id=UUID().uuidString.lowercased(), instant=CoreClockFrame.capture(now,zone:TimeZone(identifier:"Etc/UTC")!).instant
            try sql.execute("INSERT INTO plant_drafts VALUES(?,1,'edit',?,?,?, ?,?)",[.text(id),.text(plant),.integer(plantRevision),.text("retained test draft"),.text(instant),.text(instant)])
            try sql.execute("UPDATE metadata SET storage_revision=storage_revision+1")
        }
        assertCode("PREVIEW_STALE") { try call("commit",["plan":.object(p)]) }
        XCTAssertEqual(try allRows("plants").count,1); XCTAssertEqual(try allRows("plant_drafts").count,1)
    }

    func insertArchivedFixturePlant() throws -> String {
        let id=UUID().uuidString.lowercased(), instant=CoreClockFrame.capture(now,zone:TimeZone(identifier:"Etc/UTC")!).instant
        try repo.database!.transaction { sql in
            try sql.execute("INSERT INTO plants VALUES(?,1,'Other synthetic plant','','','Synthetic','unknown','unknown',1,?,?)",[.text(id),.text(instant),.text(instant)])
            try sql.execute("UPDATE metadata SET collection_revision=collection_revision+1,storage_revision=storage_revision+1")
        }
        return id
    }
    func deleteEmptyPlant(_ plant: String) throws {
        let command=UUID().uuidString.lowercased(), payload: [String:CanonicalValue] = ["plantId":.string(plant),"plantRevision":.integer(1)]
        let hash=try CanonicalCommand.commandHash(type:"DeletePlant",payload:payload), meta=try CoreSchema.object(call("metadata")), revision=try CoreSchema.number(meta["collectionRevision"])
        try call("freeze",["intent":.object(["commandId":.string(command),"datasetId":.string(dataset),"commandType":.string("DeletePlant"),"normalisedPayload":.object(payload),"payloadHash":.string(hash),"allocatedIds":.array([])])])
        var p=try CoreSchema.object(steps[25]["plan"])
        p["sessionId"] = .string(session); p["datasetId"] = .string(dataset); p["commandId"] = .string(command); p["normalisedPayload"] = .object(payload); p["payloadHash"] = .string(hash); p["expectedCollectionRevision"] = .integer(revision)
        let row=try XCTUnwrap(allRows("plants").first { $0[0] == .text(plant) })
        p["statements"] = .array([.object(["key":.string("plants.deleteTree"),"beforeHash":.string(try CoreSchema.rowHash(row)),"values":.array([.string(plant),.integer(1),.integer(0),.integer(0),.integer(0),.integer(0),.array([]),.integer(0),.integer(0),.integer(0)])])])
        p["result"] = .object(["commandId":.string(command),"datasetId":.string(dataset),"collectionRevision":.integer(revision+1),"primaryId":.string(plant),"primaryType":.string("plant"),"replayed":.boolean(false),"resourceIds":.array([.string(plant)]),"newRevisions":.object([:]),"notices":.array([])])
        p=try preview(rehash(p)); try call("commit",["plan":.object(p)])
    }
    func testDeletingUnrelatedPlantPreservesOriginalUndoDeadline() throws {
        for index in 0...4 { try execute(index) }
        let other=try insertArchivedFixturePlant()
        try deleteEmptyPlant(other)
        var undo=try plan(5), result=try CoreSchema.object(undo["result"])
        let revision=try CoreSchema.number(CoreSchema.object(call("metadata"))["collectionRevision"])
        undo["expectedCollectionRevision"] = .integer(revision); result["collectionRevision"] = .integer(revision+1); undo["result"] = .object(result)
        ticks += 7.999
        try call("commit",["plan":.object(rehash(undo))])
        XCTAssertEqual(try allRows("event_corrections").count,1)
        XCTAssertEqual(try allRows("plants").count,1)
    }
    func testNativeActiveLimitAndWrongRowScopeCannotBeBypassed() throws {
        try execute(0)
        for _ in 0..<5 { _ = try insertArchivedFixturePlant() }
        try repo.database!.transaction { try $0.execute("UPDATE plants SET archived=0") }
        var p=try plan(1), result=try CoreSchema.object(p["result"])
        let revision=try CoreSchema.number(CoreSchema.object(call("metadata"))["collectionRevision"])
        p["expectedCollectionRevision"] = .integer(revision); result["collectionRevision"] = .integer(revision+1); p["result"] = .object(result); p=try rehash(p)
        assertCode("ACTIVE_LIMIT") { _ = try preview(p) }
        XCTAssertEqual(try allRows("plants").count,5); XCTAssertEqual(try allRows("plant_drafts").count,1)
        var forged=p; forged["changeKind"] = .string("draft"); forged=try rehash(forged)
        assertCode("PLAN_INVALID") { _ = try preview(forged) }
    }

}
