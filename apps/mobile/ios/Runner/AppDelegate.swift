import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  #if DEBUG
  private var draftBridge: DraftRepositoryBridge?
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
    // Integration-only namespace: never replaces the synthetic collection UI.
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
