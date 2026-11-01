import Foundation
import XCTest
@testable import VerdiNative

final class FakeReminderCenter:ReminderCenter {
    var permission="authorized", requests:[String:ReminderRequest]=[:], others:[String]=[], deliveredIDs:[String]=[]
    var failAdd=false, delayRemoval=false, prompts=0, adds=0
    var onAdd:(()throws->Void)?
    func authorization() async throws -> String {permission}
    func requestAuthorization() async throws -> String {prompts += 1;permission="denied";return permission}
    func pending() async throws -> [String] {others+requests.keys.sorted()}
    func delivered() async throws -> [String] {deliveredIDs}
    func remove(pending:[String],delivered:[String]) async throws {
        if !delayRemoval {for id in pending{requests.removeValue(forKey:id)};deliveredIDs.removeAll{delivered.contains($0)}}
    }
    func add(_ request:ReminderRequest) async throws {
        adds += 1
        if failAdd {failAdd=false;throw CoreRepositoryError("TEST_ADD_FAILURE")}
        try onAdd?();requests[request.identifier]=request
    }
}
final class ReminderPlanTests:XCTestCase {
    func preferences(_ minute:Int,_ start:Int=0,_ end:Int=0) throws -> ReminderPreferences {
        try ReminderPreferences(.object(["enabled":.boolean(true),"preferredMinute":.integer(Int64(minute)),"quietStartMinute":.integer(Int64(start)),"quietEndMinute":.integer(Int64(end)),"settingsRevision":.integer(1)]))
    }
    func testQuietHoursAndDSTResolveWallClockWithoutRewritingDate() throws {
        let utc=TimeZone(secondsFromGMT:0)!,ny=TimeZone(identifier:"America/New_York")!
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-10-20",preferences:preferences(420,1320,480),zone:utc)),"2026-10-20T08:00:00.000Z")
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-10-20",preferences:preferences(1380,1320,480),zone:utc)),"2026-10-21T08:00:00.000Z")
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-10-20",preferences:preferences(1380,60,60),zone:utc)),"2026-10-20T23:00:00.000Z")
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-03-08",preferences:preferences(150),zone:ny)),"2026-03-08T07:00:00.000Z")
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-11-01",preferences:preferences(90),zone:ny)),"2026-11-01T05:30:00.000Z")
        XCTAssertEqual(ReminderPlan.instant(try ReminderPlan.fire("2026-03-08",preferences:preferences(150,180,240),zone:ny)),"2026-03-08T08:00:00.000Z")
    }
    func testBoundedNearestGroupsAndStableHeadOrder() {
        var plan=ReminderAccumulator(budget:2)
        for i in (0..<10000).reversed() {plan.add(ReminderHead(headId:String(format:"%08d",i),headRevision:1),fire:Date(timeIntervalSince1970:100))}
        plan.flush()
        XCTAssertEqual(plan.groups.count,2);XCTAssertEqual(plan.totalGroups,625)
        XCTAssertEqual(plan.groups[0].heads.first?.headId,"00000000")
        XCTAssertEqual(plan.groups[1].heads.last?.headId,"00000031")
        XCTAssertLessThanOrEqual(plan.heads.count,32)
    }
}

extension CoreRepositoryTests {
    func reminderRequest(enabled:Bool=true,minute:Int=540,id:String=UUID().uuidString.lowercased()) throws -> String {
        let context=try repo.reminderContext()
        return try CanonicalValue.object(["operationId":.string(id),"datasetId":.string(dataset),"expectedRevision":.integer(context.revision),"values":.object(["enabled":.boolean(enabled),"preferredMinute":.integer(Int64(minute)),"quietStartMinute":.integer(0),"quietEndMinute":.integer(0)])]).json()
    }
    func removeReminderLedger() {try? FileManager.default.removeItem(at:URL(fileURLWithPath:directory.path+"-reminders"))}
    func testReminderSettingsReceiptUnknownRecoveryAndUnrelatedValues() throws {
        try execute(0);try execute(1)
        let rows=try allRows("plants")
        try repo.queue.sync{try repo.database!.transaction{sql in
            var settings=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(sql.query("SELECT payload_json FROM user_settings")[0][0])))
            settings["localeOverride"] = .string("zz-ZZ");settings["theme"] = .string("dark")
            try sql.execute("UPDATE user_settings SET payload_json=?",[.text(CanonicalValue.object(settings).json())])
        }}
        let request=try reminderRequest()
        failure = .afterCommit
        XCTAssertThrowsError(try repo.reminderSettings(request,resolve:false)) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"UNKNOWN_OUTCOME")}
        XCTAssertEqual(try repo.reminderSettings(request,resolve:true).object?["committed"]?.json(),"true")
        let first=try repo.reminderContext();XCTAssertEqual(first.settings.object?["localeOverride"]?.text,"zz-ZZ");XCTAssertEqual(first.settings.object?["theme"]?.text,"dark")
        _ = try repo.reminderSettings(request,resolve:false)
        XCTAssertEqual(try repo.reminderContext().revision,first.revision)
        XCTAssertEqual(try allRows("plants"),rows)
        let other=try reminderRequest(minute:600);failure = .beforeCommit
        XCTAssertThrowsError(try repo.reminderSettings(other,resolve:false))
        XCTAssertEqual(try repo.reminderSettings(other,resolve:true).object?["committed"]?.json(),"false")
        _ = try repo.reminderSettings(other,resolve:false)
        try open();XCTAssertEqual(try repo.reminderContext().preferences.minute,600)
        var changed=try CoreSchema.object(CanonicalParser.parse(request));changed["values"] = .object([:])
        XCTAssertThrowsError(try repo.reminderSettings(CanonicalValue.object(changed).json(),resolve:false))
    }
    func testReminderPlanningRetryPastIdentityAndTapRevalidation() async throws {
        defer{removeReminderLedger()}
        try execute(0);try execute(1)
        _ = try repo.reminderSettings(reminderRequest(),resolve:false)
        let center=FakeReminderCenter();center.failAdd=true
        var clock=now, zone=TimeZone(secondsFromGMT:0)!
        let coordinator=ReminderCoordinator(core:repo,center:center,now:{clock},zone:{zone})
        let first=try CanonicalParser.parse(await coordinator.reconcile())
        XCTAssertEqual(first.object?["state"]?.text,"partial")
        let second=try CanonicalParser.parse(await coordinator.reconcile())
        XCTAssertEqual(second.object?["state"]?.text,"complete")
        let request=try XCTUnwrap(center.requests.values.first),ids=Set(center.requests.keys)
        _ = await coordinator.reconcile();XCTAssertEqual(Set(center.requests.keys),ids)
        clock=request.fireAt.addingTimeInterval(60);zone=TimeZone(identifier:"Pacific/Honolulu")!
        center.requests=[:]
        _ = await coordinator.reconcile();XCTAssertTrue(center.requests.isEmpty)
        try await coordinator.retainTap(requestID:request.identifier,payload:request.payloadJSON)
        let tap=try CanonicalParser.parse(await coordinator.readTap())
        XCTAssertEqual(try tap.object?["current"]?.json(),"true")
        let before=try allRows("care_events")
        try repo.queue.sync{try repo.database!.transaction{try $0.execute("UPDATE heads SET revision=revision+1")}}
        let stale=try CanonicalParser.parse(await coordinator.readTap());XCTAssertEqual(try stale.object?["current"]?.json(),"false")
        XCTAssertEqual(try allRows("care_events"),before)
        try await coordinator.acknowledgeTap(CoreSchema.string(tap.object?["eventId"]))
        let emptyTap=try await coordinator.readTap();XCTAssertEqual(emptyTap,"null")
        await coordinator.closeForTests()
    }
    func testReminderCapacityDelayedRemovalAndMutationDuringAdd() async throws {
        defer{removeReminderLedger()}
        try execute(0);try execute(1);_ = try repo.reminderSettings(reminderRequest(),resolve:false)
        let center=FakeReminderCenter(),coordinator=ReminderCoordinator(core:repo,center:center,budget:1,now:{self.now},zone:{TimeZone(secondsFromGMT:0)!})
        center.others=["foreign"]
        let full=try CanonicalParser.parse(await coordinator.reconcile());XCTAssertEqual(full.object?["omittedCapacity"]?.integer,1);XCTAssertTrue(center.requests.isEmpty)
        center.others=[];_ = await coordinator.reconcile();XCTAssertEqual(center.requests.count,1)
        let old=Set(center.requests.keys)
        _ = try repo.reminderSettings(reminderRequest(minute:600),resolve:false);center.delayRemoval=true
        let partial=try CanonicalParser.parse(await coordinator.reconcile());XCTAssertEqual(partial.object?["state"]?.text,"partial");XCTAssertEqual(Set(center.requests.keys),old)
        center.delayRemoval=false
        var changed=false
        center.onAdd={if !changed {changed=true;_ = try self.repo.reminderSettings(self.reminderRequest(enabled:false),resolve:false)}}
        _ = await coordinator.reconcile();XCTAssertTrue(center.requests.isEmpty)
        XCTAssertEqual(try repo.reminderContext().preferences.enabled,false)
        await coordinator.closeForTests()
    }
    func testReminderPermissionNoScheduleDeniedAndImportLease() async throws {
        defer{removeReminderLedger()}
        let center=FakeReminderCenter();center.permission="notDetermined"
        let coordinator=ReminderCoordinator(core:repo,center:center,now:{self.now},zone:{TimeZone(secondsFromGMT:0)!})
        do {_ = try await coordinator.requestPermission(context:"settings");XCTFail("No schedule")} catch {}
        XCTAssertEqual(center.prompts,0)
        try execute(0);try execute(1)
        _ = try await coordinator.requestPermission(context:"settings");_ = try await coordinator.requestPermission(context:"settings")
        XCTAssertEqual(center.prompts,1);XCTAssertEqual(center.permission,"denied")
        _ = try repo.reminderSettings(reminderRequest(),resolve:false)
        let denied=try CanonicalParser.parse(await coordinator.reconcile());XCTAssertEqual(denied.object?["state"]?.text,"denied")
        XCTAssertFalse(try allRows("plants").isEmpty)
        center.permission="authorized"
        center.onAdd={XCTAssertFalse(self.repo.platformLeases.isEmpty)}
        _ = await coordinator.reconcile()
        XCTAssertTrue(repo.platformLeases.isEmpty)
        await coordinator.closeForTests()
    }
}

extension ReminderCoordinator {
    func closeForTests() {try? ledger?.db.close();ledger=nil}
}

extension CoreRepositoryTests {
    func testReminderLedgerUnknownTransactionsRecoverAndCurrentIssuedSurvivesPruning() throws {
        var fault:SQLiteBoundary?
        let ledger=try ReminderLedger(directory,fault:{if fault==$0 {fault=nil;throw StorageFailure.unavailable}})
        defer{try? ledger.db.close();removeReminderLedger()}
        try execute(0);try execute(1)
        let context=try repo.reminderContext(),head=ReminderHead(headId:UUID().uuidString.lowercased(),headRevision:1)
        let group=ReminderGroup(fire:now.addingTimeInterval(3600),heads:[head])
        try ledger.db.transaction{sql in for i in 0..<600 {
            try sql.execute("INSERT INTO issued VALUES(?,?,?,?)",[.text("historic\(i)"),.text("null"),.text(ReminderPlan.instant(now.addingTimeInterval(86400))),.text(ReminderPlan.instant(now.addingTimeInterval(-60)))])
        }}
        fault = .afterCommit
        XCTAssertThrowsError(try ledger.persist([group],context:context,zone:"Etc/UTC",now:now))
        try ledger.recover()
        let requests=try ledger.persist([group],context:context,zone:"Etc/UTC",now:now),request=try XCTUnwrap(requests.first)
        XCTAssertTrue(try ledger.issued(request.identifier,payload:request.payloadJSON))
        XCTAssertEqual(try ledger.db.read{try $0.query("SELECT count(*) FROM issued")},[[.integer(513)]])
        fault = .afterCommit
        XCTAssertThrowsError(try ledger.result(.object(["state":.string("complete")])))
        try ledger.recover();XCTAssertEqual(try ledger.lastResult(dataset:context.dataset).object?["state"]?.text,"complete")
        fault = .afterCommit
        XCTAssertThrowsError(try ledger.retainTap(requestID:request.identifier,payload:request.payloadJSON,now:now))
        try ledger.recover();try ledger.retainTap(requestID:request.identifier,payload:request.payloadJSON,now:now)
        XCTAssertEqual(try ledger.db.read{try $0.query("SELECT count(*) FROM taps")},[[.integer(1)]])
        for i in 0..<40 {try ledger.retainTap(requestID:"tap\(i)",payload:"null",now:now.addingTimeInterval(Double(i+1)))}
        XCTAssertEqual(try ledger.db.read{try $0.query("SELECT count(*) FROM taps")},[[.integer(32)]])
        XCTAssertNil(try ledger.tap(now:now.addingTimeInterval(8*86400)))
    }
}

extension CoreRepositoryTests {
    func testReminderInFlightAddBlocksReplacementThenRebuildsNewDataset() async throws {
        defer{removeBackupSidecars();removeReminderLedger()}
        let fixture=try recoveryFixture()
        _ = try repo.reminderSettings(reminderRequest(),resolve:false)
        let (id,preview)=try previewBackup(fixture.zip)
        let center=FakeReminderCenter(),coordinator=ReminderCoordinator(core:repo,center:center,now:{self.now},zone:{TimeZone(secondsFromGMT:0)!})
        var attempted=false
        center.onAdd={
            guard !attempted else{return};attempted=true
            _ = try self.backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
            self.repo.backupEngine.worker.sync{}
            let status=try self.backup("backupStatus",["operationId":.string(id)])
            XCTAssertEqual(status.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
            XCTAssertEqual(status.object?["operation"]?.object?["state"]?.object?["code"]?.text,"BUSY")
        }
        _ = await coordinator.reconcile();XCTAssertTrue(attempted);XCTAssertFalse(center.requests.isEmpty)
        let old=dataset
        _ = try backup("retryImport",["operationId":.string(id)])
        let fresh=try XCTUnwrap(awaitBackup(id).object?["operation"]?.object?["state"]?.object?["preview"])
        _ = try backup("confirmImport",["operationId":.string(id),"preview":fresh,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertNotEqual(dataset,old)
        _ = await coordinator.reconcile();XCTAssertTrue(center.requests.isEmpty)
        await coordinator.closeForTests()
    }
    func testReminderUnknownOutboxAcknowledgementRecoversWithoutUndoingCare() async throws {
        defer{removeReminderLedger()}
        try execute(0);try execute(1);_ = try repo.reminderSettings(reminderRequest(),resolve:false)
        let rows=try allRows("plants"),center=FakeReminderCenter(),coordinator=ReminderCoordinator(core:repo,center:center,now:{self.now},zone:{TimeZone(secondsFromGMT:0)!})
        // No core writes occur before clean-outbox acknowledgement in this pass.
        failure = .afterCommit
        let first=try CanonicalParser.parse(await coordinator.reconcile());XCTAssertEqual(first.object?["state"]?.text,"deferred")
        let retry=try CanonicalParser.parse(await coordinator.reconcile());XCTAssertEqual(retry.object?["state"]?.text,"complete")
        XCTAssertEqual(try allRows("plants"),rows)
        await coordinator.closeForTests()
    }
}
