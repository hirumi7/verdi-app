import Foundation
import XCTest
import Darwin
@testable import VerdiNative

/// Armed only while workers are drained; inspection uses a lock across queues.
final class BackupFaultLatch {
    private let lock = NSLock()
    private var remaining: Int
    private var hits = 0
    init(_ failures: Int = 1) {remaining = failures}
    func take() -> Bool {
        lock.lock();defer{lock.unlock()};hits += 1
        if remaining == 0 {return false};remaining -= 1;return true
    }
    var count: Int {lock.lock();defer{lock.unlock()};return hits}
}

extension BackupParserTests {
    func testBackupWriterShortWritesAndEINTRPreserveExactBytes() throws {
        let target = root.appendingPathComponent("short"), bytes = Data((0..<200000).map{UInt8($0 % 251)})
        var calls = 0
        let io = BackupFileIO(write:{fd,pointer,count in
            calls += 1
            if calls % 7 == 1 {errno = EINTR;return -1}
            return Darwin.write(fd,pointer,min(count,997))
        })
        let output = try BackupWriter(target,limit:Int64(bytes.count),io:io)
        try output.write(bytes);try output.finish()
        XCTAssertEqual(try Data(contentsOf:target),bytes);XCTAssertEqual(output.count,Int64(bytes.count))
        XCTAssertGreaterThan(calls,200)
    }
    func testBackupWriterPartialDiskFullCannotFinishOrWriteAgain() throws {
        let target = root.appendingPathComponent("disk-full")
        var calls = 0
        let output = try BackupWriter(target,limit:32,io:BackupFileIO(write:{fd,pointer,count in
            calls += 1
            if calls == 1 {return Darwin.write(fd,pointer,min(count,3))}
            errno = ENOSPC;return -1
        }))
        XCTAssertThrowsError(try output.write("abcdef")) {XCTAssertEqual(BackupEngine.code($0),"DISK_FULL")}
        XCTAssertThrowsError(try output.finish())
        XCTAssertThrowsError(try output.write("g"))
        XCTAssertEqual(try Data(contentsOf:target),Data("abc".utf8))
        XCTAssertEqual(calls,2)
    }
    func testBackupWriterFlushCloseAndParentFailuresNeverFinish() throws {
        for boundary: BackupFileBoundary in [.fileSync,.fullSync,.close,.directorySync] {
            let output = try BackupWriter(root.appendingPathComponent(String(describing:boundary)),limit:32,io:BackupFileIO(fault:{point,_ in
                if point == boundary {throw CoreRepositoryError("DURABILITY_UNAVAILABLE")}
            }))
            try output.write("complete bytes")
            XCTAssertThrowsError(try output.finish())
            XCTAssertThrowsError(try output.finish())
            XCTAssertThrowsError(try output.write("again"))
        }
    }
}

extension CoreRepositoryTests {
    func saveIORecoveryDraft(note:String) throws -> [[SQLValue]] {
        var fields = try CoreSchema.object(steps[0]["intent"]?.object?["normalisedPayload"]?.object?["rawFields"])
        fields["notes"] = .string(note)
        let existing = try allRows("plant_drafts").first
        let draftID = try existing.map {try CoreSchema.text($0[0])} ?? UUID().uuidString.lowercased()
        var plan = try draftPlan(fields:fields,draftID:draftID,expected:try existing.map {try CoreSchema.integer($0[1])})
        plan["expectedCollectionRevision"] = try repo.queue.sync {try repo.database!.read {CoreSchema.canonical(try $0.query("SELECT collection_revision FROM metadata")[0][0])}}
        var saved = plan["result"]!.object!;saved["collectionRevision"] = plan["expectedCollectionRevision"];plan["result"] = .object(saved)
        _ = try call("commit",["plan":.object(rehash(plan))])
        return try allRows("plant_drafts")
    }

    func testBackupControlCommitFailureMatrixRecoversSameOwner() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture()
        for step: BackupControlWrite in [.prepare,.switchPointer,.verify] {
            for boundary: SQLiteBoundary in [.beforeCommit,.afterCommit] {
                let old = dataset, rows = try allRows("plants"), latch = BackupFaultLatch()
                let (id,preview) = try previewBackup(fixture.zip)
                repo.backupEngine.worker.sync{}
                try repo.backupControl!.db.close();repo.backupControl=nil
                repo.backupControlFault = {operation,point in
                    if operation == step && point == boundary && latch.take() {throw StorageFailure.sqlite(13)}
                }
                _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
                repo.backupEngine.worker.sync{}
                XCTAssertGreaterThan(latch.count,0)
                let result = try backup("backupStatus",["operationId":.string(id)])
                let state = try XCTUnwrap(result.object?["operation"]?.object?["state"]?.object)
                let committed = boundary == .afterCommit && step != .prepare
                XCTAssertEqual(state["kind"]?.text,committed ? "complete":"failed", "\(step)/\(boundary)")
                try open()
                if committed {
                    XCTAssertNotEqual(dataset,old);XCTAssertEqual(try allRows("plants"),fixture.newRows)
                    XCTAssertEqual(try Data(contentsOf:repo.directory.appendingPathComponent(fixture.newPath)),fixture.newBytes)
                    let replay = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
                    XCTAssertEqual(replay.object?["operationId"]?.text,id)
                    XCTAssertEqual(replay.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
                } else {XCTAssertEqual(dataset,old);XCTAssertEqual(try allRows("plants"),rows)}
                let drafts = try saveIORecoveryDraft(note:"After \(step)/\(boundary)"), identity = dataset
                try closeRecoveryFixture()
                repo = CoreRepository(directory:directory,fault:nil,now:{self.now})
                try open();XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plant_drafts"),drafts)
            }
        }
    }
}

extension CoreRepositoryTests {
    func testBackupExportFileFaultsPreserveCollectionAndPermitNewExport() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset
        let cases: [(BackupFileBoundary,String)] = [(.directoryCreate,"verify"),(.directoryCreated,"verify"),(.protection,"verify"),(.write,"data.json"),(.fileSync,"data.json"),(.fullSync,"manifest.json"),(.close,"Verdi-backup.zip"),(.directorySync,"")]
        for (boundary,name) in cases {
            let latch = BackupFaultLatch()
            repo.backupFileIO = BackupFileIO(fault:{point,url in
                if point == boundary && (name.isEmpty || url.lastPathComponent == name) && latch.take() {throw StorageFailure.filesystem(ENOSPC)}
            })
            let id = UUID().uuidString.lowercased()
            _ = try backup("startExport",["operationId":.string(id),"datasetId":.string(dataset)])
            let state = try awaitBackup(id).object?["operation"]?.object?["state"]?.object
            XCTAssertGreaterThan(latch.count,0);XCTAssertEqual(state?["kind"]?.text,"failed");XCTAssertEqual(state?["code"]?.text,"DISK_FULL")
            XCTAssertNil(state?["exportHandle"])
            XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
            XCTAssertTrue(FileManager.default.fileExists(atPath:fixture.oldPhoto.path))
            _ = try exportBackup()
        }
    }

    func testBackupImportFileFaultsRetrySameOperationWithoutChangingOldData() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset, original = try Data(contentsOf:fixture.oldPhoto)
        let cases: [(BackupFileBoundary,String)] = [(.directoryCreate,""),(.directoryCreated,""),(.protection,""),(.write,"png"),(.fileSync,"data.json"),(.fullSync,"png"),(.close,"initialized"),(.directorySync,"")]
        for (boundary,name) in cases {
            let latch = BackupFaultLatch()
            repo.backupFileIO = BackupFileIO(fault:{point,url in
                let match = name.isEmpty ? url.path.contains("-generations/") : name == "png" ? url.pathExtension == "png" : url.lastPathComponent == name
                if point == boundary && match && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
            })
            let selection = try repo.retainBackupSelection(source:fixture.zip), id = UUID().uuidString.lowercased()
            _ = try backup("startImport",["operationId":.string(id),"selectionHandle":.string(selection)])
            let state = try awaitBackup(id).object?["operation"]?.object?["state"]?.object
            XCTAssertGreaterThan(latch.count,0);XCTAssertEqual(state?["kind"]?.text,"failed")
            XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
            XCTAssertEqual(try Data(contentsOf:fixture.oldPhoto),original)
            _ = try backup("retryImport",["operationId":.string(id)])
            let retry = try awaitBackup(id)
            XCTAssertEqual(retry.object?["operationId"]?.text,id)
            XCTAssertEqual(retry.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"preview_ready")
            _ = try backup("cancelBackup",["operationId":.string(id)])
        }
    }

    func testBackupConfirmFlushFailureKeepsOldAndCanRevalidate() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset
        let (id,preview) = try previewBackup(fixture.zip), latch = BackupFaultLatch()
        repo.backupFileIO = BackupFileIO(fault:{point,url in
            if point == .fullSync && url.lastPathComponent == "core.sqlite" && latch.take() {throw CoreRepositoryError("DURABILITY_UNAVAILABLE")}
        })
        _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["failed","complete"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        XCTAssertGreaterThan(latch.count,0);XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
        _ = try backup("retryImport",["operationId":.string(id)])
        let next = try XCTUnwrap(awaitBackup(id).object?["operation"]?.object?["state"]?.object?["preview"])
        _ = try backup("confirmImport",["operationId":.string(id),"preview":next,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["failed","complete"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertNotEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.newRows)
    }

    func testBackupBootstrapFileFaultsRetainLegacyAndIsolateOtherRepository() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let identity = dataset, rows = try allRows("plants")
        let cases: [(BackupFileBoundary,String)] = [(.directoryCreate,directory.lastPathComponent+"-recovery"),(.directoryCreated,directory.lastPathComponent+"-recovery"),(.protection,directory.lastPathComponent+"-recovery"),(.write,"bootstrap.pending"),(.fileSync,"bootstrap.pending"),(.fullSync,"control.pending"),(.rename,"bootstrap.json"),(.renamed,"bootstrap.json"),(.renamed,"control.sqlite"),(.close,"established")]
        for (boundary,name) in cases {
            let latch = BackupFaultLatch()
            repo.backupFileIO = BackupFileIO(fault:{point,url in
                if point == boundary && url.lastPathComponent == name && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
            })
            XCTAssertThrowsError(try backup("latestBackupOperation"))
            XCTAssertGreaterThan(latch.count,0)
            XCTAssertEqual(try allRows("plants"),rows)
            // A different repository has real defaults, not a global injected fault.
            let otherRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            let other = CoreRepository(directory:otherRoot)
            let opened = try CanonicalParser.parse(other.call(operation:"open",body:"{\"profile\":\"custom_core_v1\",\"protocolVersion\":1}"))
            _ = try other.backupCall(method:"latestBackupOperation",request:"{}")
            _ = try other.call(operation:"close",body:CanonicalValue.object(["sessionId":opened.object!["sessionId"]!]).json())
            other.backupEngine.worker.sync{};other.mediaWorker.sync{};try other.backupControl?.db.close();other.backupControl=nil
            for suffix in ["","-recovery","-generations"] {try FileManager.default.removeItem(at:URL(fileURLWithPath:otherRoot.path+suffix))}
            try open();_ = try backup("latestBackupOperation")
            XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),rows)
            removeBackupSidecars();try open()
        }
    }

    func testBackupCleanupRetriesParentSyncAfterFileWasRemoved() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset
        let (id,zip) = try exportBackup(), control = repo.backupControl!
        try control.db.transaction {try $0.execute("UPDATE artifacts SET expires='1970-01-01T00:00:00.000Z' WHERE key=?",[.text(id)])}
        for boundary: BackupFileBoundary in [.remove,.directorySync] {
            let latch = BackupFaultLatch()
            repo.backupFileIO = BackupFileIO(fault:{point,url in
                if point == boundary && (point == .remove ? url.lastPathComponent == id : url.lastPathComponent == "jobs") && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
            })
            XCTAssertThrowsError(try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(control)})
            XCTAssertGreaterThan(latch.count,0)
            XCTAssertEqual(try control.db.read {try $0.query("SELECT key FROM artifacts WHERE key=?",[.text(id)]).count},1)
            XCTAssertEqual(try allRows("plants"),fixture.oldRows);XCTAssertEqual(dataset,identity)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath:zip.path))
        let retried = BackupFaultLatch(0)
        repo.backupFileIO = BackupFileIO(fault:{point,url in if point == .directorySync && url.lastPathComponent == "jobs" {_ = retried.take()} })
        try repo.backupEngine.worker.sync {try repo.backupEngine.cleanup(control)}
        XCTAssertGreaterThan(retried.count,0)
        XCTAssertEqual(try control.db.read {try $0.query("SELECT key FROM artifacts WHERE key=?",[.text(id)]).count},0)
        try open();XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
    }
}

extension CoreRepositoryTests {
    func testBackupControlRollbackFailureRetiresConnectionAndRecovers() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset
        let (id,preview) = try previewBackup(fixture.zip)
        let commit = BackupFaultLatch(), rollback = BackupFaultLatch()
        try repo.backupControl!.db.close();repo.backupControl=nil
        repo.backupControlFault = {step,point in
            if step == .prepare && point == .beforeCommit && commit.take() {throw StorageFailure.sqlite(13)}
            if step == .prepare && point == .beforeRollback && rollback.take() {throw StorageFailure.unavailable}
        }
        _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        repo.backupEngine.worker.sync{}
        let state = try backup("backupStatus",["operationId":.string(id)]).object?["operation"]?.object?["state"]?.object
        XCTAssertGreaterThan(commit.count,0);XCTAssertGreaterThan(rollback.count,0)
        XCTAssertEqual(state?["kind"]?.text,"failed")
        try open();XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
        XCTAssertEqual(try repo.backupControl!.db.read {try $0.query("SELECT * FROM replacement").count},0)
    }

    func testBackupRollbackCommitFailuresPreserveBothSetsAndRetry() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset, bytes = try Data(contentsOf:fixture.oldPhoto)
        for boundary: SQLiteBoundary in [.beforeCommit,.afterCommit] {
            let (id,preview) = try previewBackup(fixture.zip), latch = BackupFaultLatch(), corruption = BackupFaultLatch()
            let control = repo.backupControl!
            let candidateID = try control.db.read {try CoreSchema.text($0.query("SELECT new_generation FROM jobs WHERE id=?",[.text(id)])[0][0])}
            let candidate = control.generations.appendingPathComponent(candidateID), photo = candidate.appendingPathComponent(fixture.newPath)
            try control.db.close();repo.backupControl=nil
            repo.backupControlFault = {step,point in if step == .rollback && point == boundary && latch.take() {throw StorageFailure.unavailable} }
            repo.backupFault = {point in
                if point == .switched && corruption.take() {try Data("damaged candidate".utf8).write(to:photo);throw CoreRepositoryError("IO_FAILURE")}
            }
            _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
            repo.backupEngine.worker.sync{}
            let state = try backup("backupStatus",["operationId":.string(id)]).object?["operation"]?.object?["state"]?.object
            XCTAssertGreaterThan(latch.count,0);XCTAssertEqual(state?["kind"]?.text,"failed")
            repo.backupFault=nil;try open()
            XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
            XCTAssertEqual(try Data(contentsOf:fixture.oldPhoto),bytes)
            XCTAssertEqual(try Data(contentsOf:photo),Data("damaged candidate".utf8))
            XCTAssertTrue(FileManager.default.fileExists(atPath:candidate.appendingPathComponent("core.sqlite").path))
            XCTAssertEqual(try repo.backupControl!.db.read {try $0.query("SELECT phase FROM replacement")[0][0]},.text("rolled_back"))
            let drafts = try saveIORecoveryDraft(note:"Recovered rollback \(boundary)")
            try open();XCTAssertEqual(try allRows("plant_drafts"),drafts)
        }
    }

    func testBackupControlReconnectFailurePreservesUnknownResultAndExplicitClose() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1);_ = try backup("latestBackupOperation")
        repo.backupEngine.worker.sync{}
        let control = repo.backupControl!, id = UUID().uuidString.lowercased(), pointer = try control.activeID()
        XCTAssertThrowsError(try control.db.transaction(fault:{if $0 == .afterCommit {throw StorageFailure.unavailable}}) {
            try $0.execute("INSERT INTO artifacts VALUES('job',?,?,?)",[.text(id),.text(id),.text("2099-01-01T00:00:00.000Z")])
        }) {XCTAssertEqual($0 as? StorageFailure,.unknownOutcome)}
        XCTAssertThrowsError(try control.activeID())
        let parked = control.root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
        try FileManager.default.moveItem(at:control.root,to:parked)
        XCTAssertThrowsError(try control.recoverConnection())
        XCTAssertFalse(FileManager.default.fileExists(atPath:control.root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath:parked.appendingPathComponent("control.sqlite").path))
        try FileManager.default.moveItem(at:parked,to:control.root)
        try control.recoverConnection()
        XCTAssertTrue(control === repo.backupControl)
        XCTAssertEqual(try control.activeID(),pointer)
        XCTAssertEqual(try control.db.read {try $0.query("SELECT key FROM artifacts WHERE key=?",[.text(id)]).count},1)
        let diagnostics = try control.db.diagnostics()
        XCTAssertEqual(diagnostics.journalMode,"delete");XCTAssertEqual(diagnostics.synchronous,3)
        try control.db.close()
        XCTAssertThrowsError(try control.recoverConnection())
        repo.backupControl=nil
        try open();XCTAssertEqual(try allRows("plants").count,1)
    }
}

extension CoreRepositoryTests {
    func testBackupSourceRenameFailureRetriesAfterRestartWithoutReselection() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset
        for boundary: BackupFileBoundary in [.rename,.renamed,.directorySync] {
            let latch = BackupFaultLatch()
            repo.backupFileIO = BackupFileIO(fault:{point,url in
                let match = point == .directorySync ? url.deletingLastPathComponent().lastPathComponent == "jobs" : url.lastPathComponent == "source.zip"
                if point == boundary && match && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
            })
            let handle = try repo.retainBackupSelection(source:fixture.zip), id = UUID().uuidString.lowercased()
            _ = try backup("startImport",["operationId":.string(id),"selectionHandle":.string(handle)])
            XCTAssertEqual(try awaitBackup(id).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
            XCTAssertGreaterThan(latch.count,0);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
            try closeRecoveryFixture();repo = CoreRepository(directory:directory,fault:nil,now:{self.now});try open()
            let retried = BackupFaultLatch(0)
            repo.backupFileIO = BackupFileIO(fault:{point,_ in if point == .directorySync {_ = retried.take()} })
            let response = try backup("retryImport",["operationId":.string(id)])
            XCTAssertNotEqual(response.object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
            XCTAssertEqual(try awaitBackup(id).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"preview_ready")
            XCTAssertGreaterThan(retried.count,0)
            _ = try backup("cancelBackup",["operationId":.string(id)])
            XCTAssertEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.oldRows)
        }
    }
}

extension CoreRepositoryTests {
    func testBackupSameIDRetryAfterRollbackRecordsNewFailuresAndEventuallyCompletes() throws {
        defer{removeBackupSidecars()}
        let fixture = try recoveryFixture(), identity = dataset, rollback = BackupFaultLatch()
        let (id,preview) = try previewBackup(fixture.zip)
        repo.backupFault = {point in if point == .prepared && rollback.take() {throw CoreRepositoryError("IO_FAILURE")} }
        try repo.backupControl!.db.close();repo.backupControl=nil
        _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["failed","complete"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        try open();XCTAssertEqual(dataset,identity)
        let validation = BackupFaultLatch()
        repo.backupFileIO = BackupFileIO(fault:{point,url in
            if point == .write && url.pathExtension == "png" && validation.take() {throw CoreRepositoryError("IO_FAILURE")}
        })
        _ = try backup("retryImport",["operationId":.string(id)])
        repo.backupEngine.worker.sync{}
        XCTAssertGreaterThan(validation.count,0)
        XCTAssertEqual(try backup("backupStatus",["operationId":.string(id)]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        _ = try backup("retryImport",["operationId":.string(id)])
        let next = try XCTUnwrap(awaitBackup(id).object?["operation"]?.object?["state"]?.object?["preview"])
        let flush = BackupFaultLatch()
        repo.backupFileIO = BackupFileIO(fault:{point,url in
            if point == .fullSync && url.lastPathComponent == "core.sqlite" && flush.take() {throw CoreRepositoryError("DURABILITY_UNAVAILABLE")}
        })
        _ = try backup("confirmImport",["operationId":.string(id),"preview":next,"confirmed":.boolean(true)])
        repo.backupEngine.worker.sync{}
        XCTAssertGreaterThan(flush.count,0)
        XCTAssertEqual(try backup("backupStatus",["operationId":.string(id)]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"failed")
        XCTAssertEqual(try allRows("plants"),fixture.oldRows)
        _ = try backup("retryImport",["operationId":.string(id)])
        let final = try XCTUnwrap(awaitBackup(id).object?["operation"]?.object?["state"]?.object?["preview"])
        _ = try backup("confirmImport",["operationId":.string(id),"preview":final,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["failed","complete"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertNotEqual(dataset,identity);XCTAssertEqual(try allRows("plants"),fixture.newRows)
    }
}
