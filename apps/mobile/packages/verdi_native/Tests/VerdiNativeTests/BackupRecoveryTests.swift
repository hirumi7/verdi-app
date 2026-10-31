import Foundation
import XCTest
@testable import VerdiNative

extension CoreRepositoryTests {
    /// Only synthetic test data: the archive and live collection deliberately differ.
    func recoveryFixture() throws -> (zip: URL, oldRows: [[SQLValue]], newRows: [[SQLValue]], oldPhoto: URL, newPath: String, newBytes: Data) {
        let (photoID, photo) = try seedSavedPhoto()
        let newRows = try allRows("plants"), newPath = try CoreSchema.text(allRows("photos")[0][4])
        let newBytes = try Data(contentsOf: photo)
        let (_, zip) = try exportBackup()
        let source = try XCTUnwrap(Bundle.module.url(forResource: "media-green", withExtension: "png", subdirectory: "Fixtures/catalog"))
        let files = try MediaFiles(root: directory)
        try files.importSelection(source, to: "staging/old.copy")
        let info = try files.inspect("staging/old.copy")
        XCTAssertNotEqual(info.hash, try BackupIO.hash(photo).0)
        let oldPath = "media/\(photoID)/\(info.hash).png"
        try files.publish("staging/old.copy", to: oldPath)
        try repo.queue.sync { try repo.database!.transaction { sql in
            try sql.execute("UPDATE plants SET name='Retained old collection',notes='Edits after export'")
            try sql.execute("UPDATE photos SET content_path=?,sha256=?,byte_count=?,mime=?,width=?,height=?", [.text(oldPath),.text(info.hash),.integer(info.bytes),.text(info.mime),.integer(info.width),.integer(info.height)])
            try sql.execute("DELETE FROM media_files WHERE relative_path=?", [.text(newPath)])
            try repo.registerMediaPath(sql, oldPath)
        }}
        // Validate both datasets through the real export/self-validation path.
        _ = try exportBackup()
        return (zip, try allRows("plants"), newRows, directory.appendingPathComponent(oldPath), newPath, newBytes)
    }

    func writeOtherRecoveryDatabase(to target: URL, version: Int32 = 4) throws {
        let scratch = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let other = try SQLiteDatabase.create(at: scratch, schema: CoreSchema.schema(dataset: UUID().uuidString.lowercased(), instant: mediaInstant(), version: version))
        try other.close()
        try Data(contentsOf: scratch).write(to: target)
        try FileManager.default.removeItem(at: scratch)
    }

    func closeRecoveryFixture() throws {
        repo.backupEngine.worker.sync{}
        repo.mediaWorker.sync{}
        if !repo.sessionID.isEmpty { try repo.queue.sync { try repo.database?.checkpoint() } }
        _ = try? call("close")
        try repo.backupControl?.db.close()
        repo.backupControl = nil
    }

    func testBackupRegisteredStorageNeverReinitializesOrAcceptsWrongDataset() throws {
        defer { removeBackupSidecars() }
        let fixture = try recoveryFixture(), oldDataset = dataset
        // Exercise both registered legacy and a successfully restored generation.
        for restored in [false, true] {
            if restored {
                let (id, preview) = try previewBackup(fixture.zip)
                _ = try backup("confirmImport", ["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
                XCTAssertEqual(try awaitBackup(id, terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text, "complete")
                try open()
                XCTAssertNotEqual(dataset, oldDataset)
            }
            let root = repo.directory, identity = dataset, rows = try allRows("plants")
            let pointer = try repo.backupControl!.activeID()
            for damage in ["directory", "emptyDirectory", "marker", "database", "corruptDatabase", "wrongDataset", "wrongLegacy1", "wrongLegacy2", "wrongLegacy3"] {
                try closeRecoveryFixture()
                let parked = root.deletingLastPathComponent().appendingPathComponent(UUID().uuidString)
                defer { if FileManager.default.fileExists(atPath: parked.path) { try? FileManager.default.removeItem(at: parked) } }
                let target = damage == "marker" ? root.appendingPathComponent("initialized") : root.appendingPathComponent("core.sqlite")
                if ["directory", "emptyDirectory"].contains(damage) {
                    try FileManager.default.moveItem(at: root, to: parked)
                    if damage == "emptyDirectory" { try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
                } else {
                    try FileManager.default.moveItem(at: target, to: parked)
                    if damage == "corruptDatabase" { try Data("broken database".utf8).write(to: target) }
                    if damage.hasPrefix("wrong") {
                        let version: Int32 = damage == "wrongDataset" ? 4 : Int32(String(damage.last!))!
                        try writeOtherRecoveryDatabase(to: target, version: version)
                    }
                }
                let rejectedBytes = damage.hasPrefix("wrong") ? try Data(contentsOf: target) : nil
                assertCode("STORAGE_UNAVAILABLE") { try open() }
                if let rejectedBytes { XCTAssertEqual(try Data(contentsOf: target), rejectedBytes, "Rejection must precede migration") }
                XCTAssertTrue(repo.sessionID.isEmpty, damage)
                XCTAssertEqual(try repo.backupControl!.activeID(), pointer, damage)
                if damage == "directory" { XCTAssertFalse(FileManager.default.fileExists(atPath: root.path)) }
                if damage == "emptyDirectory" { XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), []) }
                if damage == "database" || damage == "marker" { XCTAssertFalse(FileManager.default.fileExists(atPath: target.path)) }
                try closeRecoveryFixture()
                if ["directory", "emptyDirectory"].contains(damage) {
                    if FileManager.default.fileExists(atPath: root.path) { try FileManager.default.removeItem(at: root) }
                    try FileManager.default.moveItem(at: parked, to: root)
                } else {
                    // Keep the original WAL sidecars; only the selected test file
                    // was damaged. Deleting sidecars would alter the repair fixture.
                    if FileManager.default.fileExists(atPath: target.path) { try FileManager.default.removeItem(at: target) }
                    try FileManager.default.moveItem(at: parked, to: target)
                }
                try open()
                XCTAssertEqual(dataset, identity); XCTAssertEqual(try allRows("plants"), rows)
            }
        }
    }

    func testBackupVerifiedRestartPreservesLaterWritesAndMissingPhoto() throws {
        defer { removeBackupSidecars() }
        let fixture = try recoveryFixture(), (id, preview) = try previewBackup(fixture.zip)
        _ = try backup("confirmImport", ["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id, terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text, "complete")
        try open()
        let identity = dataset
        _ = try repo.queue.sync { try repo.database!.transaction { try $0.execute("UPDATE plants SET notes='After verified restore'") } }
        let rows = try allRows("plants")
        try FileManager.default.removeItem(at: repo.directory.appendingPathComponent(fixture.newPath))
        try closeRecoveryFixture(); try open()
        XCTAssertEqual(dataset, identity); XCTAssertEqual(try allRows("plants"), rows)
        let exportID = UUID().uuidString.lowercased()
        _ = try backup("startExport", ["operationId":.string(exportID),"datasetId":.string(dataset)])
        XCTAssertEqual(try awaitBackup(exportID).object?["operation"]?.object?["state"]?.object?["kind"]?.text, "failed")
        XCTAssertEqual(try allRows("plants"), rows)
    }
}

#if os(macOS)
extension CoreRepositoryTests {
    func crashRestore(_ zip: URL, boundary: String) throws {
        try closeRecoveryFixture()
        let child = Process(); child.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        child.arguments = ["xctest", "-XCTest", "VerdiNativeTests.BackupCrashWorkerTests/testCrashWorker", Bundle(for: BackupCrashWorkerTests.self).bundleURL.path]
        var env = ProcessInfo.processInfo.environment
        env["VERDI_CRASH_ROOT"] = directory.path; env["VERDI_CRASH_BOUNDARY"] = boundary; env["VERDI_CRASH_ZIP"] = zip.path
        child.environment = env
        let output = Pipe(); child.standardOutput = output; child.standardError = output
        try child.run()
        let log = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        child.waitUntilExit(); XCTAssertEqual(child.terminationStatus, 79, log)
    }

    func testBackupSwitchedCorruptDatabaseRollsBack() throws { try damagedRecovery(newDamage: "database", oldDamage: false) }
    func testBackupSwitchedCorruptPhotoRollsBack() throws { try damagedRecovery(newDamage: "photo", oldDamage: false) }
    func testBackupNeitherGenerationValidBlocksAndRetriesAfterRepair() throws { try damagedRecovery(newDamage: "database", oldDamage: true) }
    func testBackupPreparedInvalidOldDoesNotSelectValidCandidate() throws { try damagedRecovery(newDamage: nil, oldDamage: true, boundary: "prepared") }
    func testBackupSwitchedWrongOldIdentityBlocksRollback() throws { try damagedRecovery(newDamage: "photo", oldDamage: true, wrongIdentity: true) }

    func damagedRecovery(newDamage: String?, oldDamage: Bool, boundary: String = "switched", wrongIdentity: Bool = false) throws {
        defer { removeBackupSidecars() }
        let fixture = try recoveryFixture(), old = dataset, oldPhoto = try Data(contentsOf: fixture.oldPhoto)
        try crashRestore(fixture.zip, boundary: boundary)
        let control = try BackupControl(legacy: directory)
        defer { try? control.db.close() }
        let record = try control.db.read { try $0.query("SELECT * FROM replacement") }
        let newID = try CoreSchema.text(record[0][3]), candidate = try control.generationURL(newID)
        let candidatePhoto = candidate.appendingPathComponent(fixture.newPath), candidateDB = candidate.appendingPathComponent("core.sqlite")
        XCTAssertEqual(try Data(contentsOf: candidatePhoto), fixture.newBytes)
        XCTAssertNotEqual(oldPhoto, fixture.newBytes)
        let oldDB = directory.appendingPathComponent("core.sqlite"), savedDB = try Data(contentsOf: oldDB)
        if newDamage == "database" { try Data("bad candidate".utf8).write(to: candidateDB) }
        if newDamage == "photo" { try Data("bad photo".utf8).write(to: candidatePhoto) }
        if oldDamage {
            if wrongIdentity {
                try writeOtherRecoveryDatabase(to: oldDB)
            } else { try Data("bad old database".utf8).write(to: oldDB) }
            let oldBytes = try Data(contentsOf: oldDB), newBytes = try Data(contentsOf: candidateDB), photoBytes = try Data(contentsOf: candidatePhoto)
            for _ in 0..<2 {
                assertCode("STORAGE_UNAVAILABLE") { try open() }
                XCTAssertTrue(repo.sessionID.isEmpty)
                XCTAssertEqual(try control.db.read { try $0.query("SELECT * FROM replacement") }, record)
                XCTAssertEqual(try control.activeID(), boundary == "prepared" ? try CoreSchema.text(record[0][2]) : newID)
                XCTAssertEqual(try Data(contentsOf: oldDB), oldBytes)
                XCTAssertEqual(try Data(contentsOf: candidateDB), newBytes)
                XCTAssertEqual(try Data(contentsOf: candidatePhoto), photoBytes)
                XCTAssertEqual(try Data(contentsOf: fixture.oldPhoto), oldPhoto)
            }
            try closeRecoveryFixture()
            try savedDB.write(to: oldDB)
        }
        try open()
        XCTAssertEqual(dataset, old); XCTAssertEqual(try allRows("plants"), fixture.oldRows)
        XCTAssertEqual(try Data(contentsOf: fixture.oldPhoto), oldPhoto)
        XCTAssertEqual(try control.db.read { try $0.query("SELECT phase FROM replacement")[0][0] }, .text("rolled_back"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidateDB.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: candidatePhoto.path))
        try closeRecoveryFixture(); try open()
        XCTAssertEqual(dataset, old); XCTAssertEqual(try allRows("plants"), fixture.oldRows)
    }

    func testBackupSwitchedValidDistinctGenerationCompletes() throws {
        defer { removeBackupSidecars() }
        let fixture = try recoveryFixture(), old = dataset, oldBytes = try Data(contentsOf: fixture.oldPhoto)
        try crashRestore(fixture.zip, boundary: "switched")
        try open()
        XCTAssertNotEqual(dataset, old); XCTAssertEqual(try allRows("plants"), fixture.newRows)
        XCTAssertEqual(try Data(contentsOf: repo.directory.appendingPathComponent(fixture.newPath)), fixture.newBytes)
        XCTAssertEqual(try Data(contentsOf: fixture.oldPhoto), oldBytes)
        XCTAssertEqual(try repo.backupControl!.db.read { try $0.query("SELECT phase FROM replacement")[0][0] }, .text("verified"))
    }
}
#endif
