import Foundation
import XCTest
@testable import VerdiNative

final class TestStoreCache: StoreCache {
    var data:Data?, failRead=false, failWrite=false
    func read() throws -> Data? {if failRead {throw CoreRepositoryError("LOCKED")};return data}
    func write(_ value:Data) throws {if failWrite {throw CoreRepositoryError("DISK_FULL")};data=value}
}
let storeTestConfig=StoreConfiguration.preview(bundleID:"dev.verdi.authority-test")
func storeEvidence(_ signed:Double=1, revoked:Bool=false, original:String="1",product:String?=nil) -> StoreEvidence {
    StoreEvidence(productID:product ?? storeTestConfig.productID,bundleID:storeTestConfig.bundleID,environment:storeTestConfig.environment,transactionID:original,originalID:original,signedAt:Date(timeIntervalSince1970:signed),purchasedAt:Date(timeIntervalSince1970:0),revokedAt:revoked ? Date(timeIntervalSince1970:signed):nil,recordedAt:Date(timeIntervalSince1970:signed))
}
final class StoreAuthorityTests: XCTestCase {
    func testVerifiedGrantOfflineCacheAndFreshInstallationIsolation() throws {
        let cache=TestStoreCache(),a=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:TestStoreCache())
        XCTAssertFalse(a.withCapability{$0.pro})
        let first=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache)
        try first.accept(storeEvidence());XCTAssertTrue(first.withCapability{$0.pro})
        first.markUnknown();XCTAssertTrue(first.withCapability{$0.pro})
        let reopened=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache)
        XCTAssertTrue(reopened.withCapability{$0.pro})
        XCTAssertEqual(reopened.withCapability{$0.freshness},"cached")
        let reinstall=StoreAuthority(configuration:storeTestConfig,installation:"two",cache:cache)
        XCTAssertFalse(reinstall.withCapability{$0.pro})
        let wrong=StoreAuthority(configuration:.preview(bundleID:"other"),installation:"one",cache:cache)
        XCTAssertFalse(wrong.withCapability{$0.pro})
    }
    func testRevocationOrderingTieAndSeparateRepurchase() throws {
        let a=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:TestStoreCache())
        try a.accept(storeEvidence(10));try a.accept(storeEvidence(20,revoked:true))
        let revision=a.withCapability{$0.revision}
        try a.accept(storeEvidence(10));try a.accept(storeEvidence(20))
        XCTAssertFalse(a.withCapability{$0.pro});XCTAssertEqual(a.withCapability{$0.revision},revision)
        try a.accept(storeEvidence(30,original:"2"));XCTAssertTrue(a.withCapability{$0.pro})
        XCTAssertThrowsError(try a.accept(storeEvidence(40,product:"unrelated")))
    }
    func testFailedRevocationCannotBeErasedByReplayedGrant() throws {
        let cache=TestStoreCache(),a=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:TestStoreCache())
        XCTAssertFalse(a.withCapability{$0.pro})
        let authority=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache)
        try authority.accept(storeEvidence(10));let old=cache.data
        cache.failWrite=true
        XCTAssertThrowsError(try authority.accept(storeEvidence(20,revoked:true)))
        XCTAssertFalse(authority.withCapability{$0.pro});XCTAssertEqual(cache.data,old)
        cache.failWrite=false
        try authority.accept(storeEvidence(10));try authority.accept(storeEvidence(20))
        XCTAssertFalse(authority.withCapability{$0.pro})
        try authority.accept(storeEvidence(20,revoked:true))
        XCTAssertFalse(StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache).withCapability{$0.pro})
        try authority.accept(storeEvidence(30,original:"2"));XCTAssertTrue(authority.withCapability{$0.pro})
    }
    func testFailedGrantDoesNotPublishAndLockedCacheIsNotDeleted() throws {
        let cache=TestStoreCache();cache.failWrite=true
        let a=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache)
        XCTAssertThrowsError(try a.accept(storeEvidence()));XCTAssertFalse(a.withCapability{$0.pro})
        cache.failWrite=false;try a.accept(storeEvidence());let bytes=cache.data
        cache.failRead=true
        let locked=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:cache)
        XCTAssertFalse(locked.withCapability{$0.pro});XCTAssertEqual(bytes,cache.data)
        let revision=locked.withCapability{$0.revision}
        cache.failRead=false;try locked.load();XCTAssertTrue(locked.withCapability{$0.pro})
        XCTAssertGreaterThan(locked.withCapability{$0.revision},revision)
    }
    func testAttemptStateSurvivesRestartAndCorruptionDoesNotReset() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        // Resume interrupted mkdir-before-marker initialization.
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let disk=try StoreDisk(directory:root)
        let a=StoreAttempt(intentID:UUID().uuidString.lowercased(),datasetID:UUID().uuidString.lowercased(),commandID:nil,payloadHash:nil,draftID:nil,draftRevision:nil,phase:"pending",continuationAbandoned:true)
        try disk.save(a)
        let reopen=try StoreDisk(directory:root);XCTAssertEqual(try reopen.read().attempt,a)
        XCTAssertEqual(reopen.installation,disk.installation)
        try Data("broken".utf8).write(to:disk.file)
        XCTAssertThrowsError(try StoreDisk(directory:root))
        XCTAssertEqual(try String(contentsOf:disk.file),"broken")
    }
}
extension CoreRepositoryTests {
    func testNativeProGateAndRevocationBetweenPreviewAndCommitPreserveData() throws {
        try execute(0)
        for _ in 0..<5 {_ = try insertArchivedFixturePlant()}
        try repo.database!.transaction{try $0.execute("UPDATE plants SET archived=0")}
        var p=try plan(1),result=try CoreSchema.object(p["result"])
        let revision=try CoreSchema.number(CoreSchema.object(call("metadata"))["collectionRevision"])
        p["expectedCollectionRevision"] = .integer(revision);result["collectionRevision"] = .integer(revision+1);p["result"] = .object(result);p=try rehash(p)
        assertCode("ACTIVE_LIMIT"){_ = try preview(p)}
        let authority=StoreAuthority(configuration:storeTestConfig,installation:"one",cache:TestStoreCache())
        repo.storeAuthority=authority
        try authority.accept(storeEvidence(10))
        // Forged/stale Dart revision does not bypass the native capability boundary.
        assertCode("PREVIEW_STALE"){_ = try preview(p)}
        p["accessRevision"] = .integer(authority.withCapability{$0.revision});p=try preview(rehash(p))
        let plants=try allRows("plants"),drafts=try allRows("plant_drafts")
        try authority.accept(storeEvidence(20,revoked:true))
        assertCode("PREVIEW_STALE"){_ = try call("commit",["plan":.object(p)])}
        XCTAssertEqual(try allRows("plants"),plants);XCTAssertEqual(try allRows("plant_drafts"),drafts)
        try authority.accept(storeEvidence(30,original:"2"))
        p["accessRevision"] = .integer(authority.withCapability{$0.revision});p=try preview(rehash(p))
        _ = try call("commit",["plan":.object(p)])
        XCTAssertEqual(try allRows("plants").count,6)
    }
}
