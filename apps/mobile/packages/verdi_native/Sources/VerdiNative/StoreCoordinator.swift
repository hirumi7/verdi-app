import Foundation
import StoreKit

public actor StoreCoordinator {
    let authority: StoreAuthority
    let core: CoreRepository
    let configuration: StoreConfiguration
    var listener: Task<Void,Never>?
    var started=false, busy=false
    var activePurchaseID:String?, purchaseCancelled=false
    var productLookup:(() async throws -> Product?)?
    var status="idle"
    var observer:(@Sendable ()->Void)?
    public init(core:CoreRepository,authority:StoreAuthority) {
        self.core=core;self.authority=authority;configuration=authority.configuration
    }
    deinit {listener?.cancel()}
    public func observe(_ changed:@escaping @Sendable ()->Void) {observer=changed}
    public func start() async {
        guard !started else {return};started=true
        listener=Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else {return}
                await self?.consume(result)
            }
        }
        do {
            let disk=try authority.diskStore()
            if var attempt=try disk.read().attempt,["prepared","purchasing"].contains(attempt.phase) {
                attempt.phase="recoveryRequired";try disk.save(attempt)
            }
        } catch {status="recoveryUnavailable"}
        _ = await refresh()
    }
    public func readState() -> String {
        var result=(authority.state().object ?? [:])
        result["testEnvironment"] = .boolean(configuration.environment == AppStore.Environment.xcode.rawValue)
        result["status"] = .string(status);result["busy"] = .boolean(busy)
        do {
            let attempt=try authority.diskStore().read().attempt
            result["attempt"] = attempt.map{.object([
                "intentId":.string($0.intentID),"datasetId":.string($0.datasetID),
                "commandId":$0.commandID.map{.string($0)} ?? .null,
                "payloadHash":$0.payloadHash.map{.string($0)} ?? .null,
                "priorPending":.boolean($0.unresolvedPending),"phase":.string($0.phase),"continuationAbandoned":.boolean($0.continuationAbandoned)])} ?? .null
        } catch {result["status"] = .string("recoveryUnavailable")}
        return (try? CanonicalValue.object(result).json()) ?? "{}"
    }
    public func loadOffer() async -> String {
        do {
            guard let product=try await product() else {return "null"}
            return try CanonicalValue.object(["productId":.string(product.id),"displayName":.string(product.displayName),"displayPrice":.string(product.displayPrice),"type":.string("nonConsumable")]).json()
        } catch {return "null"}
    }
    private func product() async throws -> Product? {
        if let productLookup {return try await productLookup()}
        let items=try await Product.products(for:[configuration.productID])
        return items.first{$0.id == configuration.productID && $0.type == .nonConsumable}
    }
    enum Consumption {case accepted, rejected, recovery}
    @discardableResult
    private func consume(_ result:VerificationResult<Transaction>) async -> Consumption {
        guard case .verified(let transaction)=result,
              transaction.productID == configuration.productID,
              transaction.productType == .nonConsumable,
              transaction.appBundleID == configuration.bundleID,
              transaction.environment.rawValue == configuration.environment else {
            authority.markUnknown();status="unverified";observer?();return .rejected
        }
        let evidence=StoreEvidence(productID:transaction.productID,bundleID:transaction.appBundleID,
            environment:transaction.environment.rawValue,transactionID:String(transaction.id),originalID:String(transaction.originalID),
            signedAt:transaction.signedDate,purchasedAt:transaction.purchaseDate,revokedAt:transaction.revocationDate,recordedAt:Date())
        do {
            try authority.accept(evidence)
            await transaction.finish()
            if authority.withCapability({$0.pro}) {try completeEligibleAttempt()}
            status=authority.withCapability({$0.pro}) ? "verified":"revoked"
            observer?();return .accepted
        } catch {status="recoveryUnavailable";observer?();return .recovery}
    }
    public func refresh() async -> String {
        do {
            try authority.load()
            let attempt=try authority.diskStore().read().attempt
            status = attempt?.phase == "persistencePending" ? "recoveryUnavailable":"checking"
        } catch {status="recoveryUnavailable"}
        var matched=false, count=0
        for await result in Transaction.all {
            // Unrelated products cannot revoke or grant this product.
            let transaction=result.unsafePayloadValue
            guard transaction.productID == configuration.productID else {continue}
            count += 1
            if count > 1024 {status="recoveryUnavailable";break}
            matched = (await consume(result) == .accepted) || matched
        }
        if let latest=await Transaction.latest(for:configuration.productID) {
            matched = (await consume(latest) == .accepted) || matched
        }
        if !matched {authority.markUnknown();if status != "recoveryUnavailable" && status != "unverified" {status="noneFound"}}
        // Covers a crash after durable cache commit but before attempt acknowledgement.
        if authority.withCapability({$0.pro}) {
            do {try completeEligibleAttempt()} catch {status="recoveryUnavailable"}
        }
        observer?();return readState()
    }
    private func completeEligibleAttempt() throws {
        let disk=try authority.diskStore()
        if var a=try disk.read().attempt,
           ["prepared","purchasing","pending","recoveryRequired","persistencePending"].contains(a.phase) {
            a.phase="verified";a.priorPending=false;try disk.save(a)
        }
    }
    private func setPhase(_ phase:String, intent:String?=nil) throws {
        let disk=try authority.diskStore()
        if var a=try disk.read().attempt,intent == nil || a.intentID == intent {
            if phase == "pending" {a.priorPending=true}
            a.phase = a.priorPending == true && ["cancelled","failed","unverified"].contains(phase) ? "pending":phase
            try disk.save(a)
        }
    }
    public func retryPendingPurchase(_ intent:String) async throws -> String {
        try CoreSchema.uuid(intent)
        guard !busy,let prior=try authority.diskStore().read().attempt,
              prior.intentID == intent,prior.unresolvedPending else {return readState()}
        let request=try CanonicalValue.object(["intentId":.string(prior.intentID),"datasetId":.string(prior.datasetID),
            "commandId":prior.commandID.map{.string($0)} ?? .null,"payloadHash":prior.payloadHash.map{.string($0)} ?? .null]).json()
        return try await purchase(request,pendingRetry:true)
    }
    public func purchase(_ request:String) async throws -> String {try await purchase(request,pendingRetry:false)}
    private func purchase(_ request:String,pendingRetry:Bool) async throws -> String {
        if busy {return readState()}
        let fields=try CoreSchema.object(CanonicalParser.parse(request))
        let requestedID=try CoreSchema.string(fields["intentId"]);try CoreSchema.uuid(requestedID)
        busy=true;activePurchaseID=requestedID;purchaseCancelled=false
        defer{busy=false;activePurchaseID=nil;observer?()}
        if !started {await start()}
        if pendingRetry {_ = await refresh()}
        if purchaseCancelled {return readState()}
        if status == "recoveryUnavailable" {return readState()}
        let disk=try authority.diskStore()
        if authority.withCapability({$0.pro}) {status="verified";return readState()}
        if let prior=try disk.read().attempt,prior.unresolvedPending && !pendingRetry {return readState()}
        if pendingRetry {
            guard let prior=try disk.read().attempt,prior.intentID == requestedID,prior.unresolvedPending else {return readState()}
        }
        var recovered:StoreAttempt?
        if let prior=try disk.read().attempt,(["prepared","recoveryRequired"].contains(prior.phase) || pendingRetry && prior.unresolvedPending) {
            guard fields["intentId"]?.text == prior.intentID,fields["datasetId"]?.text == prior.datasetID,
                  fields["commandId"]?.text == prior.commandID,fields["payloadHash"]?.text == prior.payloadHash else {
                status="recoveryRequired";return readState()
            }
            recovered=prior
        }
        var proposed:StoreAttempt
        var commerceOnly=false
        do {proposed=try core.storeAttempt(request)}
        catch let error as CoreRepositoryError where recovered != nil && ["DATASET_CHANGED","DRAFT_CONFLICT","STALE_TARGET","NOT_ELIGIBLE"].contains(error.code) {
            // Explicit retry of the same interrupted payment, never a stale save.
            proposed=recovered!;proposed.continuationAbandoned=true;proposed.phase="prepared";commerceOnly=true
        }
        if let prior=try disk.read().attempt {
            if prior.phase == "persistencePending" || (!pendingRetry && ["purchasing","pending"].contains(prior.phase)) {return readState()}
            if prior.intentID == proposed.intentID {
                guard prior.datasetID == proposed.datasetID,prior.commandID == proposed.commandID,prior.payloadHash == proposed.payloadHash,(!prior.continuationAbandoned || recovered != nil) else {throw CoreRepositoryError("NOT_ELIGIBLE")}
                if prior.phase == "verified" {return readState()}
            }
        }
        if authority.withCapability({$0.pro}) {status="verified";return readState()}
        if let recovered {
            proposed.continuationAbandoned=proposed.continuationAbandoned || recovered.continuationAbandoned
            proposed.priorPending=recovered.unresolvedPending
        }
        let lease=try core.acquirePlatformLease();defer{core.releasePlatformLease(lease)}
        var sheetStarted=false, sheetReturned=false
        do {
            if recovered != nil {proposed.phase=proposed.priorPending == true ? "pending":"recoveryRequired"}
            try disk.save(proposed)
            let loaded=try await product()
            if purchaseCancelled {
                status=proposed.priorPending == true ? "pending":recovered == nil ? "cancelled":"recoveryRequired"
                if recovered == nil {try setPhase("cancelled",intent:proposed.intentID)}
                return readState()
            }
            if authority.withCapability({$0.pro}) {try completeEligibleAttempt();status="verified";return readState()}
            guard let product=loaded else {
                status="offerUnavailable"
                if recovered == nil {try setPhase("failed",intent:proposed.intentID)}
                return readState()
            }
            // Revalidate dataset/draft after asynchronous product lookup.
            if !commerceOnly {
                let current=try core.storeAttempt(request)
                guard current.datasetID == proposed.datasetID,current.commandID == proposed.commandID,current.payloadHash == proposed.payloadHash,current.draftID == proposed.draftID,current.draftRevision == proposed.draftRevision else {throw CoreRepositoryError("STALE_TARGET")}
            }
            try setPhase("purchasing",intent:proposed.intentID)
            status="purchasing";observer?()
            sheetStarted=true
            let result=try await product.purchase()
            sheetReturned=true
            switch result {
            case .success(let verification):
                switch await consume(verification) {
                case .accepted:break
                case .rejected:status="unverified";try setPhase("unverified",intent:proposed.intentID)
                case .recovery:status="recoveryUnavailable";try setPhase("persistencePending",intent:proposed.intentID)
                }
            case .pending:status="pending";try setPhase("pending",intent:proposed.intentID)
            case .userCancelled:status=proposed.priorPending == true ? "pending":"cancelled";try setPhase("cancelled",intent:proposed.intentID)
            @unknown default:status="unverified";try setPhase("unverified",intent:proposed.intentID)
            }
        } catch {
            if sheetStarted && !sheetReturned {status=proposed.priorPending == true ? "pending":"failed";try? setPhase("failed",intent:proposed.intentID)}
            else {status="recoveryUnavailable"}
        }
        busy=false;return readState()
    }
    public func restorePurchases() async -> String {
        if !started {await start()}
        if busy {return readState()}
        busy=true;defer{busy=false;observer?()}
        do {
            try await AppStore.sync()
            _ = await refresh()
            if authority.withCapability({$0.pro}) {status="restored"}
        } catch StoreKitError.userCancelled {status="cancelled"}
        catch {authority.markUnknown();status="failed"}
        busy=false;return readState()
    }
    public func cancelIntent(_ id:String) throws -> String {
        try CoreSchema.uuid(id)
        if activePurchaseID == id {purchaseCancelled=true}
        let disk=try authority.diskStore()
        if var attempt=try disk.read().attempt,attempt.intentID == id {
            attempt.continuationAbandoned=true;try disk.save(attempt)
        }
        observer?();return readState()
    }
    public func stopForTests() {listener?.cancel();listener=nil}
}
