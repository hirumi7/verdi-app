import Foundation
import XCTest
import ZIPFoundation
@testable import VerdiNative

extension CoreRepositoryTests {
    func backup(_ method:String,_ args:[String:CanonicalValue]=[:]) throws -> CanonicalValue {
        try CanonicalParser.parse(repo.backupCall(method:method,request:CanonicalValue.object(args).json()))
    }
    func awaitBackup(_ id:String,terminal:Set<String>=["file_created","preview_ready","complete","failed","cancelled"]) throws -> CanonicalValue {
        for _ in 0..<1000 {
            let op=try backup("backupStatus",["operationId":.string(id)])
            if let kind=op.object?["operation"]?.object?["state"]?.object?["kind"]?.text,terminal.contains(kind) {repo.backupEngine.worker.sync{};return op}
            Thread.sleep(forTimeInterval:0.01)
        }
        throw CoreRepositoryError("TEST_TIMEOUT")
    }
    func exportBackup() throws -> (String,URL) {
        let id=UUID().uuidString.lowercased()
        _=try backup("startExport",["operationId":.string(id),"datasetId":.string(dataset)])
        let result=try awaitBackup(id)
        XCTAssertEqual(result.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"file_created",String(describing:result))
        guard result.object?["operation"]?.object?["state"]?.object?["kind"]?.text=="file_created" else {throw CoreRepositoryError("TEST_EXPORT_FAILED")}
        return (id,try repo.backupControl!.jobRoot(id).appendingPathComponent("Verdi-backup.zip"))
    }
    func previewBackup(_ url:URL) throws -> (String,CanonicalValue) {
        let handle=try repo.retainBackupSelection(source:url),id=UUID().uuidString.lowercased()
        _=try backup("startImport",["operationId":.string(id),"selectionHandle":.string(handle)])
        let result=try awaitBackup(id)
        XCTAssertEqual(result.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"preview_ready",String(describing:result))
        return (id,try XCTUnwrap(result.object?["operation"]?.object?["state"]?.object?["preview"]))
    }
    func removeBackupSidecars() {
        // Test teardown must not unlink SQLite files while workers/handles own them.
        if let repo {
            repo.backupEngine.worker.sync{}
            repo.mediaWorker.sync{}
            repo.queue.sync {
                try? repo.database?.close();repo.database=nil
                try? repo.backupControl?.db.close();repo.backupControl=nil
            }
        }
        for suffix in ["-recovery","-generations"] {try? FileManager.default.removeItem(at:URL(fileURLWithPath:directory.path+suffix))}
    }
    func testBackupRoundTripRetainsCareAuditsAndNewDataset() throws {
        defer{removeBackupSidecars()}
        for i in 0..<19 {try execute(i)}
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))})
        let oldDataset=dataset
        let (_,zip)=try exportBackup()
        let (id,preview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        let result=try awaitBackup(id,terminal:["complete","failed","cancelled"])
        XCTAssertEqual(result.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete",String(describing:result))
        try open();XCTAssertNotEqual(dataset,oldDataset)
        for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
        XCTAssertEqual(try call("pending").object?["items"]?.array?.count,0)
        XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent("core.sqlite").path))
        try open();for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table])}
    }
    func testBackupPhotoDraftRoundTripAndCancellation() throws {
        defer{removeBackupSidecars()}
        try execute(0)
        let draft=try CoreSchema.string(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["draftId"])
        let source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog")),selection=try repo.retainMediaSelection(source:source,kind:"library"),prep=UUID().uuidString.lowercased()
        _=try call("preparePhoto",["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(prep),"selectionId":.string(selection),"observedDate":.string("2026-10-20")])
        for _ in 0..<500 {if try call("photoPreparation",["preparationId":.string(prep)]).object?["kind"]?.text != "copying" {break};Thread.sleep(forTimeInterval:0.01)}
        let photos=try allRows("photos"),drafts=try allRows("plant_drafts"),old=dataset
        let (_,zip)=try exportBackup(),(cancelID,_)=try previewBackup(zip)
        _=try backup("cancelBackup",["operationId":.string(cancelID)])
        XCTAssertEqual(try allRows("photos"),photos);XCTAssertEqual(dataset,old)
        let (id,preview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed","cancelled"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertEqual(try allRows("photos"),photos);XCTAssertEqual(try allRows("plant_drafts"),drafts)
        XCTAssertEqual(try Data(contentsOf:repo.directory.appendingPathComponent(CoreSchema.text(photos[0][4]))),try Data(contentsOf:source))
    }
    func testBackupPendingIntentAfterPreviewRefusesSwitch() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (_,zip)=try exportBackup(),(id,preview)=try previewBackup(zip),old=dataset
        _=try plan(2) // durable pending freeze, without a content revision change
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        let result=try awaitBackup(id)
        XCTAssertEqual(result.object?["operation"]?.object?["state"]?.object?["code"]?.text,"BUSY")
        try open();XCTAssertEqual(dataset,old)
        XCTAssertEqual(try call("pending").object?["items"]?.array?.count,1)
    }
    func testBackupLargeRawDraftRoundTrip() throws {
        defer{removeBackupSidecars()}
        var fields=try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["rawFields"])
        fields["notes"] = .string(String(repeating:"\\",count:510000));fields["name"] = .utf16([0xd800,0])
        let p=try draftPlan(fields:fields,draftID:UUID().uuidString.lowercased(),expected:nil)
        _=try call("commit",["plan":.object(p)])
        let before=try allRows("plant_drafts")
        let (_,zip)=try exportBackup(),(id,preview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        let result=try awaitBackup(id,terminal:["complete","failed"])
        XCTAssertEqual(result.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete",String(describing:result))
        try open();XCTAssertEqual(try allRows("plant_drafts"),before)
    }
    func testBackupBoundaryFailuresAndIdempotentConfirmation() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (_,zip)=try exportBackup()
        for boundary:BackupBoundary in [.staged,.prepared,.switched,.verified] {
            let old=dataset,id=UUID().uuidString.lowercased(),selection=try repo.retainBackupSelection(source:zip)
            var fired=false
            repo.backupFault={point in if point==boundary && !fired {fired=true;throw CoreRepositoryError("IO_FAILURE")}}
            // Existing control captures a fault closure at initialization; route it
            // through a new owner, as a fresh process would.
            try repo.backupControl!.db.close();repo.backupControl=nil
            _=try backup("startImport",["operationId":.string(id),"selectionHandle":.string(selection)])
            var result=try awaitBackup(id)
            if boundary != .staged {
                let preview=try XCTUnwrap(result.object?["operation"]?.object?["state"]?.object?["preview"])
                _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
                result=try awaitBackup(id,terminal:["complete","failed"])
            }
            XCTAssertTrue(fired)
            repo.backupFault=nil
            try open()
            if boundary == .prepared || boundary == .staged {XCTAssertEqual(dataset,old)} else {XCTAssertNotEqual(dataset,old)}
            XCTAssertEqual(try allRows("plants").count,1)
            if result.object?["operation"]?.object?["state"]?.object?["kind"]?.text == "complete" {
                let replay=try backup("confirmImport",["operationId":.string(id),"preview":.null,"confirmed":.boolean(true)])
                XCTAssertEqual(replay.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
            }
        }
    }
    func testBackupMissingEstablishedControlFailsClosed() throws {
        defer{removeBackupSidecars()}
        try execute(0)
        _=try backup("latestBackupOperation")
        try open();XCTAssertEqual(try allRows("plant_drafts").count,1)
        // Missing an established control database must never reset to legacy.
        try repo.backupControl!.db.close();repo.backupControl=nil
        try FileManager.default.removeItem(at:BackupControl.location(directory).appendingPathComponent("control.sqlite"))
        assertCode("STORAGE_UNAVAILABLE"){try open()}
        XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent("core.sqlite").path))
    }
}

final class BackupParserTests:XCTestCase {
    var root:URL!
    override func setUpWithError() throws {root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);try BackupIO.directory(root)}
    override func tearDownWithError() throws {try? FileManager.default.removeItem(at:root)}
    func reader(_ text:String) throws -> BackupJSONReader {let file=root.appendingPathComponent(UUID().uuidString);try Data(text.utf8).write(to:file);return try BackupJSONReader(file,limit:1024*1024)}
    func testStreamedDuplicateKeysAndMalformedLiteralRefused() throws {
        for text in ["{\"a\":1,\"a\":2}","{\"a\":n u l l}","{\"a\":01}","{\"a\":1e2}","{\"a\":true,}"] {
            let r=try reader(text)
            XCTAssertThrowsError(try r.object {_ in _=try r.value()},text)
        }
    }
    func testRawUTF16IsLosslessAndTrailingInputRefused() throws {
        let r=try reader("{\"a\":[\"\\ud800\\u0000\"]} trailing")
        var units:[UInt16]?
        try r.object{_ in units=try r.value().array?[0].units}
        XCTAssertEqual(units,[0xd800,0]);XCTAssertThrowsError(try r.end())
    }
    func testStoredAndDeflateArchiveAndTraversalRejection() throws {
        for compression in [CompressionMethod.none,.deflate] {
            let id=UUID().uuidString,zip=root.appendingPathComponent(id+".zip"),out=root.appendingPathComponent(id)
            do {
                let archive=try Archive(url:zip,accessMode:.create)
                for name in ["manifest.json","data.json"] {
                    let bytes=Data("{}".utf8)
                    try archive.addEntry(with:name,type:.file,uncompressedSize:Int64(bytes.count),compressionMethod:compression) {offset,count in bytes.subdata(in:Int(offset)..<Int(offset)+count)}
                }
            }
            try BackupIO.directory(out)
            let index=try BackupIndex(root.appendingPathComponent(id+".sqlite"))
            try BackupArchive.extract(zip,to:out,index:index,cancel:{})
            XCTAssertEqual(try String(contentsOf:out.appendingPathComponent("data.json")),"{}")
        }
        let zip=root.appendingPathComponent("evil.zip")
        do {let a=try Archive(url:zip,accessMode:.create);for name in ["../data.json","manifest.json"] {try a.addEntry(with:name,type:.file,uncompressedSize:Int64(2)){_,_ in Data("{}".utf8)}}}
        let index=try BackupIndex(root.appendingPathComponent("evil.sqlite"))
        XCTAssertThrowsError(try BackupZIPPreflight(zip,index:index,cancel:{}).validate())
    }
}
