import Foundation
import Darwin

struct StoreAttempt: Codable, Equatable {
    let intentID: String, datasetID: String
    let commandID: String?, payloadHash: String?, draftID: String?
    let draftRevision: Int64?
    var phase: String
    var continuationAbandoned: Bool
    var priorPending: Bool? = nil
    var unresolvedPending: Bool {phase == "pending" || priorPending == true}
}
struct StoreInstallation: Codable {
    let version: Int
    let installation: String
    var attempt: StoreAttempt?
}
/// Installation state is outside all core generations and content exports.
final class StoreDisk {
    let directory: URL
    let file: URL
    let installation: String
    init(directory: URL) throws {
        self.directory=directory;file=directory.appendingPathComponent("state.json")
        let manager=FileManager.default
        if try Self.missing(directory) {
            try manager.createDirectory(at:directory,withIntermediateDirectories:true)
            try Self.protect(directory)
        }
        try BackupIO.syncDirectory(directory.deletingLastPathComponent())
        if try Self.missing(file) {
            let fresh=StoreInstallation(version:1,installation:UUID().uuidString.lowercased(),attempt:nil)
            try Self.write(fresh,to:file)
        }
        try Self.protect(directory);try Self.protect(file)
        let body=try Self.read(file)
        installation=body.installation
    }
    func read() throws -> StoreInstallation {
        let body=try Self.read(file)
        guard body.installation == installation else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        return body
    }
    func save(_ attempt: StoreAttempt?) throws {
        try Self.write(StoreInstallation(version:1,installation:installation,attempt:attempt),to:file)
    }
    private static func read(_ url:URL) throws -> StoreInstallation {
        guard let size=try FileManager.default.attributesOfItem(atPath:url.path)[.size] as? NSNumber,size.intValue <= 32768 else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        let body=try JSONDecoder().decode(StoreInstallation.self,from:Data(contentsOf:url))
        guard body.version == 1, UUID(uuidString:body.installation) != nil else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        if let a=body.attempt {
            guard UUID(uuidString:a.intentID) != nil,UUID(uuidString:a.datasetID) != nil,
                  ["prepared","purchasing","pending","verified","cancelled","failed","unverified","recoveryRequired","persistencePending"].contains(a.phase),
                  (a.commandID == nil) == (a.payloadHash == nil),
                  a.commandID.map({UUID(uuidString:$0) != nil}) ?? true,
                  a.payloadHash.map({$0.count == 64 && $0.allSatisfy{"0123456789abcdef".contains($0)}}) ?? true,
                  (a.draftID == nil) == (a.draftRevision == nil),
                  a.draftID.map({UUID(uuidString:$0) != nil}) ?? true,
                  a.draftRevision.map({$0 > 0}) ?? true else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        }
        return body
    }
    private static func write(_ body:StoreInstallation,to file:URL) throws {
        let data=try JSONEncoder().encode(body)
        #if os(iOS)
        try data.write(to:file,options:[.atomic,.completeFileProtection])
        #else
        try data.write(to:file,options:.atomic)
        #endif
        try protect(file)
        let fd=Darwin.open(file.path,O_RDONLY | O_NOFOLLOW)
        guard fd >= 0 else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        defer{Darwin.close(fd)}
        guard fsync(fd) == 0 else {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        try BackupIO.syncDirectory(file.deletingLastPathComponent())
    }
    private static func missing(_ url:URL) throws -> Bool {
        do {_ = try FileManager.default.attributesOfItem(atPath:url.path);return false}
        catch let error as NSError where error.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError,NSFileReadNoSuchFileError].contains(error.code) {return true}
    }
    private static func protect(_ url:URL) throws {
        #if os(iOS)
        try FileManager.default.setAttributes([.protectionKey:FileProtectionType.complete],ofItemAtPath:url.path)
        let value=try FileManager.default.attributesOfItem(atPath:url.path)[.protectionKey]
        let actual=(value as? FileProtectionType)?.rawValue ?? (value as? String)
        if CoreRepository.deviceProtectionRequired && actual != FileProtectionType.complete.rawValue {throw CoreRepositoryError("STORE_RECOVERY_UNAVAILABLE")}
        #endif
        try BackupIO.excludeFromOSBackup(url)
    }
}
