import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  #if DEBUG
  private var draftBridge: DraftRepositoryBridge?
  private var coreBridge: CoreRepositoryBridge?
  private var cardBridge: CardPlatformBridge?
  private var mediaBridge: MediaPlatformBridge?
  private var backupBridge: BackupPlatformBridge?
  private var storeBridge: StorePlatformBridge?
  private var reminderBridge: ReminderPlatformBridge?
  #endif

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    #if DEBUG
    // UIKit needs the notification delegate before launch finishes. Creating
    // these owners does not open the core database or request authorization.
    try? prepareNativeOwners()
    #endif
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  #if DEBUG
  private func prepareNativeOwners() throws {
    if coreBridge == nil { coreBridge = try CoreRepositoryBridge() }
    if ProcessInfo.processInfo.environment["VERDI_NATIVE_STORE_TESTS"] != "1", storeBridge == nil, let coreBridge, let authority=coreBridge.repository.storeAuthority {
      storeBridge=StorePlatformBridge(core:coreBridge.repository,authority:authority)
    }
    if reminderBridge == nil, let coreBridge {
      reminderBridge = ReminderPlatformBridge(repository: coreBridge.repository)
    }
  }
  #endif

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    #if DEBUG
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VerdiCoreRepository") {
      do {
        try prepareNativeOwners()
        guard let bridge = coreBridge, let reminders = reminderBridge else { return }
        if let storeBridge {
          storeBridge.attach(registrar.messenger())
          StorePlatformHostApiSetup.setUp(binaryMessenger:registrar.messenger(),api:storeBridge)
        }
        reminders.attach(registrar.messenger())
        ReminderPlatformHostApiSetup.setUp(binaryMessenger:registrar.messenger(),api:reminders)
        let cards = CardPlatformBridge(repository:bridge.repository)
        cardBridge = cards
        CardPlatformHostApiSetup.setUp(binaryMessenger:registrar.messenger(),api:cards)
        let media = MediaPlatformBridge(repository:bridge.repository)
        mediaBridge = media
        let backup = BackupPlatformBridge(repository:bridge.repository)
        backupBridge = backup
        BackupPlatformHostApiSetup.setUp(binaryMessenger:registrar.messenger(),api:backup)
        MediaPlatformHostApiSetup.setUp(binaryMessenger:registrar.messenger(),api:media)
        CoreRepositoryHostApiSetup.setUp(binaryMessenger: registrar.messenger(), api: bridge)
      } catch {
        // Keep any early owner/tap intact. Missing channels leave core startup
        // unavailable rather than replacing it with another collection.
      }
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
