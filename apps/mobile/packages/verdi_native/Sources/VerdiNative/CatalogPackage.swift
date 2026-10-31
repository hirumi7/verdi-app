import Foundation
import CryptoKit
import ImageIO

public struct BundledCatalogBytes {
    public let manifest: Data
    public let entries: Data
    public let assets: [String:Data]
    public init(manifest: Data, entries: Data, assets: [String:Data]) { self.manifest=manifest;self.entries=entries;self.assets=assets }
}
struct CatalogPackage {
    let manifest: CanonicalValue
    let entries: [CanonicalValue]
    let version: String
    static let popular = ["monstera_deliciosa","epipremnum_aureum","dracaena_trifasciata","zamioculcas_zamiifolia","chlorophytum_comosum","spathiphyllum_wallisii","ficus_lyrata","ficus_elastica","aloe_vera","philodendron_hederaceum","philodendron_hederaceum_brasil","pilea_peperomioides","hedera_helix","nephrolepis_exaltata","goeppertia_orbifolia","goeppertia_insignis","maranta_leuconeura","anthurium_andraeanum","dracaena_marginata","dracaena_fragrans","crassula_ovata","echeveria_elegans","haworthiopsis_fasciata","curio_rowleyanus"].map {"sp_"+$0}
    static func require(_ value: Bool) throws { if !value { throw CoreRepositoryError("CATALOG_INVALID") } }
    static func digest(_ bytes: Data)->String {SHA256.hash(data:bytes).map {String(format:"%02x",$0)}.joined()}
    static func keys(_ object: [String:CanonicalValue], _ names: [String]) throws {try require(Set(object.keys)==Set(names))}
    @discardableResult static func text(_ v: CanonicalValue?, _ max: Int = 4000, empty: Bool = false) throws -> String {
        guard let s=v?.text else {throw CoreRepositoryError("CATALOG_INVALID")}
        try require(s.count<=max && (empty || !CoreRegistry.trimLikeDart(s).isEmpty) && !s.unicodeScalars.contains {$0.value<32 && ![9,10,13].contains($0.value)})
        return s
    }
    static func matches(_ v: CanonicalValue?, _ pattern: String) throws -> String {
        let s=try text(v); try require(s.range(of:pattern,options:.regularExpression) != nil);return s
    }
    static func array(_ v: CanonicalValue?, max: Int = 10000) throws -> [CanonicalValue] {let a=try CoreSchema.array(v);try require(a.count<=max);return a}
    static func instant(_ v: CanonicalValue?) throws {
        let s=try text(v,80);let f=ISO8601DateFormatter(); f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        try require(s.range(of:"^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\\.[0-9]{3}Z$",options:.regularExpression) != nil && f.date(from:s) != nil)
    }
    static func review(_ v: CanonicalValue?, refs: Set<String>, rights: Bool = false) throws {
        let m=try CoreSchema.object(v)
        try keys(m,["reviewer","actorType","reviewedAt","outcome","scope","evidenceRefs","findings"]+(rights ? ["permissionBasis","licenseOrPermission","redistributionScope","attributionText","attributionNotRequiredReason","restrictions"]:[]))
        _=try text(m["reviewer"],200);_=try text(m["scope"]);try instant(m["reviewedAt"])
        try require(["human","ai"].contains(m["actorType"]?.text ?? "") && m["outcome"]?.text=="pass")
        let evidence=try array(m["evidenceRefs"]);try require(!evidence.isEmpty)
        for ref in evidence {try require(refs.contains(try text(ref,80)))}
        for finding in try array(m["findings"]) {_=try text(finding)}
        if rights {
            try require(["owned","licensed","public_domain","other_documented"].contains(m["permissionBasis"]?.text ?? ""))
            _=try text(m["licenseOrPermission"]);_=try text(m["redistributionScope"])
            let attribution=try text(m["attributionText"],empty:true)
            if attribution.isEmpty {_=try text(m["attributionNotRequiredReason"])}
            else if m["attributionNotRequiredReason"]?.isNull != true {_=try text(m["attributionNotRequiredReason"])}
            for restriction in try array(m["restrictions"]) {_=try text(restriction)}
        }
    }
    static func sources(_ value: CanonicalValue?) throws -> Set<String> {
        var refs:Set<String>=[]
        for v in try array(value) {
            let m=try CoreSchema.object(v), remote=m["publicUrl"] != nil
            try keys(m,["ref","title","publisherOrCreator","locator","capturedAt","captureSha256",remote ? "publicUrl":"retainedEvidenceRef"])
            let ref=try text(m["ref"],80);try require(!ref.contains(where:{$0.isWhitespace}) && refs.insert(ref).inserted)
            for key in ["title","publisherOrCreator","locator"] {_=try text(m[key])}
            try instant(m["capturedAt"]);_=try matches(m["captureSha256"],"^[a-f0-9]{64}$")
            if remote {
                let url=URLComponents(string:try text(m["publicUrl"],2048))
                try require(url?.scheme=="https" && url?.host?.isEmpty==false && url?.user==nil && url?.password==nil)
            } else {let ref=try text(m["retainedEvidenceRef"]);try require(!ref.hasPrefix("/") && !ref.contains("file://"))}
        }
        try require(!refs.isEmpty);return refs
    }
    static func suggestions(_ v: CanonicalValue?) throws {
        var kinds:Set<String>=[]
        for item in try array(v,max:5) {
            let m=try CoreSchema.object(item);try keys(m,["careKind","interval","context","sourceLabel"])
            let kind=try text(m["careKind"]);try require(["water","fertilize","mist","repot","rotate"].contains(kind) && kinds.insert(kind).inserted)
            let i=try CoreSchema.object(m["interval"]);try keys(i,["count","unit"])
            let count=try CoreSchema.number(i["count"]);try require((1...9999).contains(count) && ["day","week","month","year"].contains(i["unit"]?.text ?? ""))
            _=try text(m["context"],600);_=try text(m["sourceLabel"],200)
        }
    }
    static func entry(_ value: CanonicalValue) throws -> String {
        try require(try CanonicalCommand.bytes(value).count<=256*1024)
        let e=try CoreSchema.object(value);try keys(e,["id","entryVersion","lifecycle","commonName","scientificName","altNames","category","difficulty","light","careNotes","suggestions","toxicity","sources","contentReview","textRightsReview"])
        let id=try matches(e["id"],"^[A-Za-z0-9_-]{1,128}$"), revision=try CoreSchema.number(e["entryVersion"])
        try require(revision>0 && revision<=CoreSchema.maxRevision && ["active","retired"].contains(e["lifecycle"]?.text ?? ""))
        _=try text(e["commonName"],160);_=try text(e["scientificName"],160)
        for a in try array(e["altNames"],max:100) {_=try text(a,160)}
        try require(["foliage","succulent","cactus","fern","palm","flowering","herb","other"].contains(e["category"]?.text ?? "") && ["easy","moderate","fussy","unknown"].contains(e["difficulty"]?.text ?? "") && ["unknown","low","medium","bright-indirect","direct"].contains(e["light"]?.text ?? ""))
        _=try text(e["careNotes"],2000,empty:true);try suggestions(e["suggestions"])
        let refs=try sources(e["sources"]);try review(e["contentReview"],refs:refs);try review(e["textRightsReview"],refs:refs,rights:true)
        let t=try CoreSchema.object(e["toxicity"]);try keys(t,["value","animalScope","sourceRefs","qualification"])
        try require(["toxic","non-toxic","unknown"].contains(t["value"]?.text ?? ""));_=try text(t["qualification"])
        let scope=try array(t["animalScope"]), evidence=try array(t["sourceRefs"])
        for v in scope {_=try text(v)};for v in evidence {try require(refs.contains(try text(v,80)))}
        if t["value"]?.text != "unknown" {try require(!scope.isEmpty && !evidence.isEmpty)}
        return id
    }
    static func manifestStructure(_ meta: [String:CanonicalValue]) throws {
        try keys(meta,["schemaVersion","catalogVersion","normalizationVersion","entriesSha256","entryCount","preparedAt","preparedBy","entryIds","popularPolicyId","popularIds","genericAssetId","assets","speciesArt"])
        try require(meta["schemaVersion"]?.integer==1 && meta["normalizationVersion"]?.text=="verdi-name-v1")
        _=try matches(meta["catalogVersion"],"^[a-z0-9][a-z0-9._-]{0,79}$");_=try matches(meta["entriesSha256"],"^[a-f0-9]{64}$")
        try instant(meta["preparedAt"]);_=try text(meta["preparedBy"],200)
        let ids=try array(meta["entryIds"]).map{try matches($0,"^[A-Za-z0-9_-]{1,128}$")}
        try require(Set(ids).count==ids.count && meta["entryCount"]?.integer==Int64(ids.count))
        try require(meta["popularPolicyId"]?.text=="popular-v1" && (try array(meta["popularIds"]).map{try text($0,128)})==popular && Set(ids).isSuperset(of:popular))
        var assets:Set<String>=[],names:Set<String>=[]
        for value in try array(meta["assets"]) {
            let a=try CoreSchema.object(value);try keys(a,["id","resourceName","sha256","mimeType","pixelWidth","pixelHeight","provenance","rightsReview"])
            let id=try matches(a["id"],"^[a-z][a-z0-9_]{0,63}$"),name=try matches(a["resourceName"],"^[a-z][a-z0-9_]{0,63}$")
            try require(assets.insert(id).inserted && names.insert(name).inserted && a["mimeType"]?.text=="image/png")
            _=try matches(a["sha256"],"^[a-f0-9]{64}$")
            let w=try CoreSchema.number(a["pixelWidth"]),h=try CoreSchema.number(a["pixelHeight"])
            try require(w>0 && h>0 && w<=32768 && h<=32768)
            try review(a["rightsReview"],refs:sources(a["provenance"]),rights:true)
        }
        try require(assets.contains(try text(meta["genericAssetId"],64)))
        var mapped:Set<String>=[]
        for value in try array(meta["speciesArt"]) {
            let a=try CoreSchema.object(value);try keys(a,["catalogId","assetId"])
            let id=try text(a["catalogId"],128)
            try require(Set(ids).contains(id) && mapped.insert(id).inserted && assets.contains(try text(a["assetId"],64)))
        }
    }
    init(_ bytes: BundledCatalogBytes) throws {
        try Self.require(bytes.manifest.count+bytes.entries.count<=32*1024*1024 && bytes.manifest.count<=1024*1024)
        guard let m=String(data:bytes.manifest,encoding:.utf8), let e=String(data:bytes.entries,encoding:.utf8) else {throw CoreRepositoryError("CATALOG_INVALID")}
        manifest=try CanonicalParser.package(m);entries=try Self.array(CanonicalParser.package(e));let meta=try CoreSchema.object(manifest)
        try Self.manifestStructure(meta)
        try Self.require(try CanonicalCommand.bytes(manifest).count<=1024*1024)
        try Self.keys(meta,["schemaVersion","catalogVersion","normalizationVersion","entriesSha256","entryCount","preparedAt","preparedBy","entryIds","popularPolicyId","popularIds","genericAssetId","assets","speciesArt"])
        try Self.require(meta["schemaVersion"]?.integer==1 && meta["normalizationVersion"]?.text=="verdi-name-v1" && meta["entriesSha256"]?.text==Self.digest(bytes.entries) && meta["entryCount"]?.integer==Int64(entries.count))
        version=try Self.matches(meta["catalogVersion"],"^[a-z0-9][a-z0-9._-]{0,79}$");try Self.instant(meta["preparedAt"]);_=try Self.text(meta["preparedBy"],200)
        let ids=try entries.map(Self.entry), inventory=try Self.array(meta["entryIds"]).map {try Self.text($0,128)}
        try Self.require(Set(ids).count==ids.count && Set(inventory)==Set(ids) && inventory.count==ids.count)
        let popular=try Self.array(meta["popularIds"]).map {try Self.text($0,128)}
        try Self.require(meta["popularPolicyId"]?.text=="popular-v1" && popular==Self.popular && Set(entries.filter{$0.object?["lifecycle"]?.text=="active"}.compactMap{$0.object?["id"]?.text}).isSuperset(of:popular))
        var assets:Set<String>=[]
        for value in try Self.array(meta["assets"]) {
            let a=try CoreSchema.object(value);try Self.keys(a,["id","resourceName","sha256","mimeType","pixelWidth","pixelHeight","provenance","rightsReview"])
            let id=try Self.matches(a["id"],"^[a-z][a-z0-9_]{0,63}$"), name=try Self.matches(a["resourceName"],"^[a-z][a-z0-9_]{0,63}$")
            try Self.require(assets.insert(id).inserted && a["mimeType"]?.text=="image/png")
            let refs=try Self.sources(a["provenance"]);try Self.review(a["rightsReview"],refs:refs,rights:true)
            guard let raw=bytes.assets[name], raw.count>=24 else {throw CoreRepositoryError("CATALOG_INVALID")}
            try Self.require(Self.digest(raw)==a["sha256"]?.text && Array(raw.prefix(8))==[137,80,78,71,13,10,26,10])
            guard let imageSource=CGImageSourceCreateWithData(raw as CFData,nil), CGImageSourceCreateImageAtIndex(imageSource,0,nil) != nil else {throw CoreRepositoryError("CATALOG_INVALID")}
            let w=raw[16..<20].reduce(UInt32(0)){($0<<8)|UInt32($1)},h=raw[20..<24].reduce(UInt32(0)){($0<<8)|UInt32($1)}
            try Self.require(w>0 && h>0 && a["pixelWidth"]?.integer==Int64(w) && a["pixelHeight"]?.integer==Int64(h))
        }
        try Self.require(assets.contains(try Self.text(meta["genericAssetId"],64)))
        var mapped:Set<String>=[]
        for value in try Self.array(meta["speciesArt"]) {
            let a=try CoreSchema.object(value);try Self.keys(a,["catalogId","assetId"])
            let id=try Self.text(a["catalogId"],128)
            try Self.require(Set(ids).contains(id) && mapped.insert(id).inserted && assets.contains(try Self.text(a["assetId"],64)))
        }
    }
    static func selection(_ entry: CanonicalValue, version: String) throws -> CanonicalValue {
        let e=try CoreSchema.object(entry)
        return .object(["catalogVersion":.string(version),"speciesNameSnapshot":.string(CoreRegistry.trimLikeDart(try text(e["scientificName"],160))),"suggestions":e["suggestions"]!])
    }
}
