import Foundation
import XCTest
import ZIPFoundation
@testable import VerdiNative

extension CoreRepositoryTests {
    func alteredBackup(_ zip:URL,_ mutate:(inout [String:CanonicalValue])throws->Void) throws -> URL {
        let root=directory.appendingPathComponent("fixture-"+UUID().uuidString);try BackupIO.directory(root)
        let original=try Archive(url:zip,accessMode:.read)
        for entry in original { _=try original.extract(entry,to:root.appendingPathComponent(entry.path)) }
        let dataURL=root.appendingPathComponent("data.json")
        var data=try CoreSchema.object(CanonicalParser.package(String(contentsOf:dataURL)))
        try mutate(&data);try Data(try CanonicalValue.object(data).json().utf8).write(to:dataURL)
        let manifestURL=root.appendingPathComponent("manifest.json")
        var manifest=try CoreSchema.object(CanonicalParser.package(String(contentsOf:manifestURL)))
        let hash=try BackupIO.hash(dataURL)
        manifest["data"] = .object(["path":.string("data.json"),"sha256":.string(hash.0),"bytes":.integer(hash.1)])
        try Data(try CanonicalValue.object(manifest).json().utf8).write(to:manifestURL)
        let output=root.appendingPathComponent("mutated.zip")
        do {let archive=try Archive(url:output,accessMode:.create);for entry in original {try archive.addEntry(with:entry.path,fileURL:root.appendingPathComponent(entry.path),compressionMethod:.deflate)}}
        return output
    }
    func testBackupMalformedRowsCannotReplaceCollection() throws {
        defer{removeBackupSidecars()}
        for i in 0..<19 {try execute(i)}
        // Keep a valid raw draft as well as audit snapshots in this synthetic set.
        let fields=try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["rawFields"])
        let draft=try draftPlan(fields:fields,draftID:UUID().uuidString.lowercased(),expected:nil)
        // draftPlan's baseline result must carry the current collection revision.
        var adjusted=draft;adjusted["expectedCollectionRevision"] = try call("metadata").object?["collectionRevision"]
        var result=adjusted["result"]!.object!;result["collectionRevision"]=adjusted["expectedCollectionRevision"];adjusted["result"] = .object(result)
        // Raw snapshot fixtures are allowed in this isolated import-validator test.
        try repo.queue.sync {try repo.database!.transaction {sql in
            let raw=try CanonicalValue.object(["version":.integer(1),"fields":.object(fields)]).json(),time=mediaInstant()
            try sql.execute("INSERT INTO plant_drafts VALUES(?,1,'add',NULL,NULL,?,?,?)",[.text(UUID().uuidString.lowercased()),.text(raw),.text(time),.text(time)])
            try sql.execute("UPDATE intents SET body=NULL,status='abandoned' WHERE status='pending'")
        }}
        let (_,zip)=try exportBackup(),old=dataset,before=try allRows("plants")
        let mutations:[(String,(inout [String:CanonicalValue])throws->Void)] = [
            ("future",{$0["schemaVersion"] = .integer(3)}),
            ("entitlement",{$0["isPro"] = .boolean(true)}),
            ("duplicate",{data in var t=data["tables"]!.object!,p=t["plants"]!.array!;p.append(p[0]);t["plants"] = .array(p);data["tables"] = .object(t)}),
            ("long-name",{data in try self.alterRow(&data,"plants",2,.string(String(repeating:"a",count:61)))}),
            ("invalid-date",{data in try self.alterRow(&data,"heads",3,.string("2026-02-30"))}),
            ("noncanonical-instant",{data in try self.alterRow(&data,"plants",9,.string("2026-10-20T00:00:00.123000Z"))}),
            ("missing-fields",{data in try self.alterRow(&data,"plant_drafts",5,.string("{\"other\":{},\"version\":1}"))}),
            ("missing-head",{data in var t=data["tables"]!.object!;t["heads"] = .array([]);data["tables"] = .object(t)}),
            ("null-audit-anchor",{data in var t=data["tables"]!.object!,rows=t["routine_changes"]!.array!,r=rows[0].array!,h=try CoreSchema.object(CanonicalParser.parse(CoreSchema.string(r[8])));h["anchor"] = .null;r[8] = .string(try CanonicalValue.object(h).json());rows[0] = .array(r);t["routine_changes"] = .array(rows);data["tables"] = .object(t)}),
        ]
        for (name,mutation) in mutations {
            let bad=try alteredBackup(zip,mutation),selection=try repo.retainBackupSelection(source:bad),id=UUID().uuidString.lowercased()
            _=try backup("startImport",["operationId":.string(id),"selectionHandle":.string(selection)])
            let rejected=try awaitBackup(id)
            XCTAssertEqual(rejected.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed",name)
            XCTAssertEqual(dataset,old);XCTAssertEqual(try allRows("plants"),before,name)
        }
    }
    func mediaInstant() -> String {CoreClockFrame.capture(now,zone:TimeZone(identifier:"Etc/UTC")!).instant}
    func alterRow(_ data:inout [String:CanonicalValue],_ table:String,_ column:Int,_ value:CanonicalValue) throws {
        var tables=data["tables"]!.object!,rows=tables[table]!.array!,row=rows[0].array!
        row[column]=value;rows[0] = .array(row);tables[table] = .array(rows);data["tables"] = .object(tables)
    }
    func testBackupFailedStateWriteCanRetryFromStatus() throws {
        defer{removeBackupSidecars()}
        try execute(0)
        var blocked=true
        repo.backupFault={if $0 == .snapshot {throw CoreRepositoryError("IO_FAILURE")}}
        repo.backupEngine.failureWriteFault={if blocked {throw StorageFailure.unavailable}}
        let id=UUID().uuidString.lowercased()
        _=try backup("startExport",["operationId":.string(id),"datasetId":.string(dataset)])
        repo.backupEngine.worker.sync {}
        XCTAssertThrowsError(try backup("backupStatus",["operationId":.string(id)]))
        blocked=false
        let recovered=try backup("backupStatus",["operationId":.string(id)])
        XCTAssertEqual(recovered.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        XCTAssertEqual(try allRows("plant_drafts").count,1)
    }
    func testBackupExpiryPreservesSharedOutputAndLiveGeneration() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (id,zip)=try exportBackup()
        let state=try backup("backupStatus",["operationId":.string(id)]).object!["operation"]!.object!["state"]!.object!
        _=try repo.backupShareURL(request:CanonicalValue.object(["operationId":.string(id),"exportHandle":state["exportHandle"]!]).json())
        let selection=try repo.retainBackupSelection(source:zip)
        now=now.addingTimeInterval(86401)
        try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(repo.backupControl!)}
        XCTAssertTrue(FileManager.default.fileExists(atPath:zip.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:try repo.backupControl!.artifactURL(kind:"selection",key:selection).path))
        try repo.finishBackupShare(operationID:id,result:"cancelled")
        try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(repo.backupControl!)}
        XCTAssertFalse(FileManager.default.fileExists(atPath:zip.path))
        try open();XCTAssertEqual(try allRows("plants").count,1)
    }
    func testBackupCleanupClaimBlocksConcurrentShare() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (id,zip)=try exportBackup()
        let state=try backup("backupStatus",["operationId":.string(id)]).object!["operation"]!.object!["state"]!.object!
        try repo.backupControl!.db.transaction {try $0.execute("UPDATE artifacts SET expires='1970-01-01T00:00:00.000Z' WHERE key=?",[.text(id)])}
        var reached=false
        repo.backupEngine.cleanupClaimed={key in
            if key==id {
                reached=true
                self.assertCode("BUSY") {_=try self.repo.backupShareURL(request:CanonicalValue.object(["operationId":.string(id),"exportHandle":state["exportHandle"]!]).json())}
            }
        }
        try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(repo.backupControl!)}
        repo.backupEngine.cleanupClaimed=nil
        XCTAssertTrue(reached);XCTAssertFalse(FileManager.default.fileExists(atPath:zip.path))
    }
    func testBackupTwoRolledBackCandidatesExpireWithoutTouchingLegacy() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (_,zip)=try exportBackup(),old=dataset
        var candidates=[URL]()
        for _ in 0..<2 {
            let (id,preview)=try previewBackup(zip)
            let generation=try repo.backupControl!.db.read {try CoreSchema.text($0.query("SELECT new_generation FROM jobs WHERE id=?",[.text(id)])[0][0])}
            candidates.append(repo.backupControl!.generations.appendingPathComponent(generation))
            repo.backupFault={if $0 == .prepared {throw CoreRepositoryError("IO_FAILURE")}}
            try repo.backupControl!.db.close();repo.backupControl=nil
            _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
            _=try awaitBackup(id,terminal:["failed"])
            repo.backupFault=nil;try open();XCTAssertEqual(dataset,old)
        }
        try repo.backupControl!.db.transaction {try $0.execute("UPDATE artifacts SET expires='1970-01-01T00:00:00.000Z' WHERE kind='staging'")}
        try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(repo.backupControl!)}
        for candidate in candidates {XCTAssertFalse(FileManager.default.fileExists(atPath:candidate.path))}
        try open();XCTAssertEqual(dataset,old);XCTAssertEqual(try allRows("plants").count,1)
    }
    func testBackupCloseFailureRequiresReopenAndRetainsCare() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (_,zip)=try exportBackup(),old=dataset,(id,preview)=try previewBackup(zip)
        failure = .close
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        let failed=try awaitBackup(id,terminal:["failed"])
        XCTAssertEqual(failed.object?["operation"]?.object?["state"]?.object?["recovery"]?.text,"open_recovery")
        try open();XCTAssertEqual(dataset,old);XCTAssertEqual(try allRows("plants").count,1)
        try execute(2);try execute(3)
    }

    func testBackupCatalogSnapshotsAndSettingsSurvive() throws {
        defer{removeBackupSidecars()}
        try useCatalogFixture()
        for i in 0..<4 {try execute(i)}
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))})
        let (_,zip)=try exportBackup(),(id,preview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
    }
    func testBackupSettingsOrDraftChangeInvalidatesPreview() throws {
        defer{removeBackupSidecars()}
        try execute(0)
        let (_,zip)=try exportBackup(),old=dataset
        for query in ["UPDATE plant_drafts SET revision=revision+1","UPDATE user_settings SET revision=revision+1"] {
            let (id,preview)=try previewBackup(zip)
            _=try repo.queue.sync {try repo.database!.transaction {try $0.execute(query)}}
            _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
            let failed=try awaitBackup(id,terminal:["failed"])
            XCTAssertEqual(failed.object?["operation"]?.object?["state"]?.object?["code"]?.text,"PREVIEW_STALE")
            XCTAssertEqual(dataset,old)
        }
    }
    func testBackupOriginalMissingLeavesExistingCollectionOpen() throws {
        defer{removeBackupSidecars()}
        try execute(0)
        let draft=try CoreSchema.text(allRows("plant_drafts")[0][0]),source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog")),selection=try repo.retainMediaSelection(source:source,kind:"library"),prep=UUID().uuidString.lowercased()
        _=try call("preparePhoto",["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(prep),"selectionId":.string(selection),"observedDate":.string("2026-10-20")])
        repo.mediaWorker.sync{}
        let path=try CoreSchema.text(allRows("photos")[0][4]),old=dataset
        try FileManager.default.removeItem(at:directory.appendingPathComponent(path))
        _=try backup("latestBackupOperation");try open();XCTAssertEqual(dataset,old)
        let id=UUID().uuidString.lowercased()
        _=try backup("startExport",["operationId":.string(id),"datasetId":.string(dataset)])
        XCTAssertEqual(try awaitBackup(id).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        try open();XCTAssertEqual(try allRows("photos").count,1);XCTAssertEqual(dataset,old)
    }

    func testBackupQueuedMediaCleanupRetainsRepository() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let entered=DispatchSemaphore(value:0),release=DispatchSemaphore(value:0)
        repo.mediaWorker.async {entered.signal();release.wait()}
        XCTAssertEqual(entered.wait(timeout:.now()+2),.success)
        defer{release.signal()}
        _=try exportBackup()
        weak var owner=repo
        repo=nil
        XCTAssertNotNil(owner)
        release.signal()
        for _ in 0..<100 where owner != nil {Thread.sleep(forTimeInterval:0.02)}
        XCTAssertNil(owner)
        repo=CoreRepository(directory:directory,fault:nil,now:{self.now})
        try open();XCTAssertEqual(try allRows("plants").count,1)
    }

}

extension BackupParserTests {
    func testCanonicalInstantsAndAuditHeadsRejectBeforeHydration() throws {
        XCTAssertNoThrow(try BackupContent.instantValue("2026-10-20T00:00:00.123Z"))
        XCTAssertNoThrow(try BackupContent.instantValue("2026-10-20T00:00:00.123001Z"))
        for value in ["2026-10-20T00:00:00.123000Z","2026-02-30T00:00:00.000Z","2026-10-20T25:00:00.000Z"] {XCTAssertThrowsError(try BackupContent.instantValue(value))}
        var h:[String:CanonicalValue] = ["version":.integer(1),"headId":.string(UUID().uuidString.lowercased()),"intervalCount":.integer(1),"intervalUnit":.string("month"),"anchor":.string("2026-01-31"),"firstCheckAnchor":.boolean(false),"firstCheckDate":.null,"nextCheck":.string("2026-02-28"),"overrideDate":.null,"status":.string("active"),"archived":.boolean(false)]
        XCTAssertNoThrow(try BackupContent.validateHead(.object(h)))
        h["anchor"] = .null;XCTAssertThrowsError(try BackupContent.validateHead(.object(h)));h["anchor"] = .string("2026-01-31")
        h["version"] = .integer(2);h["originalSuggestionId"] = .null;h["appliedSuggestionId"] = .null
        XCTAssertThrowsError(try BackupContent.validateHead(.object(h)))
    }
}
