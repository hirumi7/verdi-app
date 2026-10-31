import Flutter
import Foundation
import UIKit
import VerdiNative

final class CoreRepositoryBridge: CoreRepositoryHostApi {
  private let repository: CoreRepository
  private var observer: NSObjectProtocol?
  init() throws {
    let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    repository = CoreRepository(directory: support.appendingPathComponent("VerdiCore", isDirectory: true))
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
