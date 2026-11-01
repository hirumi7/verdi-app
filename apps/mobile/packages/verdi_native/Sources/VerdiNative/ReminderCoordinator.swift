import Foundation

public protocol ReminderCenter: AnyObject {
    func authorization() async throws -> String
    func requestAuthorization() async throws -> String
    func pending() async throws -> [String]
    func delivered() async throws -> [String]
    func remove(pending:[String],delivered:[String]) async throws
    func add(_ request:ReminderRequest) async throws
}

public actor ReminderCoordinator {
    let core:CoreRepository, center:ReminderCenter
    let budget:Int
    let now:()->Date, zone:()->TimeZone
    var ledger:ReminderLedger?
    var running=false, again=false
    var last:CanonicalValue = .null
    var unretainedTaps:[(String,String,Date)]=[]
    public var changed:(()->Void)?
    public init(core:CoreRepository,center:ReminderCenter,maximumPending:Int=60) {
        self.core=core;self.center=center;self.budget=maximumPending;now=Date.init;zone={.current}
    }
    init(core:CoreRepository,center:ReminderCenter,budget:Int=60,now:@escaping()->Date,zone:@escaping()->TimeZone) {
        self.core=core;self.center=center;self.budget=budget;self.now=now;self.zone=zone
    }
    public func observe(_ callback:@escaping()->Void) {changed=callback}
    func store() throws -> ReminderLedger {
        if let ledger{try ledger.recover();return ledger}
        let created=try ReminderLedger(core.installationDirectory);ledger=created;return created
    }
    func result(_ state:String,_ context:ReminderContext?,attempted:Int=0,confirmed:Int=0,omitted:Int=0,past:Int=0,error:String?=nil)->CanonicalValue {
        .object(["state":.string(state),"datasetId":context.map{.string($0.dataset)} ?? .null,"collectionRevision":context.map{.integer($0.collection)} ?? .null,"attempted":.integer(Int64(attempted)),"pendingConfirmed":.integer(Int64(confirmed)),"omittedCapacity":.integer(Int64(omitted)),"pastCount":.integer(Int64(past)),"errors":.array(error.map{[.object(["code":.string($0),"retryable":.boolean(true),"requestId":.null])]} ?? [])])
    }
    public func readState() async throws -> String {
        let context=try core.reminderContext(),permission=try await center.authorization()
        var projection=last
        if projection.isNull {projection=(try? store().lastResult(dataset:context.dataset)) ?? .null}
        if projection.object?["datasetId"]?.text != context.dataset || projection.object?["collectionRevision"]?.integer != context.collection {projection=result("deferred",context)}
        return try CanonicalValue.object(["datasetId":.string(context.dataset),"settings":context.settings,"authorization":.string(permission),"hasSavedSchedule":.boolean(context.savedSchedule),"lastReconcile":projection]).json()
    }
    public func savePreferences(_ request:String) async throws -> String {
        let saved=try core.reminderSettings(request,resolve:false)
        await reconcile();return try saved.json()
    }
    public func resolvePreferences(_ request:String) throws -> String {try core.reminderSettings(request,resolve:true).json()}
    public func requestPermission(context:String) async throws -> String {
        guard ["settings","firstSchedule"].contains(context),try core.reminderContext().savedSchedule else{throw CoreRepositoryError("NO_SAVED_SCHEDULE")}
        let lease=try core.acquirePlatformLease();defer{core.releasePlatformLease(lease)}
        if try await center.authorization()=="notDetermined" {_ = try await center.requestAuthorization()}
        await reconcile();return try await readState()
    }
    @discardableResult public func reconcile() async -> String {
        if running {again=true;return (try? last.json()) ?? "null"}
        running=true;defer{running=false;changed?()}
        for _ in 0..<2 {
            again=false
            do {last=try await pass()}
            catch {last=result("deferred",try? core.reminderContext(),error:(error as? CoreRepositoryError)?.code ?? "nativeFailure")}
            if !again {break}
        }
        return (try? last.json()) ?? "null"
    }
    func pass() async throws -> CanonicalValue {
        guard (0...60).contains(budget) else{throw CoreRepositoryError("FIELD_INVALID")}
        let lease=try core.acquirePlatformLease();defer{core.releasePlatformLease(lease)}
        let context=try core.reminderContext(),store=try store(),p=try context.preferences
        let authorization=try await center.authorization()
        let allowed=["authorized","provisional"].contains(authorization)
        let before=try await center.pending(),other=before.filter{!$0.hasPrefix(ReminderPlan.prefix)}.count
        var plan=ReminderAccumulator(budget:0)
        if p.enabled && allowed {plan=try core.reminderGroups(context,ledger:store,budget:max(0,budget-other),at:now(),zone:zone())}
        guard try core.reminderMatches(context) else{again=true;return result("deferred",context,error:"STALE")}
        let requests=try store.persist(plan.groups,context:context,zone:zone().identifier,now:now())
        let wanted=Set(requests.map(\.identifier)),delivered=try await center.delivered()
        try await center.remove(pending:before.filter{$0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0)},delivered:delivered.filter{$0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0)})
        var pending=try await center.pending(),attempted=0,failed=false
        for request in requests {
            guard try core.reminderMatches(context) else {
                try await center.remove(pending:Array(wanted),delivered:Array(wanted));again=true
                return result("deferred",context,error:"STALE")
            }
            if request.fireAt<=now() {continue}
            if pending.contains(request.identifier) {continue}
            guard pending.count<budget else{failed=true;continue}
            attempted += 1
            do {try await center.add(request)} catch {failed=true}
            pending=try await center.pending()
        }
        guard try core.reminderMatches(context) else {
            try await center.remove(pending:Array(wanted),delivered:Array(wanted));again=true
            return result("deferred",context,error:"STALE")
        }
        pending=try await center.pending()
        let confirmed=pending.filter{wanted.contains($0)}.count
        let obsolete=pending.contains{$0.hasPrefix(ReminderPlan.prefix) && !wanted.contains($0)}
        let state = !p.enabled ? "disabled" : !allowed ? "denied" : failed || obsolete || confirmed<requests.count ? "partial":"complete"
        let value=result(state,context,attempted:attempted,confirmed:confirmed,omitted:plan.totalGroups-requests.count,past:plan.past,error:failed || obsolete ? "nativeFailure":nil)
        try store.result(value)
        if (state=="complete" || state=="disabled") && !obsolete {try core.reminderClear(context)}
        return value
    }
    func flushTaps() throws {
        guard !unretainedTaps.isEmpty else{return}
        let ledger=try store()
        while let first=unretainedTaps.first {
            try ledger.retainTap(requestID:first.0,payload:first.1,now:first.2)
            unretainedTaps.removeFirst()
        }
    }
    public func retainTap(requestID:String,payload:String) throws {
        defer{changed?()}
        let canonical=payload.utf8.count<=8192 ? ((try? CanonicalParser.parse(payload).json()) ?? "null") : "null"
        if !unretainedTaps.contains(where:{$0.0==requestID}) {unretainedTaps.append((String(requestID.prefix(100)),canonical,now()))}
        if unretainedTaps.count>32 {unretainedTaps.removeFirst(unretainedTaps.count-32)}
        try flushTaps()
    }
    public func readTap() throws -> String {
        try flushTaps()
        let store=try store()
        guard let row=try store.tap(now:now()) else{return "null"}
        let id=try CoreSchema.text(row[0]),request=try CoreSchema.text(row[1]),payload=try CoreSchema.text(row[2])
        _ = try core.reminderContext() // Defer navigation until runtime recovery is complete.
        let parsed=try? CanonicalParser.parse(payload)
        var valid=false
        if let parsed,try store.issued(request,payload:payload) {
            do {valid=try core.reminderTapValid(parsed)}
            catch let error as CoreRepositoryError where error.code=="FIELD_INVALID" {valid=false}
        }
        return try CanonicalValue.object(["eventId":.string(id),"current":.boolean(valid)]).json()
    }
    public func acknowledgeTap(_ token:String) throws {try store().acknowledge(token)}
}
