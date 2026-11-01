import Flutter
import Foundation
import UIKit
import VerdiNative

final class CoreRepositoryBridge: CoreRepositoryHostApi {
  let repository: CoreRepository
  private var observer: NSObjectProtocol?
  init() throws {
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    repository = CoreRepository(directory: support.appendingPathComponent("VerdiCore", isDirectory: true), catalog: {
      func read(_ asset: String, limit: Int) throws -> Data {
        let key = FlutterDartProject.lookupKey(forAsset: asset)
        guard let path = Bundle.main.path(forResource: key, ofType: nil),
              let size = try FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber, size.intValue <= limit else {
          throw NSError(domain: "VerdiBundledCatalog", code: 1)
        }
        return try Data(contentsOf: URL(fileURLWithPath: path))
      }
      let manifest = try read("assets/catalog/manifest.json", limit: 1024*1024)
      guard let object = try JSONSerialization.jsonObject(with: manifest) as? [String: Any],
            let records = object["assets"] as? [[String: Any]], records.count <= 10_000 else {
        throw NSError(domain: "VerdiBundledCatalog", code: 1)
      }
      var assets: [String: Data] = [:]
      for record in records {
        guard let name = record["resourceName"] as? String,
              name.range(of: "^[a-z][a-z0-9_]{0,63}$", options: .regularExpression) != nil,
              assets[name] == nil else { throw NSError(domain: "VerdiBundledCatalog", code: 1) }
        let path = name == "generic_plant" ? "assets/illustrations/empty-plants.png" : "assets/catalog_art/\(name).png"
        assets[name] = try read(path, limit: 8*1024*1024)
      }
      return try BundledCatalogBytes(manifest: manifest,
        entries: read("assets/catalog/entries.json", limit: 32*1024*1024), assets: assets)
    })
    repository.storeAuthority = StoreAuthority(configuration:.preview(bundleID:Bundle.main.bundleIdentifier ?? "dev.verdi.preview"),directory:support.appendingPathComponent("VerdiStore-local",isDirectory:true))
    observer = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: nil) { [weak self] _ in
      self?.repository.invalidateUndo()
    }
  }
  deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
  func callCore(operation: String, canonicalBody: String) throws -> String {
    do { return try repository.call(operation: operation, body: canonicalBody) }
    catch let error as CoreRepositoryError { throw PigeonError(code: error.code, message: nil, details: nil) }
    catch { throw PigeonError(code: "STORAGE_UNAVAILABLE", message: nil, details: nil) }
  }
}
