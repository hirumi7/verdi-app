import Foundation
import Security
import StoreKit

public struct StoreConfiguration: Equatable {
    public let productID: String
    public let bundleID: String
    public let environment: String
    public init(productID: String, bundleID: String, environment: String) {
        self.productID=productID; self.bundleID=bundleID; self.environment=environment
    }
    public static func preview(bundleID: String) -> Self {
        Self(productID:"dev.verdi.preview.pro.local",bundleID:bundleID,environment:AppStore.Environment.xcode.rawValue)
    }
    var namespace: String { "verdi.store.v1.\(bundleID).\(productID).\(environment)" }
}

struct StoreEvidence: Codable, Equatable {
    let productID: String, bundleID: String, environment: String, transactionID: String, originalID: String
    let signedAt: Date, purchasedAt: Date, revokedAt: Date?, recordedAt: Date
    func matches(_ c: StoreConfiguration) -> Bool {
        productID == c.productID && bundleID == c.bundleID && environment == c.environment &&
        UInt64(transactionID) != nil && UInt64(originalID) != nil &&
        signedAt.timeIntervalSince1970.isFinite && purchasedAt.timeIntervalSince1970.isFinite &&
        (revokedAt?.timeIntervalSince1970.isFinite ?? true)
    }
}
struct StoreCacheBody: Codable {
    let version: Int
    let installation: String
    let records: [StoreEvidence]
}
protocol StoreCache {
    func read() throws -> Data?
    func write(_ value: Data) throws
}
struct KeychainStoreCache: StoreCache {
    let namespace: String
    private var query: [String:Any] { [kSecClass as String:kSecClassGenericPassword,
        kSecAttrService as String:namespace,kSecAttrAccount as String:"verified-entitlement",
        kSecAttrSynchronizable as String:false] }
    func read() throws -> Data? {
        var q=query; q[kSecReturnData as String]=true; q[kSecMatchLimit as String]=kSecMatchLimitOne
        var result: CFTypeRef?
        let status=SecItemCopyMatching(q as CFDictionary,&result)
        if status == errSecItemNotFound {return nil}
        guard status == errSecSuccess, let data=result as? Data, data.count <= 1_048_576 else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")}
        return data
    }
    func write(_ value: Data) throws {
        let attributes:[String:Any]=[kSecValueData as String:value,kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        var status=SecItemUpdate(query as CFDictionary,attributes as CFDictionary)
        if status == errSecItemNotFound {
            status=SecItemAdd(query.merging(attributes){_,new in new} as CFDictionary,nil)
        }
        guard status == errSecSuccess else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")}
    }
}

public struct StoreCapability {
    public let pro: Bool
    public let revision: Int64
    let basis: String
    let freshness: String
    let lastVerified: Date?
    var value: CanonicalValue { .object([
        "access":.string(pro ? "pro":"free"),"capabilityRevision":.integer(revision),
        "basis":.string(basis),"freshness":.string(freshness),
        "lastVerifiedAt":lastVerified.map{.string(CoreClockFrame.capture($0).instant)} ?? .null]) }
    static let free = Self(pro:false,revision:1,basis:"noEvidence",freshness:"unknown",lastVerified:nil)
}

/// Native-only authority. No channel accepts evidence or a capability flag.
public final class StoreAuthority {
    let configuration: StoreConfiguration
    private let lock=NSRecursiveLock()
    private var cache: StoreCache?
    private var installation=""
    private var records:[String:StoreEvidence]=[:]
    private var pendingRevocations:[String:StoreEvidence]=[:]
    private var revision:Int64=1
    private var loaded=false, unknown=true, restricted=false
    private var disk: StoreDisk?
    private var directory:URL?
    public init(configuration: StoreConfiguration, directory: URL) {
        self.configuration=configuration
        self.directory=directory
        do {try load()} catch {unknown=true}
    }
    init(configuration: StoreConfiguration, installation: String, cache: StoreCache, disk: StoreDisk? = nil) {
        self.configuration=configuration;self.installation=installation;self.cache=cache;self.disk=disk
        do {try load()} catch {unknown=true}
    }
    func withCapability<T>(_ body:(StoreCapability)throws->T) rethrows -> T {
        lock.lock();defer{lock.unlock()};return try body(snapshot())
    }
    private func snapshot() -> StoreCapability {
        let pro = !restricted && records.values.contains{$0.revokedAt == nil}
        let newest=records.values.map(\.signedAt).max()
        return StoreCapability(pro:pro,revision:revision,
            basis:pro ? (unknown ? "verifiedCache":"verifiedCurrent") : records.isEmpty ? "noEvidence":"verifiedRevocation",
            freshness:unknown ? (pro ? "cached":"unknown"):"current",lastVerified:newest)
    }
    func load() throws {
        lock.lock();defer{lock.unlock()}
        if disk == nil,let directory {
            let opened=try StoreDisk(directory:directory)
            disk=opened;installation=opened.installation
            cache=KeychainStoreCache(namespace:configuration.namespace)
        }
        guard let cache else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")}
        if loaded {return}
        let previous=snapshot().pro
        if let bytes=try cache.read() {
            let decoded=try JSONDecoder().decode(StoreCacheBody.self,from:bytes)
            guard decoded.version == 1, decoded.records.count <= 1024 else {throw CoreRepositoryError("STORE_CACHE_INVALID")}
            if decoded.installation == installation {
                guard decoded.records.allSatisfy({$0.matches(configuration)}),Set(decoded.records.map(\.originalID)).count == decoded.records.count else {throw CoreRepositoryError("STORE_CACHE_INVALID")}
                records=Dictionary(uniqueKeysWithValues:decoded.records.map{($0.originalID,$0)})
            }
        }
        loaded=true;unknown=true
        if previous != snapshot().pro {revision += 1}
    }
    func markUnknown() {lock.lock();unknown=true;lock.unlock()}
    /// Only the StoreKit adapter calls this after .verified; internal for fault tests.
    func accept(_ evidence: StoreEvidence) throws {
        lock.lock();defer{lock.unlock()}
        guard evidence.matches(configuration) else {throw CoreRepositoryError("STORE_UNVERIFIED")}
        try load()
        let old=snapshot().pro
        var next=records.merging(pendingRevocations){_,new in new}
        if let previous=next[evidence.originalID] {
            if previous.signedAt > evidence.signedAt {return}
            if previous.signedAt == evidence.signedAt && previous.revokedAt != nil && evidence.revokedAt == nil {return}
        }
        next[evidence.originalID]=evidence
        guard next.count <= 1024,let cache else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")}
        do {
            let data=try JSONEncoder().encode(StoreCacheBody(version:1,installation:installation,records:next.values.sorted{$0.originalID < $1.originalID}))
            guard data.count <= 1_048_576 else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")}
            try cache.write(data)
        } catch {
            unknown=true
            if evidence.revokedAt != nil {pendingRevocations[evidence.originalID]=evidence;restricted=true;if old {revision += 1}}
            throw error
        }
        records=next;pendingRevocations.removeAll();restricted=false;unknown=false
        if old != snapshot().pro {revision += 1}
    }
    func state() -> CanonicalValue {withCapability{$0.value}}
    func diskStore() throws -> StoreDisk {
        lock.lock();defer{lock.unlock()}
        if disk == nil {try load()}
        guard let disk else {throw CoreRepositoryError("STORE_CACHE_UNAVAILABLE")};return disk
    }
}
