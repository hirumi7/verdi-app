import Dispatch
import Foundation
import SQLite3

/// A scoped view whose handle and statements never escape the native executor.
final class SQLiteSession {
    private let handle: OpaquePointer
    private let queueKey: DispatchSpecificKey<UInt8>
    private let writable: Bool
    private var active = true
    private var failure: Error?

    init(handle: OpaquePointer, queueKey: DispatchSpecificKey<UInt8>, writable: Bool) {
        self.handle = handle
        self.queueKey = queueKey
        self.writable = writable
    }

    func expire() { active = false }

    func finish() throws {
        if let failure { throw failure }
    }

    func query(_ sql: String, _ values: [SQLValue] = []) throws -> [[SQLValue]] {
        try run(sql, values, readOnly: true)
    }

    @discardableResult
    func execute(_ sql: String, _ values: [SQLValue] = []) throws -> Int {
        guard writable else { throw StorageFailure.readOnly }
        _ = try run(sql, values, readOnly: false)
        return Int(sqlite3_changes(handle))
    }

    private func run(_ sql: String, _ values: [SQLValue], readOnly: Bool) throws -> [[SQLValue]] {
        guard DispatchQueue.getSpecific(key: queueKey) != nil, active else {
            throw StorageFailure.expiredSession
        }
        if let failure { throw failure }
        guard !writable || sqlite3_get_autocommit(handle) == 0 else {
            failure = StorageFailure.unknownOutcome
            throw StorageFailure.unknownOutcome
        }
        do {
            return try statement(sql, values, readOnly: readOnly)
        } catch {
            // A caught SQL error must not let later statements autocommit after
            // SQLite has automatically rolled back (e.g. INSERT OR ROLLBACK).
            failure = error
            throw error
        }
    }

    private func statement(_ sql: String, _ values: [SQLValue], readOnly: Bool) throws -> [[SQLValue]] {
        // Deny connection/transaction control even to compiled operation code.
        // Read queries also deny writes at prepare time (some PRAGMAs act then).
        var onlyReads = readOnly
        return try withUnsafeMutablePointer(to: &onlyReads) { permission in
            sqlite3_set_authorizer(handle, { context, action, _, _, _, _ in
                guard let context else { return SQLITE_DENY }
                let readOnly = context.assumingMemoryBound(to: Bool.self).pointee
                if readOnly {
                    switch action {
                    case SQLITE_SELECT, SQLITE_READ, SQLITE_FUNCTION, SQLITE_RECURSIVE:
                        return SQLITE_OK
                    default: return SQLITE_DENY
                    }
                }
                switch action {
                case SQLITE_TRANSACTION, SQLITE_SAVEPOINT, SQLITE_ATTACH, SQLITE_DETACH, SQLITE_PRAGMA:
                    return SQLITE_DENY
                default: return SQLITE_OK
                }
            }, permission)
            defer { sqlite3_set_authorizer(handle, nil, nil) }
            return try SQLiteStatement.run(handle, sql, values, readOnly: readOnly)
        }
    }
}

enum SQLiteStatement {
    static func run(
        _ handle: OpaquePointer, _ sql: String, _ values: [SQLValue] = [],
        readOnly: Bool = false
    ) throws -> [[SQLValue]] {
        guard !sql.utf8.contains(0), sql.utf8.count < Int(Int32.max) else {
            throw StorageFailure.invalidStatement
        }
        var statement: OpaquePointer?
        let preparation: Int32 = sql.withCString { source in
            var tail: UnsafePointer<CChar>?
            let code = sqlite3_prepare_v2(handle, source, -1, &statement, &tail)
            if code == SQLITE_OK, let tail,
               !String(cString: tail).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return SQLITE_MISUSE
            }
            return code
        }
        guard preparation == SQLITE_OK, let prepared = statement else {
            if let statement { sqlite3_finalize(statement) }
            throw StorageFailure.sqlite(preparation == SQLITE_OK ? SQLITE_MISUSE : preparation)
        }
        let result: Result<[[SQLValue]], Error> = Result {
            guard !readOnly || sqlite3_stmt_readonly(prepared) != 0 else {
                throw StorageFailure.readOnly
            }
            guard sqlite3_bind_parameter_count(prepared) == values.count else {
                throw StorageFailure.invalidBindings
            }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            for (offset, value) in values.enumerated() {
                let index = Int32(offset + 1)
                let code: Int32
                switch value {
                case .null: code = sqlite3_bind_null(prepared, index)
                case .integer(let number): code = sqlite3_bind_int64(prepared, index, number)
                case .text(let text):
                    guard text.utf8.count < Int(Int32.max) else { throw StorageFailure.unsupportedValue }
                    code = text.withCString { sqlite3_bind_text(prepared, index, $0, Int32(text.utf8.count), transient) }
                }
                guard code == SQLITE_OK else { throw StorageFailure.sqlite(code) }
            }
            var rows: [[SQLValue]] = []
            while true {
                let code = sqlite3_step(prepared)
                if code == SQLITE_DONE { return rows }
                guard code == SQLITE_ROW else { throw StorageFailure.sqlite(code) }
                var row: [SQLValue] = []
                for column in 0..<sqlite3_column_count(prepared) {
                    switch sqlite3_column_type(prepared, column) {
                    case SQLITE_NULL: row.append(.null)
                    case SQLITE_INTEGER: row.append(.integer(sqlite3_column_int64(prepared, column)))
                    case SQLITE_TEXT:
                        guard let bytes = sqlite3_column_text(prepared, column) else { throw StorageFailure.unsupportedValue }
                        let count = Int(sqlite3_column_bytes(prepared, column))
                        guard let text = String(bytes: UnsafeBufferPointer(start: bytes, count: count), encoding: .utf8) else {
                            throw StorageFailure.unsupportedValue
                        }
                        row.append(.text(text))
                    default: throw StorageFailure.unsupportedValue
                    }
                }
                rows.append(row)
            }
        }
        let finalCode = sqlite3_finalize(prepared)
        let rows = try result.get()
        guard finalCode == SQLITE_OK else { throw StorageFailure.sqlite(finalCode) }
        return rows
    }
}
