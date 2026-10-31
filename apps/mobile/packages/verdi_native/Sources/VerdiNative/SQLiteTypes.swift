import Foundation

// Module-internal infrastructure. No arbitrary SQL or file URL crosses a channel.
enum SQLValue: Equatable {
    case null
    case integer(Int64)
    case text(String)
    static func == (lhs: SQLValue, rhs: SQLValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case (.integer(let a), .integer(let b)): return a == b
        case (.text(let a), .text(let b)): return a.utf8.elementsEqual(b.utf8)
        default: return false
        }
    }
}

enum StorageFailure: Error, Equatable {
    case sqlite(Int32)
    case filesystem(Int32)
    case invalidPath, invalidSchema, schemaMismatch, integrityFailure
    case settingsUnsupported, readOnly, unavailable, reentrant, expiredSession
    case invalidStatement, invalidBindings, unsupportedValue
    case unknownOutcome
}

struct CompiledSchema {
    let applicationID: Int32
    let version: Int32
    let statements: [String]
    let validate: (SQLiteSession) throws -> Void
}

struct SQLiteDiagnostics {
    let libraryVersion: String
    let libraryVersionNumber: Int32
    let compileOptions: [String]
    let foreignKeys: Int64
    let journalMode: String
    let synchronous: Int64
    let busyTimeoutMilliseconds: Int64
}

// Deterministic boundary faults for tests, not an externally configurable API.
enum SQLiteBoundary { case beforeCommit, afterCommit, beforeRollback, close }
