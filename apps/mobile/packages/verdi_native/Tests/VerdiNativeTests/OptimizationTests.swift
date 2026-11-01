import Foundation
import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import SQLite3
@testable import VerdiNative

extension CoreRepositoryTests {
    func optimizationImage(width:Int=2400,height:Int=1600,alpha:Bool=false,orientation:Int=1) throws -> Data {
        let c=try XCTUnwrap(CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:alpha ? CGImageAlphaInfo.premultipliedLast.rawValue:CGImageAlphaInfo.noneSkipLast.rawValue))
        c.setFillColor(CGColor(red:0.2,green:0.7,blue:0.1,alpha:alpha ? 0.5:1));c.fill(CGRect(x:0,y:0,width:width,height:height))
        let data=NSMutableData(),out=try XCTUnwrap(CGImageDestinationCreateWithData(data,(alpha ? UTType.png:UTType.jpeg).identifier as CFString,1,nil))
        CGImageDestinationAddImage(out,try XCTUnwrap(c.makeImage()),[kCGImagePropertyOrientation:orientation,kCGImagePropertyExifDictionary:[kCGImagePropertyExifUserComment:"private source comment"]] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(out));return data as Data
    }
    func optimizedFixture(alpha:Bool=false) throws -> String {
        let (id,_)=try seedSavedPhoto(),files=try XCTUnwrap(repo.mediaFiles)
        let staging="staging/optimization-fixture";try files.writeGeneratedImage(optimizationImage(alpha:alpha),to:staging)
        let info=try files.inspect(staging),path="media/\(id)/\(info.hash).\(info.ext)";try files.publish(staging,to:path)
        try repo.queue.sync {try repo.database!.transaction{sql in
            try sql.execute("UPDATE photos SET content_path=?,sha256=?,byte_count=?,mime=?,width=?,height=? WHERE id=?",[.text(path),.text(info.hash),.integer(info.bytes),.text(info.mime),.integer(info.width),.integer(info.height),.text(id)])
            try repo.registerMediaPath(sql,path)
        }}
        return id
    }
    func optimizationPreview(_ id:String,revision:Int64=1) throws -> [String:CanonicalValue] {
        let plant=try CoreSchema.text(allRows("plants").first![0])
        return try CoreSchema.object(call("previewOptimization",["datasetId":.string(dataset),"plantId":.string(plant),"targets":.array([.object(["photoId":.string(id),"photoRevision":.integer(revision)])]),"longEdge":.integer(1280),"jpegQualityPercent":.integer(85)]))
    }
    func optimizationStart(_ photo:String) throws -> [String:CanonicalValue] {
        let preview=try optimizationPreview(photo)
        return try CoreSchema.object(call("startOptimization",["datasetId":.string(dataset),"jobId":.string(UUID().uuidString.lowercased()),"previewToken":preview["previewToken"]!]))
    }
    /// Preparation-boundary fixture only: saved-content compiled plans are
    /// exercised by the actual Flutter/native integration, not this seeded row.
    func optimizationAcknowledgedDraft(_ job:[String:CanonicalValue]) throws -> [String:CanonicalValue] {
        let target=try CoreSchema.object(CoreSchema.array(job["results"])[0]),draft=try CoreSchema.string(target["draftId"]),command=try CoreSchema.string(target["draftCommandId"])
        try repo.queue.sync {try repo.database!.transaction{sql in
            try sql.execute("INSERT INTO media_drafts VALUES(?,1,?,?,?,'[]',?,?)",[.text(draft),try CoreSchema.scalar(job["plantId"]!),try CoreSchema.scalar(target["photoId"]!),try CoreSchema.scalar(target["photoRevision"]!),.text(repo.mediaClock()),.text(repo.mediaClock())])
            try sql.execute("INSERT INTO intents VALUES(?,'SaveMediaDraft',?,NULL,'committed')",[.text(command),.text(String(repeating:"a",count:64))])
            try sql.execute("INSERT INTO receipts VALUES(?,?,'{}',NULL,0)",[.text(command),.text(String(repeating:"a",count:64))])
        }}
        return target
    }
    func testOptimizationRendererBoundsOrientationNoUpscaleAlphaAndOriginal() throws {
        let files=try XCTUnwrap(repo.mediaFiles)
        for (index,size) in [(2400,1600),(64,32)].enumerated() {
            let source="staging/source\(index)",bytes=try optimizationImage(width:size.0,height:size.1,orientation:6)
            try files.writeGeneratedImage(bytes,to:source);let info=try files.inspect(source)
            let result=try PhotoOptimizer.render(files,source,expectedHash:info.hash),decoded=try XCTUnwrap(CGImageSourceCreateWithData(result as CFData,nil)),props=try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(decoded,0,nil) as? [CFString:Any])
            XCTAssertEqual((props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,min(1280,size.0))
            XCTAssertLessThanOrEqual((props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0,size.1)
            XCTAssertNil((props[kCGImagePropertyExifDictionary] as? [CFString:Any])?[kCGImagePropertyExifUserComment])
            XCTAssertEqual(try Data(contentsOf:directory.appendingPathComponent(source)),bytes)
        }
        try files.writeGeneratedImage(optimizationImage(alpha:true),to:"staging/alpha")
        assertCode("MEDIA_UNSUPPORTED"){_=try PhotoOptimizer.render(files,"staging/alpha",expectedHash:files.inspect("staging/alpha").hash)}
        assertCode("MEDIA_INVALID"){_=try PhotoOptimizer.render(files,"staging/source0",expectedHash:String(repeating:"0",count:64))}
    }
    func testOptimizationConfirmationReplayCancellationAndRestartDoNotReplace() throws {
        let photo=try optimizedFixture(),before=try allRows("photos"),preview=try optimizationPreview(photo),id=UUID().uuidString.lowercased()
        let args:[String:CanonicalValue]=["datasetId":.string(dataset),"jobId":.string(id),"previewToken":preview["previewToken"]!]
        let first=try call("startOptimization",args)
        let policy=try repo.queue.sync{try repo.database!.read{try CanonicalParser.parse(CoreSchema.text($0.query("SELECT targets_json FROM optimization_jobs WHERE id=?",[.text(id)])[0][0]))}}
        XCTAssertEqual(policy.object?["jpegQualityPercent"]?.integer,85);XCTAssertEqual(policy.object?["longEdge"]?.integer,1280)

        XCTAssertEqual(try call("startOptimization",args).json(),try first.json())
        var changed=args;changed["previewToken"] = .string(UUID().uuidString.lowercased())
        assertCode("COMMAND_ID_REUSED"){_=try call("startOptimization",changed)}
        let cancelled=try call("stopOptimization",["jobId":.string(id),"reason":.string("cancelled")])
        XCTAssertEqual(cancelled.object?["state"]?.text,"cancelled")
        XCTAssertEqual(cancelled.object?["results"]?.array?[0].object?["state"]?.text,"not_attempted")
        XCTAssertEqual(try call("stopOptimization",["jobId":.string(id),"reason":.string("interrupted")]).json(),try cancelled.json())
        XCTAssertEqual(try allRows("photos"),before)
        let second=try optimizationStart(photo),secondID=try CoreSchema.string(second["jobId"])
        XCTAssertFalse(repo.platformLeases.isEmpty)
        try open()
        XCTAssertEqual(try call("getOptimizationJob",["jobId":.string(secondID)]).object?["state"]?.text,"interrupted")
        XCTAssertTrue(repo.platformLeases.isEmpty);XCTAssertEqual(try allRows("photos"),before)
    }
    func testOptimizationPreparationPreservesFutureDateProvenanceAndOriginal() throws {
        let photo=try optimizedFixture()
        try repo.queue.sync{try repo.database!.transaction{try $0.execute("UPDATE photos SET observed_date='2030-01-01' WHERE id=?",[.text(photo)])}}
        let before=try allRows("photos")[0],job=try optimizationStart(photo),target=try optimizationAcknowledgedDraft(job),id=try CoreSchema.string(job["jobId"])
        let args:[String:CanonicalValue]=["jobId":.string(id),"photoId":.string(photo)]
        XCTAssertEqual(try call("prepareOptimizationPhoto",args).object?["kind"]?.text,"copying")
        repo.mediaWorker.sync{}
        let result=try call("photoPreparation",["preparationId":target["preparationId"]!])
        XCTAssertEqual(result.object?["kind"]?.text,"ready")
        let row=try XCTUnwrap(result.object?["photo"]?.array)
        XCTAssertEqual(row[10].text,"2030-01-01");XCTAssertEqual(row[12].text,try CoreSchema.text(before[5]))
        XCTAssertEqual(row[7].text,"image/jpeg");XCTAssertLessThanOrEqual(row[8].integer ?? 0,1280)
        XCTAssertEqual(try allRows("photos").first{$0[0] == .text(photo)},before)
        XCTAssertTrue(FileManager.default.fileExists(atPath:directory.appendingPathComponent(try CoreSchema.text(before[4])).path))
        assertCode("RECOVERY_REQUIRED"){_=try call("finishOptimizationTarget",["jobId":.string(id),"photoId":.string(photo),"code":.null])}
        try open()
        XCTAssertEqual(try call("getOptimizationJob",["jobId":.string(id)]).object?["state"]?.text,"interrupted")
        XCTAssertEqual(try allRows("media_drafts").count,1)
        XCTAssertEqual(try allRows("photos").count,2)
    }
    func testOptimizationFileFailuresRetainOriginalAndAcknowledgedDraft() throws {
        for boundary:MediaFileBoundary in [.create,.write,.flush,.publish,.parentFlush] {
            try tearDownWithError();try setUpWithError()
            let photo=try optimizedFixture(),before=try allRows("photos")[0],job=try optimizationStart(photo),target=try optimizationAcknowledgedDraft(job)
            repo.mediaWorker.sync{repo.mediaFiles=try! MediaFiles(root:directory,fault:{at in if at==boundary{throw CoreRepositoryError("IO_FAILURE")}})}
            try call("prepareOptimizationPhoto",["jobId":job["jobId"]!,"photoId":.string(photo)])
            repo.mediaWorker.sync{}
            XCTAssertEqual(try call("photoPreparation",["preparationId":target["preparationId"]!]).object?["kind"]?.text,"failed")
            XCTAssertEqual(try allRows("photos"),[before]);XCTAssertEqual(try allRows("media_drafts").count,1)
            XCTAssertEqual(try MediaFiles(root:directory).inspect(CoreSchema.text(before[4])).hash,try CoreSchema.text(before[5]))
            let result=try call("finishOptimizationTarget",["jobId":job["jobId"]!,"photoId":.string(photo),"code":.string("IO_FAILURE")])
            XCTAssertEqual(result.object?["state"]?.text,"complete");XCTAssertEqual(result.object?["results"]?.array?[0].object?["state"]?.text,"failed")
        }
    }
    func testOptimizationReservedIDsCannotBeTakenByOrdinaryPaths() throws {
        let photo=try optimizedFixture(),job=try optimizationStart(photo),target=try CoreSchema.object(CoreSchema.array(job["results"])[0])
        let payload:[String:CanonicalValue]=["draftId":target["draftId"]!,"expectedRevision":.null,"plantId":job["plantId"]!,"photoId":target["photoId"]!,"basePhotoRevision":target["photoRevision"]!,"readyPhotoIds":.array([])]
        assertCode("COMMAND_ID_REUSED"){try repo.queue.sync{try repo.database!.read{try repo.guardOptimizationCommand($0,id:UUID().uuidString.lowercased(),type:"SaveMediaDraft",payload:payload)}}}
        assertCode("COMMAND_ID_REUSED"){try repo.queue.sync{try repo.database!.read{try repo.guardOrdinaryPreparation($0,CoreSchema.string(target["draftId"]),CoreSchema.string(target["preparationId"]))}}}
        try repo.queue.sync{try repo.database!.read{try repo.guardOptimizationCommand($0,id:CoreSchema.string(target["draftCommandId"]),type:"SaveMediaDraft",payload:payload)}}
        try call("stopOptimization",["jobId":job["jobId"]!,"reason":.string("cancelled")])
        assertCode("NOT_ELIGIBLE"){try repo.queue.sync{try repo.database!.read{try repo.guardOptimizationCommand($0,id:CoreSchema.string(target["draftCommandId"]),type:"SaveMediaDraft",payload:payload)}}}
        assertCode("COMMAND_ID_REUSED"){try repo.queue.sync{try repo.database!.read{try repo.guardOptimizationCommand($0,id:UUID().uuidString.lowercased(),type:"SaveMediaDraft",payload:payload)}}}
    }
    func testOptimizationCrossKindFreezeAndCancelledDraftIdentityReuseReject() throws {
        let photo=try optimizedFixture(),job=try optimizationStart(photo),target=try CoreSchema.object(CoreSchema.array(job["results"])[0])
        func ordinaryFreeze(_ draft:CanonicalValue,revision:CanonicalValue = .null) throws {
            var intent=try CoreSchema.object(steps[0]["intent"]),payload=try CoreSchema.object(intent["normalisedPayload"])
            payload["draftId"]=draft;payload["expectedRevision"]=revision;intent["normalisedPayload"] = .object(payload)
            intent["commandId"] = .string(UUID().uuidString.lowercased());intent["datasetId"] = .string(dataset)
            intent["payloadHash"] = .string(try CanonicalCommand.commandHash(type:"SaveDraft",payload:payload))
            try call("freeze",["intent":.object(intent)])
        }
        for id in [job["jobId"]!,target["draftId"]!,target["preparationId"]!,target["draftCommandId"]!,target["replaceCommandId"]!] {assertCode("COMMAND_ID_REUSED"){try ordinaryFreeze(id)};assertCode("COMMAND_ID_REUSED"){try ordinaryFreeze(id,revision:.integer(1))}}
        try call("stopOptimization",["jobId":job["jobId"]!,"reason":.string("cancelled")])
        assertCode("COMMAND_ID_REUSED"){try ordinaryFreeze(target["draftId"]!)}
    }
    func testOptimizationPreviewBoundsAndUnknownStartReceiptRecovery() throws {
        let photo=try optimizedFixture(),plant=try CoreSchema.text(allRows("plants")[0][0])
        let target:CanonicalValue = .object(["photoId":.string(photo),"photoRevision":.integer(1)])
        var request:[String:CanonicalValue]=["datasetId":.string(dataset),"plantId":.string(plant),"targets":.array([]),"longEdge":.integer(1280),"jpegQualityPercent":.integer(85)]
        assertCode("FIELD_INVALID"){_=try call("previewOptimization",request)}
        request["targets"] = .array([target,target]);assertCode("FIELD_INVALID"){_=try call("previewOptimization",request)}
        request["targets"] = .array(Array(repeating:target,count:201));assertCode("FIELD_INVALID"){_=try call("previewOptimization",request)}
        request["targets"] = .array([target]);request["jpegQualityPercent"] = .integer(84);assertCode("FIELD_INVALID"){_=try call("previewOptimization",request)}
        var targets:[CanonicalValue]=[target]
        try repo.queue.sync{try repo.database!.transaction{sql in
            let source=try CoreRegistry.requiredRow(sql,"photos",photo)
            for _ in 1..<200 {
                let id=UUID().uuidString.lowercased();var row=source;row[0] = .text(id);row[4] = .text("media/\(id)/\(try CoreSchema.text(source[5])).jpg")
                try sql.execute("INSERT INTO photos VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",row)
                targets.append(.object(["photoId":.string(id),"photoRevision":.integer(1)]))
            }
        }}
        request["targets"] = .array(targets);request["jpegQualityPercent"] = .integer(85)
        let maximumPreview=try call("previewOptimization",request),maximumID=UUID().uuidString.lowercased()
        let maximum=try call("startOptimization",["datasetId":.string(dataset),"jobId":.string(maximumID),"previewToken":maximumPreview.object!["previewToken"]!])
        XCTAssertEqual(maximum.object?["results"]?.array?.count,200)
        let identities=try CoreSchema.array(maximum.object?["results"]).flatMap{value in ["draftId","draftCommandId","preparationId","replaceCommandId"].map{value.object![$0]!.text!}}
        XCTAssertEqual(Set(identities).count,800)
        try call("stopOptimization",["jobId":.string(maximumID),"reason":.string("cancelled")])
        let preview=try optimizationPreview(photo),job=UUID().uuidString.lowercased(),before=try allRows("photos")
        failure = .afterCommit
        assertCode("UNKNOWN_OUTCOME"){_=try call("startOptimization",["datasetId":.string(dataset),"jobId":.string(job),"previewToken":preview["previewToken"]!])}
        try open()
        let status=try call("getOptimizationJob",["jobId":.string(job)])
        XCTAssertEqual(status.object?["state"]?.text,"interrupted")
        XCTAssertEqual(status.object?["results"]?.array?[0].object?["state"]?.text,"not_attempted")
        XCTAssertEqual(try allRows("photos"),before);XCTAssertTrue(try allRows("media_drafts").isEmpty)
    }
    func testOptimizationV5MigrationPreservesAllExistingRows() throws {
        _ = try optimizedFixture();_ = try call("close")
        let file=directory.appendingPathComponent("core.sqlite");var raw:OpaquePointer?
        XCTAssertEqual(sqlite3_open(file.path,&raw),SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw,"DROP TABLE optimization_targets; DROP TABLE optimization_jobs; PRAGMA user_version=5;",nil,nil,nil),SQLITE_OK);sqlite3_close(raw)
        let old=try SQLiteDatabase.open(at:file,schema:CoreSchema.schema(version:5))
        let names=try old.read{try $0.query("SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'").map{try CoreSchema.text($0[0])}}
        let before=try old.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}};try old.close()
        try open()
        XCTAssertEqual(try repo.queue.sync{try repo.database!.read{sql in try names.map{try sql.query("SELECT * FROM \($0) ORDER BY 1")}}},before)
    }
}

#if os(macOS)
extension CoreRepositoryTests {
    func testOptimizationUpgradeVerifiesOldSwitchedBytesBeforeMigration() throws {
        for version:Int32 in [4,5] {
            try tearDownWithError();try setUpWithError()
            let fixture=try recoveryFixture(),old=dataset
            try crashRestore(fixture.zip,boundary:"switched")
            var fail=true
            let control=try BackupControl(legacy:directory,transactionFault:{boundary,point in
                if fail && (boundary == .verify || boundary == .rollback) && point == .beforeCommit {throw StorageFailure.unavailable}
            })
            let id=try control.activeID(),root=try control.generationURL(id),file=root.appendingPathComponent("core.sqlite")
            var raw:OpaquePointer?;XCTAssertEqual(sqlite3_open(file.path,&raw),SQLITE_OK)
            let downgrade=version==4 ? legacyRoutinesDDL():"DROP TABLE optimization_targets; DROP TABLE optimization_jobs;"
            XCTAssertEqual(sqlite3_exec(raw,"PRAGMA foreign_keys=OFF; BEGIN; \(downgrade) PRAGMA user_version=\(version); COMMIT; PRAGMA wal_checkpoint(TRUNCATE);",nil,nil,nil),SQLITE_OK);sqlite3_close(raw)
            let exact=try SQLiteDatabase.open(at:file,schema:CoreSchema.schema(version:version));try exact.close()
            let bytes=try Data(contentsOf:file),hash=try BackupIO.hash(file).0
            try control.db.transaction{try $0.execute("UPDATE replacement SET db_hash=?",[.text(hash)])}
            for _ in 0..<2 {
                XCTAssertThrowsError(try control.recover(at:mediaInstant()))
                XCTAssertEqual(try Data(contentsOf:file),bytes)
                XCTAssertEqual(try control.db.read{try $0.query("SELECT phase FROM replacement")[0][0]},.text("switched"))
            }
            fail=false;try control.recover(at:mediaInstant())
            XCTAssertEqual(try Data(contentsOf:file),bytes)
            XCTAssertEqual(try control.db.read{try $0.query("SELECT phase FROM replacement")[0][0]},.text("verified"))
            try control.db.close();try open()
            XCTAssertNotEqual(dataset,old);XCTAssertEqual(try allRows("plants"),fixture.newRows)
            XCTAssertEqual(try Data(contentsOf:repo.directory.appendingPathComponent(fixture.newPath)),fixture.newBytes)
            try closeRecoveryFixture()
            let migrated=try SQLiteDatabase.open(at:file,schema:CoreSchema.schema(version:6));try migrated.close()
            removeBackupSidecars()
        }
    }
}
#endif
