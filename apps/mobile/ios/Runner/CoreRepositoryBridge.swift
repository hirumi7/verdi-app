import Flutter
import Foundation
import UIKit
import VerdiNative

final class CoreRepositoryBridge: CoreRepositoryHostApi {
  private let repository: CoreRepository
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
      return try BundledCatalogBytes(
        manifest: read("assets/catalog/manifest.json", limit: 1024*1024),
        entries: read("assets/catalog/entries.json", limit: 32*1024*1024),
        assets: ["generic_plant": read("assets/illustrations/empty-plants.png", limit: 8*1024*1024)])
    })
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
