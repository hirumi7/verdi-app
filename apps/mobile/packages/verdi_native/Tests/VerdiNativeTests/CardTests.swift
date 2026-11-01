import Foundation
import XCTest
import ImageIO
@testable import VerdiNative

extension CoreRepositoryTests {
    func cardRequest(kind:String="plant",choice:String="illustration",photos:[String]=[]) throws -> String {
        let p=try XCTUnwrap(allRows("plants").first)
        return try CanonicalValue.object(["datasetId":.string(dataset),"kind":.string(kind),"plantId":CoreSchema.canonical(p[0]),"plantRevision":CoreSchema.canonical(p[1]),"imageChoice":kind=="comparison" ? .null:.string(choice),"photos":.array(photos.map{.object(["id":.string($0),"revision":.integer(1)])})]).json()
    }
    func awaitCard<T>(_ work: (@escaping(Result<T,Error>)->Void)->Void) throws -> T {
        let done=expectation(description:"card worker");var result:Result<T,Error>?
        work{result=$0;done.fulfill()};wait(for:[done],timeout:20);return try XCTUnwrap(result).get()
    }
    func makeCard(_ request:String) throws -> [String:CanonicalValue] {
        try CoreSchema.object(CanonicalParser.parse(awaitCard{repo.prepareCard(request,completion:$0)}))
    }
    func testCardFreeIllustrationExactBytesExpiryAndContentPreservation() throws {
        try execute(0);try execute(1)
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))})
        let response=try makeCard(cardRequest()),token=try CoreSchema.string(response["token"])
        let bytes:Data=try awaitCard{repo.readCard(token,completion:$0)};try CardRenderer.validate(bytes)
        XCTAssertEqual(response["dates"]?.array?.count,0);XCTAssertEqual(response["width"]?.integer,1080)
        let prep:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(token,completion:$0)}
        let handoff=try repo.grantCardHandoff(prep)
        XCTAssertEqual(try Data(contentsOf:handoff.url),bytes)
        ticks+=601;repo.releaseCard(token);repo.mediaWorker.sync{}
        XCTAssertTrue(FileManager.default.fileExists(atPath:handoff.url.path))
        assertCode("CARD_EXPIRED"){_=try awaitCard{repo.readCard(token,completion:$0)}}
        try open();repo.mediaWorker.sync{} // Active OS owner survives reconnect and preview expiry.
        XCTAssertTrue(FileManager.default.fileExists(atPath:handoff.url.path))
        repo.releaseCardHandoff(handoff.leaseID);repo.mediaWorker.sync{}
        XCTAssertFalse(FileManager.default.fileExists(atPath:handoff.url.path))
        for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
    }
    func testCardCoverMissingStaleSourceAndFinalGrantRace() throws {
        let (photo,url)=try seedSavedPhoto()
        assertCode("MEDIA_MISSING"){_=try makeCard(cardRequest(choice:"cover"))}
        _ = try repo.queue.sync{try repo.database!.transaction{sql in try sql.execute("INSERT INTO plant_covers SELECT id,? FROM plants",[.text(photo)])}}
        let response=try makeCard(cardRequest(choice:"cover")),token=try CoreSchema.string(response["token"])
        let prep:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(token,completion:$0)}
        // Actual source file corruption after preflight must invalidate the grant.
        try Data("bad".utf8).write(to:url)
        assertCode("PREVIEW_STALE"){_=try repo.grantCardHandoff(prep)}
        XCTAssertTrue(repo.platformLeases.isEmpty)
        XCTAssertThrowsError(try makeCard(cardRequest(choice:"cover")))
    }
    func testCardPlantEditAndCapabilityChangeRequireFreshPreview() throws {
        let (photo,original)=try seedSavedPhoto()
        let other=UUID().uuidString.lowercased()
        let secondPath="media/\(other)/\(original.lastPathComponent)"
        try repo.mediaFiles!.importSelection(original,to:secondPath)
        try repo.queue.sync{try repo.database!.transaction{sql in
            try repo.registerMediaPath(sql,secondPath)
            try sql.execute("INSERT INTO photos SELECT ?,plant_id,draft_id,revision,?,sha256,byte_count,mime,width,height,'2026-10-19',source_kind,optimized_from_hash,created_at FROM photos WHERE id=?",[.text(other),.text(secondPath),.text(photo)])
        }}
        let request=try cardRequest(kind:"comparison",photos:[photo,other])
        assertCode("FIELD_INVALID"){_=try makeCard(cardRequest(kind:"comparison",photos:[photo,photo]))}
        assertCode("PRO_REQUIRED"){_=try makeCard(request)}
        let authority=StoreAuthority(configuration:storeTestConfig,installation:"cards",cache:TestStoreCache());repo.storeAuthority=authority;try authority.accept(storeEvidence(10))
        let response=try makeCard(request),token=try CoreSchema.string(response["token"])
        XCTAssertEqual(response["dates"]?.array?.compactMap(\.text),["2026-10-19","2026-10-20"])
        let prep:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(token,completion:$0)}
        try authority.accept(storeEvidence(20,revoked:true))
        assertCode("PRO_REQUIRED"){_=try repo.grantCardHandoff(prep)}
        try authority.accept(storeEvidence(30,original:"2"))
        assertCode("PREVIEW_STALE"){_=try repo.grantCardHandoff(prep)}
        let free=try makeCard(cardRequest()),freeToken=try CoreSchema.string(free["token"])
        let checked:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(freeToken,completion:$0)}
        _ = try repo.queue.sync{try repo.database!.transaction{try $0.execute("UPDATE plants SET revision=revision+1,name='Changed'")}}
        assertCode("PREVIEW_STALE"){_=try repo.grantCardHandoff(checked)}
    }
    func testCardLimitsReopenAndEveryWriteFailureCleanOnlyGeneratedFiles() throws {
        let (_,original)=try seedSavedPhoto(),before=try Data(contentsOf:original)
        for boundary in [MediaFileBoundary.create,.write,.flush,.publish,.parentFlush] {
            repo.mediaWorker.sync{repo.mediaFiles=try! MediaFiles(root:directory,fault:{if $0==boundary{throw CoreRepositoryError("IO_FAILURE")}})}
            XCTAssertThrowsError(try makeCard(cardRequest()))
            repo.mediaWorker.sync{repo.cleanupMedia()}
            XCTAssertEqual(try Data(contentsOf:original),before)
            XCTAssertTrue(repo.cardPreviews.isEmpty)
        }
        repo.mediaWorker.sync{repo.mediaFiles=try! MediaFiles(root:directory)}
        var tokens:[String]=[]
        for _ in 0..<8 {tokens.append(try CoreSchema.string(makeCard(cardRequest())["token"]))}
        assertCode("CARD_LIMIT"){_=try makeCard(cardRequest())}
        repo.releaseCard(tokens[0]);_=try makeCard(cardRequest())
        try open();repo.mediaWorker.sync{}
        assertCode("CARD_EXPIRED"){_=try awaitCard{repo.readCard(tokens[1],completion:$0)}}
        XCTAssertTrue(repo.cardPreviews.isEmpty)
    }
    func testCardRendererLongUnicodeAndMetadataRejection() throws {
        let data=try CardRenderer.render(name:String(repeating:"🌱",count:60),species:String(repeating:"界",count:160),images:[],dates:[])
        try CardRenderer.validate(data)
        var tagged=data
        // Insert a synthetic textual PNG chunk before IEND; validator rejects it before decoding metadata.
        let chunk=Data([0,0,0,3])+Data("tEXt".utf8)+Data("x=y".utf8)+Data([0,0,0,0])
        tagged.insert(contentsOf:chunk,at:tagged.count-12)
        XCTAssertThrowsError(try CardRenderer.validate(tagged))
    }
    func testCardPassivePreviewAllowsReplacementButActiveHandoffBlocksIt() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let (_,zip)=try exportBackup()
        let response=try makeCard(cardRequest()),token=try CoreSchema.string(response["token"])
        let (id,preview)=try previewBackup(zip)
        let prepared:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(token,completion:$0)}
        let lease=try repo.grantCardHandoff(prepared)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["failed"]).object?["operation"]?.object?["state"]?.object?["code"]?.text,"BUSY")
        repo.releaseCardHandoff(lease.leaseID)
        let (retry,newPreview)=try previewBackup(zip)
        _=try backup("confirmImport",["operationId":.string(retry),"preview":newPreview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(retry,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open()
        assertCode("CARD_EXPIRED"){_=try awaitCard{repo.readCard(token,completion:$0)}}
        XCTAssertEqual(try allRows("plants").count,1)
    }
    func testCardOutputMutationAndMalformedRequestCannotAcquireOSLease() throws {
        try execute(0);try execute(1)
        let response=try makeCard(cardRequest()),token=try CoreSchema.string(response["token"])
        let prepared:CardHandoffPreparation=try awaitCard{repo.prepareCardHandoff(token,completion:$0)}
        let url=prepared.preview.snapshot.files.root.appendingPathComponent(prepared.preview.path)
        try Data("broken PNG".utf8).write(to:url)
        assertCode("PREVIEW_STALE"){_=try repo.grantCardHandoff(prepared)}
        XCTAssertTrue(repo.platformLeases.isEmpty)
        XCTAssertThrowsError(try awaitCard{repo.readCard(token,completion:$0)})
        var request=try CoreSchema.object(CanonicalParser.parse(cardRequest()));request["notes"] = .string("private")
        assertCode("FIELD_INVALID"){_=try makeCard(CanonicalValue.object(request).json())}
    }

    func testCardSaveReceiptRequiresActualRequestAndCompletion() {
        XCTAssertEqual(CardSaveResult.resolve(requestCreated:false,completed:true,errorReported:false),.failed)
        XCTAssertEqual(CardSaveResult.resolve(requestCreated:true,completed:true,errorReported:false),.saved)
        XCTAssertEqual(CardSaveResult.resolve(requestCreated:true,completed:false,errorReported:true),.failed)
        XCTAssertEqual(CardSaveResult.resolve(requestCreated:true,completed:false,errorReported:false),.unknown)
    }

}
