import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  #if DEBUG
  private var draftBridge: DraftRepositoryBridge?
  private var coreBridge: CoreRepositoryBridge?
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if DEBUG
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VerdiCoreRepository") {
      do {
        let bridge = try CoreRepositoryBridge()
        coreBridge = bridge
        CoreRepositoryHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: bridge)
      } catch { coreBridge = nil }
    }
    // Preserve the separate isolated-draft integration namespace.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VerdiDraftIntegration") {
      do {
        let bridge = try DraftRepositoryBridge()
        draftBridge = bridge
        DraftRepositoryHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: bridge)
      } catch {
        // No fallback database or writable session. Host channel remains absent.
        draftBridge = nil
      }
    }
    #endif
  }
}
