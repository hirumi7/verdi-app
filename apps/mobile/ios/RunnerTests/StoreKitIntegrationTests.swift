#if os(iOS)
import XCTest
import StoreKit
import StoreKitTest
import Security
@testable import VerdiNative

final class StoreKitIntegrationTests: XCTestCase {
    func testRealLocalPurchaseCacheRestoreAndRefund() async throws {
        let file=try XCTUnwrap(Bundle(for:Self.self).url(forResource:"Verdi",withExtension:"storekit"))
        let session=try SKTestSession(contentsOf:file)
        session.resetToDefaultState();session.disableDialogs=true;session.clearTransactions()
        defer{session.clearTransactions()}
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:root)}
        let config=StoreConfiguration.preview(bundleID:try XCTUnwrap(Bundle.main.bundleIdentifier))
        let disk=try StoreDisk(directory:root.appendingPathComponent("store"))
        let cache=KeychainStoreCache(namespace:config.namespace+".qa."+UUID().uuidString)
        let authority=StoreAuthority(configuration:config,installation:disk.installation,cache:cache,disk:disk)
        defer{SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:cache.namespace] as CFDictionary)}
        let core=CoreRepository(directory:root.appendingPathComponent("core"));core.storeAuthority=authority
        let opened=try CanonicalParser.parse(core.call(operation:"open",body:"{\"profile\":\"custom_core_v1\",\"protocolVersion\":1}"))
        let coordinator=StoreCoordinator(core:core,authority:authority)
        await coordinator.start()
        let offer=try CanonicalParser.parse(await coordinator.loadOffer())
        XCTAssertEqual(offer.object?["productId"]?.text,config.productID)
        XCTAssertNotNil(offer.object?["displayPrice"]?.text)
        let request=try CanonicalValue.object(["intentId":.string(UUID().uuidString.lowercased()),"datasetId":opened.object!["datasetId"]!,"commandId":.null,"payloadHash":.null]).json()
        let purchased=try CanonicalParser.parse(await coordinator.purchase(request))
        XCTAssertEqual(purchased.object?["access"]?.text,"pro", "state: \(purchased)")
        let cached=StoreAuthority(configuration:config,installation:disk.installation,cache:cache,disk:disk)
        XCTAssertTrue(cached.withCapability{$0.pro})
        let restored=try CanonicalParser.parse(await coordinator.restorePurchases())
        XCTAssertEqual(restored.object?["access"]?.text,"pro")
        let transactions=session.allTransactions()
        let transaction=try XCTUnwrap(transactions.first)
        try session.refundTransaction(identifier:transaction.identifier)
        for _ in 0..<30 {
            _ = await coordinator.refresh()
            if !authority.withCapability({$0.pro}) {break}
            try await Task.sleep(for:.milliseconds(100))
        }
        XCTAssertFalse(authority.withCapability{$0.pro})
        let refunded=StoreAuthority(configuration:config,installation:disk.installation,cache:cache,disk:disk)
        XCTAssertFalse(refunded.withCapability{$0.pro})
        await coordinator.stopForTests()
        _ = try core.call(operation:"close",body:CanonicalValue.object(["sessionId":opened.object!["sessionId"]!]).json())
    }
    func testPendingApprovalAndAbandonmentNeverOpenSecondPurchase() async throws {
        let c=try HostedStoreContext()
        defer{c.cleanup()}
        await c.coordinator.start()
        c.session.askToBuyEnabled=true
        let first=try CanonicalParser.parse(await c.coordinator.purchase(c.request))
        XCTAssertEqual(first.object?["access"]?.text,"free")
        XCTAssertEqual(first.object?["attempt"]?.object?["phase"]?.text,"pending")
        _ = try await c.coordinator.cancelIntent(c.intent)
        let other=try c.makeRequest(UUID().uuidString.lowercased())
        _ = try await c.coordinator.purchase(other)
        let transactions=c.session.allTransactions()
        XCTAssertEqual(transactions.count,1)
        try c.session.approveAskToBuyTransaction(identifier:try XCTUnwrap(transactions.first).identifier)
        for _ in 0..<30 {
            _ = await c.coordinator.refresh()
            if c.authority.withCapability({$0.pro}) {break}
            try await Task.sleep(for:.milliseconds(100))
        }
        let state=try CanonicalParser.parse(await c.coordinator.readState())
        XCTAssertEqual(state.object?["access"]?.text,"pro")
        XCTAssertEqual(try state.object?["attempt"]?.object?["continuationAbandoned"]?.json(),"true")
        XCTAssertEqual(state.object?["attempt"]?.object?["intentId"]?.text,c.intent)
        await c.coordinator.stopForTests()
    }
    func testLeavingDuringProductLookupPreventsStoreSheet() async throws {
        let c=try HostedStoreContext()
        defer{c.cleanup()}
        await c.coordinator.start()
        let products=try await Product.products(for:[c.config.productID])
        let product=try XCTUnwrap(products.first)
        let entered=expectation(description:"lookup reached")
        let gate=StoreLookupGate()
        await c.coordinator.testProductLookup {
            entered.fulfill();await gate.wait();return product
        }
        let task=Task{try await c.coordinator.purchase(c.request)}
        await fulfillment(of:[entered],timeout:5)
        _ = try await c.coordinator.cancelIntent(c.intent)
        await gate.resume()
        let result=try CanonicalParser.parse(await task.value)
        XCTAssertEqual(result.object?["status"]?.text,"cancelled")
        XCTAssertEqual(c.session.allTransactions().count,0)
        XCTAssertFalse(c.authority.withCapability{$0.pro})
        await c.coordinator.stopForTests()
    }
    func testRestartUsesOriginalAttemptAndCancelledAttemptIsNotRevived() async throws {
        let c=try HostedStoreContext()
        defer{c.cleanup()}
        var attempt=try c.core.storeAttempt(c.request)
        attempt.phase="purchasing";try c.disk.save(attempt)
        await c.coordinator.start()
        var state=try CanonicalParser.parse(await c.coordinator.readState())
        XCTAssertEqual(state.object?["attempt"]?.object?["phase"]?.text,"recoveryRequired")
        _ = try await c.coordinator.purchase(c.makeRequest(UUID().uuidString.lowercased()))
        XCTAssertEqual(c.session.allTransactions().count,0)
        _ = try await c.coordinator.purchase(c.request)
        XCTAssertTrue(c.authority.withCapability{$0.pro})
        XCTAssertEqual(c.session.allTransactions().count,1)
        attempt.phase="cancelled";try c.disk.save(attempt)
        _ = await c.coordinator.refresh()
        state=try CanonicalParser.parse(await c.coordinator.readState())
        XCTAssertEqual(state.object?["attempt"]?.object?["phase"]?.text,"cancelled")
        await c.coordinator.stopForTests()
    }

    func testVerifiedPurchaseWriteFailureStaysUnfinishedUntilRecovery() async throws {
        let c=try HostedStoreContext();defer{c.cleanup()}
        await c.coordinator.start();c.faultCache.failWrite=true
        let result=try CanonicalParser.parse(await c.coordinator.purchase(c.request))
        XCTAssertEqual(result.object?["access"]?.text,"free")
        XCTAssertEqual(result.object?["status"]?.text,"recoveryUnavailable")
        _ = try await c.coordinator.purchase(c.makeRequest(UUID().uuidString.lowercased()))
        XCTAssertEqual(c.session.allTransactions().count,1)
        var unfinished=0
        for await transaction in Transaction.unfinished where transaction.unsafePayloadValue.productID == c.config.productID {unfinished += 1}
        XCTAssertGreaterThan(unfinished,0)
        c.faultCache.failWrite=false;_ = await c.coordinator.refresh()
        XCTAssertTrue(c.authority.withCapability{$0.pro})
        unfinished=0
        for await transaction in Transaction.unfinished where transaction.unsafePayloadValue.productID == c.config.productID {unfinished += 1}
        XCTAssertEqual(unfinished,0)
        await c.coordinator.stopForTests()
    }
    func testRepairedAttemptStorageWithEmptyHistoryAllowsFirstPurchase() async throws {
        let c=try HostedStoreContext();defer{c.cleanup()}
        let bytes=try Data(contentsOf:c.disk.file)
        try Data("broken".utf8).write(to:c.disk.file)
        await c.coordinator.start()
        var state=try CanonicalParser.parse(await c.coordinator.readState())
        XCTAssertEqual(state.object?["status"]?.text,"recoveryUnavailable")
        try bytes.write(to:c.disk.file,options:.atomic)
        _ = await c.coordinator.refresh()
        state=try CanonicalParser.parse(await c.coordinator.readState())
        XCTAssertEqual(state.object?["status"]?.text,"noneFound")
        _ = try await c.coordinator.purchase(c.request)
        XCTAssertTrue(c.authority.withCapability{$0.pro})
        await c.coordinator.stopForTests()
    }

    func testDeclinedApprovalRestartsAndExplicitRetryUsesSameIntent() async throws {
        let c=try HostedStoreContext();defer{c.cleanup()}
        await c.coordinator.start();c.session.askToBuyEnabled=true
        _ = try await c.coordinator.purchase(c.request)
        try c.session.declineAskToBuyTransaction(identifier:try XCTUnwrap(c.session.allTransactions().first).identifier)
        await c.coordinator.stopForTests()
        let restarted=StoreCoordinator(core:c.core,authority:c.authority)
        await restarted.start()
        _ = try await restarted.purchase(c.request)
        XCTAssertEqual(try c.disk.read().attempt?.phase,"pending")
        c.session.askToBuyEnabled=false
        let result=try CanonicalParser.parse(await restarted.retryPendingPurchase(c.intent))
        XCTAssertEqual(result.object?["access"]?.text,"pro")
        XCTAssertEqual(try c.disk.read().attempt?.intentID,c.intent)
        XCTAssertEqual(try c.disk.read().attempt?.phase,"verified")
        XCTAssertEqual(try c.disk.read().attempt?.priorPending,false)
        await restarted.stopForTests()
    }
    func testLateApprovalDuringPendingRetryLookupSuppressesSecondSheet() async throws {
        let c=try HostedStoreContext();defer{c.cleanup()}
        await c.coordinator.start();c.session.askToBuyEnabled=true
        _ = try await c.coordinator.purchase(c.request)
        let original=try XCTUnwrap(c.session.allTransactions().first)
        let products=try await Product.products(for:[c.config.productID])
        let product=try XCTUnwrap(products.first)
        let entered=expectation(description:"pending retry lookup")
        let gate=StoreLookupGate()
        await c.coordinator.testProductLookup {entered.fulfill();await gate.wait();return product}
        let retry=Task{try await c.coordinator.retryPendingPurchase(c.intent)}
        await fulfillment(of:[entered],timeout:5)
        _ = try await c.coordinator.retryPendingPurchase(c.intent)
        XCTAssertEqual(c.session.allTransactions().count,1)
        _ = try await c.coordinator.cancelIntent(c.intent)
        try c.session.approveAskToBuyTransaction(identifier:original.identifier)
        for _ in 0..<30 {
            _ = await c.coordinator.refresh()
            if c.authority.withCapability({$0.pro}) {break}
            try await Task.sleep(for:.milliseconds(100))
        }
        await gate.resume();_ = try await retry.value
        XCTAssertTrue(c.authority.withCapability{$0.pro})
        XCTAssertEqual(c.session.allTransactions().count,1)
        XCTAssertEqual(try c.disk.read().attempt?.continuationAbandoned,true)
        await c.coordinator.stopForTests()
    }
    func testInterruptedPendingRetryRetainsOriginAfterCancellationAndError() async throws {
        let c=try HostedStoreContext();defer{c.cleanup()}
        var attempt=try c.core.storeAttempt(c.request)
        attempt.phase="purchasing";attempt.priorPending=true;try c.disk.save(attempt)
        await c.coordinator.start()
        XCTAssertEqual(try c.disk.read().attempt?.phase,"recoveryRequired")
        _ = try await c.coordinator.purchase(c.request)
        XCTAssertEqual(c.session.allTransactions().count,0)
        let entered=expectation(description:"recovered retry lookup")
        let gate=StoreLookupGate()
        await c.coordinator.testProductLookup {entered.fulfill();await gate.wait();return nil}
        let retry=Task{try await c.coordinator.retryPendingPurchase(c.intent)}
        await fulfillment(of:[entered],timeout:5)
        _ = try await c.coordinator.cancelIntent(c.intent)
        await gate.resume();_ = try await retry.value
        XCTAssertEqual(try c.disk.read().attempt?.phase,"pending")
        XCTAssertEqual(try c.disk.read().attempt?.priorPending,true)
        await c.coordinator.testProductLookup {throw StoreKitError.networkError(URLError(.notConnectedToInternet))}
        _ = try await c.coordinator.retryPendingPurchase(c.intent)
        XCTAssertEqual(try c.disk.read().attempt?.phase,"pending")
        XCTAssertEqual(try c.disk.read().attempt?.priorPending,true)
        _ = try await c.coordinator.purchase(c.request)
        XCTAssertEqual(c.session.allTransactions().count,0)
        let products=try await Product.products(for:[c.config.productID])
        let product=try XCTUnwrap(products.first)
        await c.coordinator.testProductLookup {product}
        for failure:SKTestFailures.Purchase in [.generic(.userCancelled),.generic(.networkError(URLError(.notConnectedToInternet)))] {
            try await c.session.setSimulatedError(failure,forAPI:.purchase)
            _ = try await c.coordinator.retryPendingPurchase(c.intent)
            XCTAssertEqual(try c.disk.read().attempt?.phase,"pending")
            XCTAssertEqual(try c.disk.read().attempt?.priorPending,true)
            XCTAssertEqual(try c.disk.read().attempt?.continuationAbandoned,true)
        }
        await c.coordinator.stopForTests()
    }

}
private final class HostedFaultCache:StoreCache {
    let wrapped:KeychainStoreCache
    var failWrite=false
    init(_ wrapped:KeychainStoreCache) {self.wrapped=wrapped}
    func read() throws -> Data? {try wrapped.read()}
    func write(_ data:Data) throws {if failWrite {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")};try wrapped.write(data)}
}
private actor StoreLookupGate {
    var continuation:CheckedContinuation<Void,Never>?
    func wait() async {await withCheckedContinuation{continuation=$0}}
    func resume() {continuation?.resume();continuation=nil}
}
extension StoreCoordinator {
    func testProductLookup(_ lookup:@escaping() async throws -> Product?) {productLookup=lookup}
}
private final class HostedStoreContext {
    let session:SKTestSession,root:URL,config:StoreConfiguration,disk:StoreDisk,cache:KeychainStoreCache
    let authority:StoreAuthority,core:CoreRepository,coordinator:StoreCoordinator
    let faultCache:HostedFaultCache
    let opened:CanonicalValue,intent=UUID().uuidString.lowercased()
    var request:String {get throws {try makeRequest(intent)}}
    init() throws {
        let file=try XCTUnwrap(Bundle(for:StoreKitIntegrationTests.self).url(forResource:"Verdi",withExtension:"storekit"))
        session=try SKTestSession(contentsOf:file);session.resetToDefaultState();session.disableDialogs=true;session.clearTransactions()
        root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        config = .preview(bundleID:try XCTUnwrap(Bundle.main.bundleIdentifier))
        disk=try StoreDisk(directory:root.appendingPathComponent("store"))
        cache=KeychainStoreCache(namespace:config.namespace+".qa."+UUID().uuidString)
        faultCache=HostedFaultCache(cache)
        authority=StoreAuthority(configuration:config,installation:disk.installation,cache:faultCache,disk:disk)
        core=CoreRepository(directory:root.appendingPathComponent("core"));core.storeAuthority=authority
        opened=try CanonicalParser.parse(core.call(operation:"open",body:"{\"profile\":\"custom_core_v1\",\"protocolVersion\":1}"))
        coordinator=StoreCoordinator(core:core,authority:authority)
    }
    func makeRequest(_ id:String) throws -> String {
        try CanonicalValue.object(["intentId":.string(id),"datasetId":opened.object!["datasetId"]!,"commandId":.null,"payloadHash":.null]).json()
    }
    func cleanup() {
        session.clearTransactions()
        _ = try? core.call(operation:"close",body:CanonicalValue.object(["sessionId":opened.object!["sessionId"]!]).json())
        SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:cache.namespace] as CFDictionary)
        try? FileManager.default.removeItem(at:root)
    }
}
#endif
