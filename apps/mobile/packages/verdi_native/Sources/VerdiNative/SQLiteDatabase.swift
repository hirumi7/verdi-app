import Darwin
import Dispatch
import Foundation
import SQLite3

/// One OS SQLite connection, serialized for the entire lifetime of each operation.
/// Not yet a customer-data repository or the Pigeon openRuntime implementation.
final class SQLiteDatabase {
    private let queue = DispatchQueue(label: "verdi.native.sqlite")
    private let queueKey = DispatchSpecificKey<UInt8>()
    private var handle: OpaquePointer?
    private var usable = false
    private let controlProfile: Bool
    private let fault: ((SQLiteBoundary) throws -> Void)?

    private init(fault: ((SQLiteBoundary) throws -> Void)?, controlProfile: Bool = false) {
        self.controlProfile = controlProfile
        self.fault = fault
        queue.setSpecific(key: queueKey, value: 1)
    }

    static func create(
        at url: URL, schema: CompiledSchema, controlProfile: Bool = false,
        fault: ((SQLiteBoundary) throws -> Void)? = nil
    ) throws -> SQLiteDatabase {
        let target = try canonicalTarget(url)
        let database = SQLiteDatabase(fault: fault, controlProfile: controlProfile)
        try database.queue.sync {
            try database.checkInput(url, schema)
            // A missing main file with old sidecars is not a new database.
            for suffix in ["-wal", "-shm", "-journal"] {
                var info = stat()
                if lstat(target + suffix, &info) == 0 { throw StorageFailure.filesystem(EEXIST) }
                guard errno == ENOENT else { throw StorageFailure.filesystem(errno) }
            }
            let descriptor = Darwin.open(target, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
            guard descriptor >= 0 else { throw StorageFailure.filesystem(errno) }
            guard Darwin.close(descriptor) == 0 else { throw StorageFailure.filesystem(errno) }
            do {
                try database.openHandle(target, readOnly: false)
                try database.configure()
                try database.atomic { session in
                    for sql in schema.statements { try session.execute(sql) }
                    try database.control("PRAGMA application_id = \(schema.applicationID)")
                    try database.control("PRAGMA user_version = \(schema.version)")
                    try database.validate(schema)
                }
                database.usable = true
            } catch {
                database.dispose()
                throw error
            }
        }
        return database
    }

    static func open(at url: URL, schema: CompiledSchema, upgradeFrom: CompiledSchema? = nil, migrationStatements: [String] = [], controlProfile: Bool = false, fault: ((SQLiteBoundary) throws -> Void)? = nil) throws -> SQLiteDatabase {
        let target = try canonicalTarget(url)
        let database = SQLiteDatabase(fault: fault, controlProfile: controlProfile)
        try database.queue.sync {
            try database.checkInput(url, schema)
            var info = stat()
            guard lstat(target, &info) == 0 else { throw StorageFailure.filesystem(errno) }
            guard (info.st_mode & S_IFMT) == S_IFREG else { throw StorageFailure.invalidPath }
            do {
                try database.openHandle(target, readOnly: true)
                var migrating = false
                do { try database.validate(schema) }
                catch StorageFailure.schemaMismatch {
                    guard let previous = upgradeFrom, !migrationStatements.isEmpty else { throw StorageFailure.schemaMismatch }
                    try database.validate(previous); migrating = true
                }
                try database.closeHandle()
                try database.openHandle(target, readOnly: false)
                if migrating {
                    try database.validate(upgradeFrom!)
                    try database.configure()
                    try database.atomic { sql in
                        try database.validate(upgradeFrom!)
                        for statement in migrationStatements { try sql.execute(statement) }
                        try database.control("PRAGMA user_version = \(schema.version)")
                        try database.validate(schema)
                    }
                } else { try database.validate(schema); try database.configure() }
                database.usable = true
            } catch {
                database.dispose()
                throw error
            }
        }
        return database
    }

    func read<T>(_ work: (SQLiteSession) throws -> T) throws -> T {
        try scheduled {
            try requireUsable()
            return try atomic(writable: false, work)
        }
    }

    @discardableResult
    func transaction<T>(_ work: (SQLiteSession) throws -> T) throws -> T {
        try scheduled {
            try requireUsable()
            return try atomic(work)
        }
    }

    /// Compiled import boundary only; foreign keys are checked before commit.
    func importTransaction<T>(_ work: (SQLiteSession) throws -> T) throws -> T {
        try scheduled {
            try requireUsable()
            return try atomic { sql in
                try self.control("PRAGMA defer_foreign_keys = ON")
                let result = try work(sql)
                guard try self.raw("PRAGMA foreign_key_check").isEmpty else { throw StorageFailure.integrityFailure }
                return result
            }
        }
    }
    func checkpoint() throws {
        try scheduled {
            try requireUsable()
            let rows = try raw("PRAGMA wal_checkpoint(TRUNCATE)")
            guard rows.first?.first == .integer(0) else { throw CoreRepositoryError("BUSY") }
        }
    }
    /// SQLite, not filesystem copying, owns the WAL-consistent snapshot.
    func snapshot(to target: URL) throws {
        try scheduled {
            try requireUsable()
            let path = try Self.canonicalTarget(target)
            let fd = Darwin.open(path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, S_IRUSR | S_IWUSR)
            guard fd >= 0 else { throw StorageFailure.filesystem(errno) }
            guard Darwin.close(fd) == 0 else { throw StorageFailure.filesystem(errno) }
            var destination: OpaquePointer?
            let status = sqlite3_open_v2(path, &destination, SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW, nil)
            guard status == SQLITE_OK,
                  let destination else { if let destination { sqlite3_close(destination) }; throw StorageFailure.unavailable }
            var closed = false
            defer { if !closed { sqlite3_close(destination) } }
            guard let backup = sqlite3_backup_init(destination, "main", handle, "main") else { throw StorageFailure.unavailable }
            let result = sqlite3_backup_step(backup, -1), finish = sqlite3_backup_finish(backup)
            guard result == SQLITE_DONE, finish == SQLITE_OK else { throw StorageFailure.unavailable }
            // The copied header can retain WAL mode without sidecars. Convert the
            // private clone to a closed standalone database before readonly validation.
            guard sqlite3_exec(destination, "PRAGMA journal_mode=DELETE", nil, nil, nil) == SQLITE_OK else {throw StorageFailure.unavailable}
            guard sqlite3_close(destination) == SQLITE_OK else { throw StorageFailure.unavailable }
            closed = true
        }
    }

    func diagnostics() throws -> SQLiteDiagnostics {
        try scheduled {
            try requireUsable()
            return try diagnosticValues()
        }
    }

    func close() throws {
        try scheduled {
            usable = false
            guard handle != nil else { return }
            try fault?(.close)
            try closeHandle()
        }
    }

    deinit {
        // No statement escapes; this only releases an abandoned native owner.
        if DispatchQueue.getSpecific(key: queueKey) != nil { dispose() }
        else { queue.sync { dispose() } }
    }

    private func scheduled<T>(_ work: () throws -> T) throws -> T {
        guard DispatchQueue.getSpecific(key: queueKey) == nil else { throw StorageFailure.reentrant }
        return try queue.sync(execute: work)
    }

    private func requireUsable() throws {
        guard usable, handle != nil else { throw StorageFailure.unavailable }
    }

    private static func canonicalTarget(_ url: URL) throws -> String {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0) else { throw StorageFailure.invalidPath }
        // Apple sandbox parents commonly pass through /var -> /private/var.
        // Resolve the trusted parent, never a possibly substituted leaf file.
        guard let parent = realpath(url.deletingLastPathComponent().path, nil) else {
            throw StorageFailure.filesystem(errno)
        }
        defer { free(parent) }
        return String(cString: parent) + "/" + url.lastPathComponent
    }

    private func checkInput(_ url: URL, _ schema: CompiledSchema) throws {
        guard url.isFileURL, url.path.hasPrefix("/"), !url.path.utf8.contains(0) else { throw StorageFailure.invalidPath }
        guard schema.applicationID > 0, schema.version > 0, !schema.statements.isEmpty else { throw StorageFailure.invalidSchema }
        guard sqlite3_threadsafe() != 0 else { throw StorageFailure.settingsUnsupported }
    }

    private func openHandle(_ path: String, readOnly: Bool) throws {
        var opened: OpaquePointer?
        let flags = (readOnly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE) | SQLITE_OPEN_FULLMUTEX | SQLITE_OPEN_NOFOLLOW
        let code = sqlite3_open_v2(path, &opened, flags, nil)
        handle = opened
        guard code == SQLITE_OK, let opened else { throw StorageFailure.sqlite(code) }
        guard readOnly || sqlite3_db_readonly(opened, "main") == 0 else { throw StorageFailure.readOnly }
        sqlite3_extended_result_codes(opened, 1)
        let timeout = sqlite3_busy_timeout(opened, 2500)
        guard timeout == SQLITE_OK else { throw StorageFailure.sqlite(timeout) }
    }

    private func closeHandle() throws {
        guard let handle else { return }
        let code = sqlite3_close(handle)
        guard code == SQLITE_OK else { throw StorageFailure.sqlite(code) }
        self.handle = nil
    }

    private func dispose() {
        usable = false
        if let handle {
            // All scoped statements have already finalized; close_v2 is not used
            // on the observable close path because it hides SQLITE_BUSY.
            sqlite3_close_v2(handle)
            self.handle = nil
        }
    }

    private func configure() throws {
        try control("PRAGMA foreign_keys = ON")
        try control(controlProfile ? "PRAGMA journal_mode = DELETE" : "PRAGMA journal_mode = WAL")
        try control(controlProfile ? "PRAGMA synchronous = EXTRA" : "PRAGMA synchronous = FULL")
        if controlProfile {
            try control("PRAGMA fullfsync = ON")
            guard try raw("PRAGMA fullfsync") == [[.integer(1)]] else { throw StorageFailure.settingsUnsupported }
        }
        let values = try diagnosticValues()
        guard values.foreignKeys == 1, values.journalMode == (controlProfile ? "delete" : "wal"), values.synchronous == (controlProfile ? 3 : 2),
              values.busyTimeoutMilliseconds == 2500 else { throw StorageFailure.settingsUnsupported }
    }

    private func diagnosticValues() throws -> SQLiteDiagnostics {
        func integer(_ sql: String) throws -> Int64 {
            guard case .integer(let value)? = try raw(sql).first?.first else { throw StorageFailure.settingsUnsupported }
            return value
        }
        guard case .text(let mode)? = try raw("PRAGMA journal_mode").first?.first else { throw StorageFailure.settingsUnsupported }
        let options = try raw("PRAGMA compile_options").map { row -> String in
            guard case .text(let value)? = row.first else { throw StorageFailure.settingsUnsupported }
            return value
        }
        return try SQLiteDiagnostics(
            libraryVersion: String(cString: sqlite3_libversion()), libraryVersionNumber: sqlite3_libversion_number(),
            compileOptions: options, foreignKeys: integer("PRAGMA foreign_keys"), journalMode: mode,
            synchronous: integer("PRAGMA synchronous"), busyTimeoutMilliseconds: integer("PRAGMA busy_timeout")
        )
    }

    private func validate(_ schema: CompiledSchema) throws {
        guard try raw("PRAGMA application_id") == [[.integer(Int64(schema.applicationID))]],
              try raw("PRAGMA user_version") == [[.integer(Int64(schema.version))]] else { throw StorageFailure.schemaMismatch }
        guard try raw("PRAGMA quick_check") == [[.text("ok")]],
              try raw("PRAGMA foreign_key_check").isEmpty else { throw StorageFailure.integrityFailure }
        try scoped(writable: false, schema.validate)
    }

    private func scoped<T>(writable: Bool, _ work: (SQLiteSession) throws -> T) throws -> T {
        guard let handle else { throw StorageFailure.unavailable }
        let session = SQLiteSession(handle: handle, queueKey: queueKey, writable: writable)
        defer { session.expire() }
        let result = try work(session)
        try session.finish()
        return result
    }

    private func raw(_ sql: String) throws -> [[SQLValue]] {
        guard let handle else { throw StorageFailure.unavailable }
        return try SQLiteStatement.run(handle, sql)
    }

    private func control(_ sql: String) throws { _ = try raw(sql) }

    private func atomic<T>(writable: Bool = true, _ work: (SQLiteSession) throws -> T) throws -> T {
        guard let handle else { throw StorageFailure.unavailable }
        let uncertainFailure: StorageFailure = writable ? .unknownOutcome : .unavailable
        guard sqlite3_get_autocommit(handle) != 0 else {
            usable = false
            throw uncertainFailure
        }
        try control(writable ? "BEGIN IMMEDIATE" : "BEGIN DEFERRED")
        var committing = false
        do {
            let result = try scoped(writable: writable, work)
            committing = true
            if writable { try fault?(.beforeCommit) }
            try control("COMMIT")
            if writable { try fault?(.afterCommit) }
            guard sqlite3_get_autocommit(handle) != 0 else { throw uncertainFailure }
            return result
        } catch {
            let original = error
            if sqlite3_get_autocommit(handle) != 0 {
                if !committing { throw original } // SQLite automatically rolled back pre-commit work.
                usable = false
                throw uncertainFailure
            }
            do {
                try fault?(.beforeRollback)
                try control("ROLLBACK")
                guard sqlite3_get_autocommit(handle) != 0 else { throw uncertainFailure }
            } catch {
                usable = false
                throw uncertainFailure
            }
            throw original
        }
    }
}
