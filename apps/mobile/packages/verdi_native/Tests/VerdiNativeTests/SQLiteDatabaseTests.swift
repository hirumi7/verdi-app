import Dispatch
import Foundation
import SQLite3
import XCTest
@testable import VerdiNative

final class SQLiteDatabaseTests: XCTestCase {
    private var directory: URL!
    private var url: URL { directory.appendingPathComponent("synthetic.sqlite") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    // Distinct synthetic identity; this is not Verdi product schema/version 1.
    private func schema(
        applicationID: Int32 = 0x54535431, version: Int32 = 7001,
        extra: [String] = [], invalidValidator: Bool = false
    ) -> CompiledSchema {
        CompiledSchema(applicationID: applicationID, version: version, statements: [
            "CREATE TABLE metadata (singleton INTEGER PRIMARY KEY CHECK(singleton = 1), marker TEXT NOT NULL)",
            "INSERT INTO metadata VALUES (1, 'synthetic-only')",
            "CREATE TABLE parents (id INTEGER PRIMARY KEY, label TEXT, optional TEXT)",
            "CREATE TABLE children (id INTEGER PRIMARY KEY, parent_id INTEGER NOT NULL REFERENCES parents(id))",
            "CREATE TABLE receipts (command_id TEXT PRIMARY KEY NOT NULL, parent_id INTEGER NOT NULL REFERENCES parents(id))",
        ] + extra, validate: { session in
            guard !invalidValidator,
                  try session.query("SELECT marker FROM metadata WHERE singleton = 1") == [[.text("synthetic-only")]] else {
                throw StorageFailure.schemaMismatch
            }
        })
    }

    private func count(_ database: SQLiteDatabase, table: String = "parents") throws -> Int64 {
        // Table names are test constants, never customer input.
        guard case .integer(let count)? = try database.read({ try $0.query("SELECT COUNT(*) FROM \(table)") }).first?.first else {
            XCTFail("Missing count")
            return -1
        }
        return count
    }

    func testCreateDiagnosticsValuesAndDurableReopen() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        let diagnostics = try database.diagnostics()
        XCTAssertEqual(diagnostics.foreignKeys, 1)
        XCTAssertEqual(diagnostics.journalMode, "wal")
        XCTAssertEqual(diagnostics.synchronous, 2)
        XCTAssertEqual(diagnostics.busyTimeoutMilliseconds, 2500)
        XCTAssertGreaterThan(diagnostics.libraryVersionNumber, 0)
        XCTAssertFalse(diagnostics.compileOptions.isEmpty)
        print("OS SQLite \(diagnostics.libraryVersion) (\(diagnostics.libraryVersionNumber)); options: \(diagnostics.compileOptions.joined(separator: ",")); FK=1 WAL FULL busy=2500")
        let label = "O'Brien 🌿\u{0}tail"
        try database.transaction { session in
            XCTAssertEqual(try session.execute("INSERT INTO parents VALUES (?, ?, ?)", [.integer(Int64.max), .text(label), .null]), 1)
            try session.execute("INSERT INTO children VALUES (?, ?)", [.integer(1), .integer(Int64.max)])
            try session.execute("INSERT INTO receipts VALUES (?, ?)", [.text("original-command"), .integer(Int64.max)])
        }
        try database.close()
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try reopened.read { try $0.query("SELECT * FROM parents") }, [[.integer(Int64.max), .text(label), .null]])
        XCTAssertEqual(try count(reopened, table: "receipts"), 1)
        try reopened.close()
    }

    func testExistingCreateAndMissingOpenPreserveDestination() throws {
        XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: schema()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        try database.close()
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try SQLiteDatabase.create(at: url, schema: schema()))
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testStaleSidecarsAndSymlinkAreRejected() throws {
        let sidecar = URL(fileURLWithPath: url.path + "-wal")
        try Data("keep".utf8).write(to: sidecar)
        XCTAssertThrowsError(try SQLiteDatabase.create(at: url, schema: schema()))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(try Data(contentsOf: sidecar), Data("keep".utf8))
        try FileManager.default.removeItem(at: sidecar)
        let target = directory.appendingPathComponent("target")
        try Data("keep".utf8).write(to: target)
        try FileManager.default.createSymbolicLink(at: url, withDestinationURL: target)
        XCTAssertThrowsError(try SQLiteDatabase.create(at: url, schema: schema()))
        XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: schema()))
        XCTAssertEqual(try Data(contentsOf: target), Data("keep".utf8))
    }

    func testUnsupportedIDsCorruptionAndMetadataNeverRewriteFile() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        try database.close()
        let before = try Data(contentsOf: url)
        for candidate in [schema(version: 7002), schema(applicationID: 99), schema(invalidValidator: true)] {
            XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: candidate))
            XCTAssertEqual(try Data(contentsOf: url), before)
        }
        try FileManager.default.removeItem(at: url)
        let corrupt = Data("not a database; preserve this evidence".utf8)
        try corrupt.write(to: url)
        XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: schema()))
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testForeignKeyIntegrityFailurePreservesBytes() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        try database.close()
        var raw: OpaquePointer?
        XCTAssertEqual(sqlite3_open(url.path, &raw), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(raw, "PRAGMA foreign_keys=OFF; INSERT INTO children VALUES (1, 999)", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_close(raw), SQLITE_OK)
        let before = try Data(contentsOf: url)
        XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: schema())) { XCTAssertEqual($0 as? StorageFailure, .integrityFailure) }
        XCTAssertEqual(try Data(contentsOf: url), before)
    }

    func testFailedDDLAndValidatorRollBackBootstrap() throws {
        for (index, badSchema) in [schema(extra: ["CREATE TABLE metadata (duplicate TEXT)"]), schema(invalidValidator: true)].enumerated() {
            let url = directory.appendingPathComponent("failed-bootstrap-\(index).sqlite")
            XCTAssertThrowsError(try SQLiteDatabase.create(at: url, schema: badSchema)) {
                XCTAssertEqual($0 as? StorageFailure, index == 0 ? .sqlite(SQLITE_ERROR) : .schemaMismatch)
            }
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            XCTAssertThrowsError(try SQLiteDatabase.open(at: url, schema: schema()))
            var raw: OpaquePointer?
            XCTAssertEqual(sqlite3_open_v2(url.path, &raw, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
            var statement: OpaquePointer?
            XCTAssertEqual(sqlite3_prepare_v2(raw, "SELECT count(*) FROM sqlite_master WHERE type='table'", -1, &statement, nil), SQLITE_OK)
            XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
            XCTAssertEqual(sqlite3_column_int(statement, 0), 0)
            XCTAssertEqual(sqlite3_finalize(statement), SQLITE_OK)
            XCTAssertEqual(sqlite3_close(raw), SQLITE_OK)
        }
    }

    func testConstraintErrorsAndThrownWorkRollBackWholeOperation() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (1)")
            try session.execute("INSERT INTO receipts VALUES ('same-id', 1)")
        }
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (2)")
            try session.execute("INSERT INTO children VALUES (2, 2)")
            try session.execute("INSERT INTO receipts VALUES ('same-id', 2)")
        })
        XCTAssertEqual(try count(database), 1)
        XCTAssertEqual(try count(database, table: "children"), 0)
        XCTAssertEqual(try count(database, table: "receipts"), 1)
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (3)")
            try session.execute("INSERT INTO children VALUES (3, 999)")
        })
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (4)")
            throw StorageFailure.invalidBindings
        })
        XCTAssertEqual(try count(database), 1)
        try database.close()
    }

    func testCaughtStatementErrorsCannotCommitOrContinueAfterAutomaticRollback() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }
        for conflict in ["INSERT", "INSERT OR ROLLBACK"] {
            XCTAssertThrowsError(try database.transaction { session in
                try session.execute("INSERT INTO parents(id) VALUES (2)")
                do { try session.execute("\(conflict) INTO parents(id) VALUES (1)") } catch { }
                XCTAssertThrowsError(try session.execute("INSERT INTO parents(id) VALUES (3)"))
                // Even if operation code catches both errors, scope finish fails.
            })
            XCTAssertEqual(try database.read { try $0.query("SELECT id FROM parents ORDER BY id") }, [[.integer(1)]])
        }
        try database.close()
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try count(reopened), 1)
        try reopened.close()
    }

    func testStatementsFinalizeAndCannotControlConnection() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        for sql in ["BEGIN", "COMMIT", "ROLLBACK", "SAVEPOINT x", "PRAGMA foreign_keys=OFF", "ATTACH ':memory:' AS other", "INSERT INTO parents(id) VALUES (1); DELETE FROM parents"] {
            XCTAssertThrowsError(try database.transaction { try $0.execute(sql) })
        }
        XCTAssertThrowsError(try database.read { try $0.query("PRAGMA user_version=99") })
        XCTAssertThrowsError(try database.read { try $0.query("DELETE FROM parents") })
        XCTAssertThrowsError(try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (?)") })
        XCTAssertThrowsError(try database.read { try $0.query("SELECT 1.5") })
        XCTAssertThrowsError(try database.read { try $0.query("SELECT 1\u{0}; SELECT 2") })
        XCTAssertEqual(try count(database), 0)
        try database.close() // No leaked prepared statement causes BUSY.
    }

    func testReentrantNestedAndEscapedSessionsRejectWithoutDeadlock() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        var escaped: SQLiteSession?
        try database.transaction { session in
            escaped = session
            XCTAssertThrowsError(try database.transaction { _ in }) { XCTAssertEqual($0 as? StorageFailure, .reentrant) }
            XCTAssertThrowsError(try database.close()) { XCTAssertEqual($0 as? StorageFailure, .reentrant) }
            XCTAssertThrowsError(try database.read { _ in }) { XCTAssertEqual($0 as? StorageFailure, .reentrant) }
        }
        XCTAssertThrowsError(try escaped?.query("SELECT 1")) { XCTAssertEqual($0 as? StorageFailure, .expiredSession) }
        try database.read { _ in
            XCTAssertThrowsError(try escaped?.query("SELECT 1")) { XCTAssertEqual($0 as? StorageFailure, .expiredSession) }
        }
        try database.close()
    }

    func testCommitFailureWithVerifiedRollbackIsReusable() throws {
        var shouldFail = false
        let database = try SQLiteDatabase.create(at: url, schema: schema()) { boundary in
            if shouldFail, boundary == .beforeCommit { throw StorageFailure.sqlite(SQLITE_IOERR) }
        }
        shouldFail = true
        XCTAssertThrowsError(try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }) {
            XCTAssertEqual($0 as? StorageFailure, .sqlite(SQLITE_IOERR))
        }
        XCTAssertEqual(try count(database), 0)
        shouldFail = false
        try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }
        try database.close()
    }

    func testActualDeferredConstraintCommitFailureRollsBack() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema(extra: [
            "CREATE TABLE deferred_children (parent_id INTEGER REFERENCES parents(id) DEFERRABLE INITIALLY DEFERRED)",
        ]))
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (1)")
            // The statement succeeds; the actual SQLite COMMIT must fail.
            try session.execute("INSERT INTO deferred_children VALUES (999)")
        }) {
            guard case .sqlite(let code) = $0 as? StorageFailure else { return XCTFail("Expected constraint failure") }
            XCTAssertEqual(code & 0xff, SQLITE_CONSTRAINT)
        }
        XCTAssertEqual(try count(database), 0)
        XCTAssertEqual(try count(database, table: "deferred_children"), 0)
        try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }
        try database.close()
    }

    func testLostCommitAcknowledgementPoisonsAndReopenFindsReceipt() throws {
        var shouldFail = false
        let database = try SQLiteDatabase.create(at: url, schema: schema()) { boundary in
            if shouldFail, boundary == .afterCommit { throw StorageFailure.sqlite(SQLITE_IOERR) }
        }
        shouldFail = true
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (1)")
            try session.execute("INSERT INTO receipts VALUES ('one-command', 1)")
        }) { XCTAssertEqual($0 as? StorageFailure, .unknownOutcome) }
        XCTAssertThrowsError(try count(database)) { XCTAssertEqual($0 as? StorageFailure, .unavailable) }
        XCTAssertThrowsError(try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (2)") })
        try database.close()
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try count(reopened), 1)
        XCTAssertEqual(try count(reopened, table: "receipts"), 1)
        try reopened.close()
    }

    func testRollbackFailurePoisonsUntilCloseReopen() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema()) { boundary in
            if boundary == .beforeRollback { throw StorageFailure.sqlite(SQLITE_IOERR) }
        }
        XCTAssertThrowsError(try database.transaction { session in
            try session.execute("INSERT INTO parents(id) VALUES (1)")
            throw StorageFailure.invalidBindings
        }) { XCTAssertEqual($0 as? StorageFailure, .unknownOutcome) }
        XCTAssertThrowsError(try count(database))
        try database.close()
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try count(reopened), 0)
        try reopened.close()
    }

    func testReadRollbackFailureNeedsReopenWithoutAmbiguousMutation() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema()) { boundary in
            if boundary == .beforeRollback { throw StorageFailure.sqlite(SQLITE_IOERR) }
        }
        try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }
        XCTAssertThrowsError(try database.read { session in
            _ = try session.query("SELECT id FROM parents")
            throw StorageFailure.invalidBindings
        }) { XCTAssertEqual($0 as? StorageFailure, .unavailable) }
        XCTAssertThrowsError(try database.read { try $0.query("SELECT 1") })
        try database.close()
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try count(reopened), 1)
        XCTAssertEqual(try count(reopened, table: "receipts"), 0)
        try reopened.close()
    }

    func testCloseFailureRetainsHandleAndRejectsWorkUntilRetry() throws {
        var busy = true
        let database = try SQLiteDatabase.create(at: url, schema: schema()) { boundary in
            if boundary == .close, busy { throw StorageFailure.sqlite(SQLITE_BUSY) }
        }
        XCTAssertThrowsError(try database.close())
        XCTAssertThrowsError(try count(database)) { XCTAssertEqual($0 as? StorageFailure, .unavailable) }
        busy = false
        try database.close()
        try database.close() // Idempotent close, never reuse a closed handle.
        XCTAssertThrowsError(try database.diagnostics())
    }

    func testConcurrentOperationsSerializeAndCloseWaitsForPriorWork() throws {
        let database = try SQLiteDatabase.create(at: url, schema: schema())
        let done = expectation(description: "all operations")
        done.expectedFulfillmentCount = 40
        for value in 1...40 {
            DispatchQueue.global().async {
                defer { done.fulfill() }
                do { try database.transaction { try $0.execute("INSERT INTO parents(id) VALUES (?)", [.integer(Int64(value))]) } }
                catch { XCTFail("Unexpected error \(error)") }
            }
        }
        wait(for: [done], timeout: 10)
        XCTAssertEqual(try count(database), 40)
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = expectation(description: "transaction finishes")
        let closed = expectation(description: "close follows transaction")
        DispatchQueue.global().async {
            defer { finished.fulfill() }
            do {
                try database.transaction { session in
                    entered.signal()
                    XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
                    try session.execute("INSERT INTO parents(id) VALUES (41)")
                }
            } catch { XCTFail("Unexpected error \(error)") }
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 5), .success)
        DispatchQueue.global().async {
            defer { closed.fulfill() }
            do { try database.close() } catch { XCTFail("Unexpected close error \(error)") }
        }
        release.signal()
        wait(for: [finished, closed], timeout: 10)
        XCTAssertThrowsError(try count(database))
        let reopened = try SQLiteDatabase.open(at: url, schema: schema())
        XCTAssertEqual(try count(reopened), 41)
        try reopened.close()
    }

    func testBusyTimeoutAndRetryPreserveOriginalData() throws {
        let first = try SQLiteDatabase.create(at: url, schema: schema())
        let second = try SQLiteDatabase.open(at: url, schema: schema())
        let entered = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        let finished = expectation(description: "first writer")
        DispatchQueue.global().async {
            defer { finished.fulfill() }
            do {
                try first.transaction { session in
                    try session.execute("INSERT INTO parents(id) VALUES (1)")
                    entered.signal()
                    XCTAssertEqual(release.wait(timeout: .now() + 10), .success)
                }
            } catch { XCTFail("First writer \(error)") }
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 5), .success)
        let start = ProcessInfo.processInfo.systemUptime
        XCTAssertThrowsError(try second.transaction { try $0.execute("INSERT INTO parents(id) VALUES (2)") }) {
            guard case .sqlite(let code) = $0 as? StorageFailure else { return XCTFail("Expected busy") }
            XCTAssertEqual(code & 0xff, SQLITE_BUSY)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - start
        XCTAssertGreaterThanOrEqual(elapsed, 2.0)
        XCTAssertLessThan(elapsed, 6.0)
        release.signal()
        wait(for: [finished], timeout: 5)
        XCTAssertEqual(try count(second), 1)
        try second.transaction { try $0.execute("INSERT INTO parents(id) VALUES (2)") }
        XCTAssertEqual(try count(first), 2)
        try first.close()
        try second.close()
    }

    func testReadCallbackKeepsOneSnapshotWhileOtherConnectionCommits() throws {
        let reader = try SQLiteDatabase.create(at: url, schema: schema())
        let writer = try SQLiteDatabase.open(at: url, schema: schema())
        try reader.read { session in
            XCTAssertEqual(try session.query("SELECT COUNT(*) FROM parents"), [[.integer(0)]])
            try writer.transaction { try $0.execute("INSERT INTO parents(id) VALUES (1)") }
            XCTAssertEqual(try session.query("SELECT COUNT(*) FROM parents"), [[.integer(0)]])
        }
        XCTAssertEqual(try count(reader), 1)
        try reader.close()
        try writer.close()
    }
}
