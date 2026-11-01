import Foundation
import XCTest
@testable import VerdiNative

func catalogBytes() throws -> BundledCatalogBytes {
    func bytes(_ name: String,_ ext: String) throws -> Data {try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:name,withExtension:ext,subdirectory:"Fixtures/catalog")))}
    let manifest = try bytes("manifest", "json")
    let object = try XCTUnwrap(JSONSerialization.jsonObject(with: manifest) as? [String: Any])
    let records = try XCTUnwrap(object["assets"] as? [[String: Any]])
    var assets: [String: Data] = [:]
    for record in records { let name = try XCTUnwrap(record["resourceName"] as? String); assets[name] = try bytes(name == "generic_plant" ? "generic" : name, "png") }
    return try BundledCatalogBytes(manifest:manifest,entries:bytes("entries","json"),assets:assets)
}
final class CatalogTests: XCTestCase {
    func mutate(_ work: (inout [String:CanonicalValue],inout [CanonicalValue]) throws -> Void) throws -> BundledCatalogBytes {
        let bytes=try catalogBytes();var manifest=try CoreSchema.object(CanonicalParser.package(String(decoding:bytes.manifest,as:UTF8.self))),entries=try CoreSchema.array(CanonicalParser.package(String(decoding:bytes.entries,as:UTF8.self)))
        try work(&manifest,&entries)
        let raw=try CanonicalCommand.bytes(.array(entries));manifest["entriesSha256"] = .string(CatalogPackage.digest(raw))
        return try BundledCatalogBytes(manifest:CanonicalCommand.bytes(.object(manifest)),entries:raw,assets:bytes.assets)
    }
    func testRealReviewedPackageAndLosslessWhitespaceParser() throws {
        let bytes=try catalogBytes(),package=try CatalogPackage(bytes)
        XCTAssertEqual(package.entries.count,24)
        XCTAssertEqual(try CatalogPackage(BundledCatalogBytes(manifest:Data(" \n".utf8)+bytes.manifest,entries:bytes.entries,assets:bytes.assets)).version,package.version)
        XCTAssertThrowsError(try CanonicalParser.package("{\"a\":1, \"a\":2}"))
        XCTAssertThrowsError(try CanonicalParser.parse(" {\"a\":1}"))
    }
    func testBotanicalMappingsAndMissingOrAlteredExportsReject() throws {
        let original = try catalogBytes()
        let manifest = try CoreSchema.object(CanonicalParser.package(String(decoding: original.manifest, as: UTF8.self)))
        let mappings = try CoreSchema.array(manifest["speciesArt"]!)
        XCTAssertEqual(mappings.count, 7)
        XCTAssertEqual(original.assets.count, 8)
        XCTAssertEqual(Set(mappings.compactMap { $0.object?["catalogId"]?.text }).count, 7)
        for name in original.assets.keys where name != "generic_plant" {
            var missing = original.assets
            missing.removeValue(forKey: name)
            XCTAssertThrowsError(try CatalogPackage(BundledCatalogBytes(manifest: original.manifest, entries: original.entries, assets: missing)), name)
            var corrupt = original.assets
            corrupt[name] = original.assets["generic_plant"]!
            XCTAssertThrowsError(try CatalogPackage(BundledCatalogBytes(manifest: original.manifest, entries: original.entries, assets: corrupt)), name)
        }
        let pending = try mutate { manifest, _ in
            var assets = manifest["assets"]!.array!
            var record = assets[1].object!
            var rights = record["rightsReview"]!.object!
            rights["outcome"] = .string("pending")
            record["rightsReview"] = .object(rights)
            assets[1] = .object(record)
            manifest["assets"] = .array(assets)
        }
        XCTAssertThrowsError(try CatalogPackage(pending))
    }
    func testInvalidReviewsPopularHashAndCorruptAssetReject() throws {
        for mutateEntry in ["review","toxicity","duplicate","popular","name"] {
            let bytes=try mutate { m,e in
                var first=e[0].object!
                switch mutateEntry {
                case "review": var r=first["contentReview"]!.object!;r["outcome"] = .string("pending");first["contentReview"] = .object(r);e[0] = .object(first)
                case "toxicity": var t=first["toxicity"]!.object!;t["value"] = .string("non-toxic");first["toxicity"] = .object(t);e[0] = .object(first)
                case "duplicate":e[1]=e[0]
                case "popular": m["popularIds"] = .array(Array(m["popularIds"]!.array!.dropFirst()))
                default:first["scientificName"] = .string(String(repeating:"a",count:161));e[0] = .object(first)
                }
            }
            XCTAssertThrowsError(try CatalogPackage(bytes),mutateEntry)
        }
        let original=try catalogBytes()
        XCTAssertThrowsError(try CatalogPackage(BundledCatalogBytes(manifest:original.manifest,entries:original.entries+Data(" ".utf8),assets:original.assets)))
        XCTAssertThrowsError(try CatalogPackage(BundledCatalogBytes(manifest:original.manifest,entries:original.entries,assets:["generic_plant":Data(repeating:0,count:40)])))
        _ = try CatalogPackage(mutate { _,e in var x=e[0].object!;x["scientificName"] = .string(String(repeating:"a",count:160));e[0] = .object(x) })
    }
    func testFailedUpdateKeepsPriorHeadAndUserRevisions() throws {
        let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);defer{try? FileManager.default.removeItem(at:dir)}
        var candidate=try catalogBytes();let repo=CoreRepository(directory:dir,catalog:{candidate})
        let opened=try CanonicalParser.parse(repo.call(operation:"open",body:"{\"profile\":\"custom_core_v1\",\"protocolVersion\":1}")),session=opened.object!["sessionId"]!
        func call(_ op:String) throws -> CanonicalValue {try CanonicalParser.parse(repo.call(operation:op,body:CanonicalValue.object(["sessionId":session]).json()))}
        let meta=try call("metadata"),before=try call("catalogMeta")
        candidate=try mutate {_,e in var x=e[0].object!;x["commonName"] = .string("Changed without version");e[0] = .object(x)}
        _=try call("retryCatalog")
        XCTAssertEqual(try call("catalogMeta").object?["version"]?.text,before.object?["version"]?.text)
        XCTAssertEqual(try call("catalogMeta").object?["limitation"]?.text,"CATALOG_UNAVAILABLE")
        XCTAssertEqual(try call("metadata").json(),try meta.json())
        _=try call("close")
    }
}
