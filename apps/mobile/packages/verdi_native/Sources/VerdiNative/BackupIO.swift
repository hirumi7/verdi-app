import Foundation
import Darwin
import CryptoKit

/// Instance-owned fault seams. No hooks or paths are exposed through platform APIs.
enum BackupFileBoundary { case write, fileSync, fullSync, close, directorySync, rename, renamed, remove }
final class BackupFileIO {
    let fault: ((BackupFileBoundary, URL) throws -> Void)?
    let writeOverride: ((Int32, UnsafeRawPointer, Int) -> Int)?
    init(fault: ((BackupFileBoundary, URL) throws -> Void)? = nil,
         write: ((Int32, UnsafeRawPointer, Int) -> Int)? = nil) {
        self.fault = fault; self.writeOverride = write
    }
    func write(_ fd:Int32, _ pointer:UnsafeRawPointer, _ count:Int, at url:URL) throws -> Int {
        try fault?(.write,url)
        return writeOverride?(fd,pointer,count) ?? Darwin.write(fd,pointer,count)
    }
    func syncFile(_ fd:Int32, at url:URL) throws {
        try fault?(.fileSync,url)
        try BackupIO.require(fsync(fd) == 0,"DURABILITY_UNAVAILABLE")
        try fault?(.fullSync,url)
        try BackupIO.require(fcntl(fd,F_FULLFSYNC) == 0,"DURABILITY_UNAVAILABLE")
    }
    func close(_ fd:Int32, at url:URL) throws {
        // Close exactly once, even if its result is ambiguous. Never retry an FD.
        let result = Darwin.close(fd)
        try fault?(.close,url)
        try BackupIO.require(result == 0,"DURABILITY_UNAVAILABLE")
    }
    func syncDirectory(_ url:URL) throws {
        try fault?(.directorySync,url)
        let fd = Darwin.open(url.path,O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        try BackupIO.require(fd >= 0,"IO_FAILURE")
        let synced = fsync(fd), closed = Darwin.close(fd)
        try BackupIO.require(synced == 0 && closed == 0,"DURABILITY_UNAVAILABLE")
    }
    func renameExclusive(_ source:URL, to target:URL) throws {
        try fault?(.rename,target)
        guard renamex_np(source.path,target.path,UInt32(RENAME_EXCL)) == 0 else {throw StorageFailure.filesystem(errno)}
        try fault?(.renamed,target)
        try syncDirectory(target.deletingLastPathComponent())
        if source.deletingLastPathComponent() != target.deletingLastPathComponent() {try syncDirectory(source.deletingLastPathComponent())}
    }
    func remove(_ target:URL) throws {
        try fault?(.remove,target)
        if FileManager.default.fileExists(atPath:target.path) {try FileManager.default.removeItem(at:target)}
        // A prior deletion may have succeeded while parent sync failed. Retry sync
        // even when the name is already absent, before dropping its inventory row.
        try syncDirectory(target.deletingLastPathComponent())
    }
}

/// Backup paths originate in native UUIDs and compiled names, never archive paths.
enum BackupIO {
    static let chunk = 65_536
    static let archiveLimit: Int64 = 8 * 1024 * 1024 * 1024
    static let expandedLimit: Int64 = 12 * 1024 * 1024 * 1024
    static func require(_ value: Bool, _ code: String = "BACKUP_SCHEMA_INVALID") throws {
        if !value { throw CoreRepositoryError(code) }
    }
    static func directory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var info = stat()
        try require(lstat(url.path, &info) == 0 && info.st_mode & S_IFMT == S_IFDIR, "BACKUP_PATH_INVALID")
        try protect(url)
    }
    static func protect(_ url: URL) throws {
        #if os(iOS)
        _ = try DraftProtection.apply(deviceRequired: CoreRepository.deviceProtectionRequired, set: {
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: url.path)
        }, read: {
            let value = try FileManager.default.attributesOfItem(atPath: url.path)[.protectionKey]
            return (value as? FileProtectionType)?.rawValue ?? (value as? String)
        })
        #endif
    }
    static func excludeFromOSBackup(_ url:URL, excluded:Bool = true) throws {
        var target=url, values=URLResourceValues();values.isExcludedFromBackup=excluded
        try target.setResourceValues(values)
        try require(try target.resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup == excluded,"IO_FAILURE")
    }
    static func read(_ url: URL) throws -> Int32 {
        let fd = Darwin.open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw CoreRepositoryError("IO_FAILURE") }
        var info = stat()
        guard fstat(fd, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { Darwin.close(fd); throw CoreRepositoryError("BACKUP_PATH_INVALID") }
        return fd
    }
    static func size(_ url: URL) throws -> Int64 {
        let fd = try read(url); defer { Darwin.close(fd) }; var info = stat()
        try require(fstat(fd, &info) == 0, "IO_FAILURE"); return info.st_size
    }
    static func flush(_ url: URL, io: BackupFileIO = BackupFileIO()) throws {
        let fd = try read(url)
        do {try io.syncFile(fd,at:url)} catch {Darwin.close(fd);throw error}
        try io.close(fd,at:url)
        try io.syncDirectory(url.deletingLastPathComponent())
    }
    static func syncDirectory(_ url: URL) throws {try BackupFileIO().syncDirectory(url)}
    static func hash(_ url: URL, limit: Int64 = archiveLimit, cancel: () throws -> Void = {}) throws -> (String, Int64) {
        let fd = try read(url); defer { Darwin.close(fd) }
        var hash = SHA256(), buffer = [UInt8](repeating: 0, count: chunk), total: Int64 = 0
        while true {
            try cancel()
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            try require(count >= 0, "IO_FAILURE"); if count == 0 { break }
            total += Int64(count); try require(total <= limit, "BACKUP_LIMIT")
            hash.update(data: Data(buffer.prefix(count)))
        }
        return (hash.finalize().map { String(format: "%02x", $0) }.joined(), total)
    }
    static func copy(_ source: URL, to destination: URL, limit: Int64, io: BackupFileIO = BackupFileIO(), cancel: () throws -> Void = {}) throws {
        let input = try read(source); defer { Darwin.close(input) }
        let output = try BackupWriter(destination, limit: limit, io: io)
        var buffer = [UInt8](repeating: 0, count: chunk)
        while true {
            try cancel()
            let count = Darwin.read(input, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            try require(count >= 0, "IO_FAILURE"); if count == 0 { break }
            try output.write(Data(buffer.prefix(count)))
        }
        try output.finish()
    }
    static func reserve(at url: URL, additional: Int64) throws {
        try require(additional >= 0 && additional <= 64 * 1024 * 1024 * 1024, "BACKUP_LIMIT")
        let attrs = try FileManager.default.attributesOfFileSystem(forPath: url.path)
        guard let available = attrs[.systemFreeSize] as? NSNumber else { throw CoreRepositoryError("DISK_FULL") }
        try require(available.int64Value >= additional + max(256 * 1024 * 1024, additional / 10), "DISK_FULL")
    }
    static func validHash(_ hash: String) -> Bool { hash.utf8.count == 64 && hash.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    static func canonicalMedia(_ path: String) throws {
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        try require(parts.count == 3 && parts[0] == "media", "BACKUP_PATH_INVALID")
        try CoreSchema.uuid(String(parts[1]))
        let name = parts[2].split(separator: ".", omittingEmptySubsequences: false)
        try require(name.count == 2 && validHash(String(name[0])) && ["jpg", "png", "heic"].contains(name[1]), "BACKUP_PATH_INVALID")
    }
}

final class BackupWriter {
    let url: URL, limit: Int64
    private var fd: Int32
    private let io: BackupFileIO
    private(set) var count: Int64 = 0
    init(_ url: URL, limit: Int64, io: BackupFileIO = BackupFileIO()) throws {
        self.url = url; self.limit = limit; self.io = io
        fd = Darwin.open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw StorageFailure.filesystem(errno) }
        do { try BackupIO.protect(url) } catch { Darwin.close(fd); fd = -1; throw error }
    }
    func write(_ text: String) throws { try write(Data(text.utf8)) }
    func write(_ bytes: Data) throws {
        do {
            try BackupIO.require(fd >= 0 && count + Int64(bytes.count) <= limit, "BACKUP_LIMIT")
            try bytes.withUnsafeBytes { raw in
                var position = 0
                while position < bytes.count {
                    let n = try io.write(fd, raw.baseAddress!.advanced(by: position), bytes.count-position, at:url)
                    if n < 0 && errno == EINTR { continue }
                    if n < 0 {throw StorageFailure.filesystem(errno)}
                    try BackupIO.require(n > 0, "IO_FAILURE"); position += n
                }
            }
            count += Int64(bytes.count)
        } catch {
            // A partial write cannot subsequently be published as a complete file.
            let descriptor = fd; fd = -1
            if descriptor >= 0 {Darwin.close(descriptor)}
            throw error
        }
    }
    func finish() throws {
        try BackupIO.require(fd >= 0, "IO_FAILURE")
        let descriptor = fd; fd = -1
        do {try io.syncFile(descriptor,at:url)} catch {Darwin.close(descriptor);throw error}
        try io.close(descriptor,at:url)
        try io.syncDirectory(url.deletingLastPathComponent())
    }
    deinit { if fd >= 0 { Darwin.close(fd) } }
}

/// Framing is streaming. Only a single bounded row is decoded by the lossless codec.
final class BackupJSONReader {
    private let fd: Int32
    private var buffer = [UInt8](), index = 0, total: Int64 = 0
    private let limit: Int64
    let cancel: () throws -> Void
    init(_ url: URL, limit: Int64, cancel: @escaping () throws -> Void = {}) throws {
        fd = try BackupIO.read(url); self.limit = limit; self.cancel = cancel
    }
    deinit { Darwin.close(fd) }
    private func peek() throws -> UInt8? {
        if index == buffer.count {
            try cancel(); var chunk = [UInt8](repeating: 0, count: BackupIO.chunk)
            var n: Int
            repeat { n = Darwin.read(fd, &chunk, chunk.count) } while n < 0 && errno == EINTR
            try BackupIO.require(n >= 0, "IO_FAILURE"); if n == 0 { return nil }
            total += Int64(n); try BackupIO.require(total <= limit, "BACKUP_LIMIT")
            buffer = Array(chunk.prefix(n)); index = 0
        }
        return buffer[index]
    }
    private func whitespace() throws { while let b = try peek(), [9,10,13,32].contains(b) { index += 1 } }
    private func take(_ value: UInt8) throws { try whitespace(); try BackupIO.require(try peek() == value); index += 1 }
    func value(limit rowLimit: Int = 2*1024*1024, depth baseDepth: Int = 0) throws -> CanonicalValue {
        try whitespace(); var bytes = [UInt8](), depth = 0, quoted = false, escaped = false
        while let byte = try peek() {
            if !quoted && depth == 0 && (byte == 44 || byte == 93 || byte == 125 || [9,10,13,32].contains(byte)) { break }
            bytes.append(byte); index += 1
            try BackupIO.require(bytes.count <= rowLimit, "BACKUP_LIMIT")
            if quoted {
                if escaped { escaped = false } else if byte == 92 { escaped = true } else if byte == 34 { quoted = false }
            } else if byte == 34 { quoted = true }
            else if byte == 91 || byte == 123 { depth += 1; try BackupIO.require(depth + baseDepth <= 16, "BACKUP_LIMIT") }
            else if byte == 93 || byte == 125 { depth -= 1; try BackupIO.require(depth >= 0) }
            if !quoted && depth == 0 && (byte == 34 || byte == 93 || byte == 125) { break }
        }
        guard let text = String(bytes: bytes, encoding: .utf8), !bytes.isEmpty, !quoted, depth == 0 else { throw CoreRepositoryError("BACKUP_SCHEMA_INVALID") }
        return try CanonicalParser.package(text)
    }
    func object(_ consume: (String) throws -> Void) throws {
        try take(123); try whitespace(); if try peek() == 125 { index += 1; return }
        var seen = Set<String>()
        while true {
            // A key is a bounded string; value framing also consumes its final quote.
            let key = try CoreSchema.string(value(limit: 256))
            try BackupIO.require(seen.insert(key).inserted && seen.count <= 32)
            try take(58); try consume(key); try whitespace()
            if try peek() == 125 { index += 1; return }; try take(44)
        }
    }
    func array(_ consume: () throws -> Void) throws {
        try take(91); try whitespace(); if try peek() == 93 { index += 1; return }
        while true { try consume(); try whitespace(); if try peek() == 93 { index += 1; return }; try take(44) }
    }
    func end() throws { try whitespace(); try BackupIO.require(try peek() == nil) }
}

enum BackupSettings {
    static let defaults: CanonicalValue = .object([
        "schemaVersion":.integer(1), "revision":.integer(1), "theme":.string("system"), "localeOverride":.null,
        "units":.string("device"), "personalityEnabled":.boolean(false),
        "reminders":.object(["enabled":.boolean(false), "preferredMinute":.integer(540), "quietStartMinute":.integer(0), "quietEndMinute":.integer(0), "settingsRevision":.integer(1)])
    ])
    static func validate(_ value: CanonicalValue) throws {
        let object = try CoreSchema.object(value)
        try BackupIO.require(Set(object.keys) == Set(defaults.object!.keys) && object["schemaVersion"]?.integer == 1)
        try revision(object["revision"])
        try BackupIO.require(["system","light","dark"].contains(object["theme"]?.text ?? "") && ["device","metric","us"].contains(object["units"]?.text ?? ""))
        try boolean(object["personalityEnabled"])
        if object["localeOverride"]?.isNull != true {
            let locale = try CoreSchema.string(object["localeOverride"])
            try BackupIO.require(!locale.isEmpty && locale.utf8.count <= 80 && locale.split(separator:"-",omittingEmptySubsequences:false).allSatisfy { !$0.isEmpty && $0.utf8.allSatisfy { (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) } })
        }
        let reminders = try CoreSchema.object(object["reminders"])
        try BackupIO.require(Set(reminders.keys) == Set(defaults.object!["reminders"]!.object!.keys))
        try boolean(reminders["enabled"]); try revision(reminders["settingsRevision"])
        for key in ["preferredMinute","quietStartMinute","quietEndMinute"] { try BackupIO.require((0...1439).contains(try CoreSchema.number(reminders[key]))) }
    }
    static func revision(_ value: CanonicalValue?) throws { try BackupIO.require((1...CoreSchema.maxRevision).contains(try CoreSchema.number(value))) }
    static func boolean(_ value: CanonicalValue?) throws { guard case .boolean = value else { throw CoreRepositoryError("BACKUP_SCHEMA_INVALID") } }
}
