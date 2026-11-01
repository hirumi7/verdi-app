import Flutter
import Foundation
import UIKit
import VerdiNative

final class StorePlatformBridge: StorePlatformHostApi {
    let coordinator: StoreCoordinator
    private var events: StorePlatformEventsApi?
    private var foreground: NSObjectProtocol?
    init(core:CoreRepository, authority:StoreAuthority) {
        coordinator=StoreCoordinator(core:core,authority:authority)
        Task {await coordinator.start()}
        foreground=NotificationCenter.default.addObserver(forName:UIApplication.didBecomeActiveNotification,object:nil,queue:.main) { [weak self] _ in
            guard let self else {return};Task {_ = await self.coordinator.refresh()}
        }
    }
    deinit {if let foreground {NotificationCenter.default.removeObserver(foreground)}}
    func attach(_ messenger:FlutterBinaryMessenger) {
        events=StorePlatformEventsApi(binaryMessenger:messenger)
        Task {await coordinator.observe { [weak self] in
            Task { @MainActor in try? await self?.events?.changed() }
        }}
    }
    private func run(_ work:() async throws->String) async throws -> String {
        do {return try await work()}
        catch let error as CoreRepositoryError {throw PigeonError(code:error.code,message:nil,details:nil)}
        catch {throw PigeonError(code:"STORE_UNAVAILABLE",message:nil,details:nil)}
    }
    func readState() async throws -> String {await coordinator.readState()}
    func refresh() async throws -> String {await coordinator.refresh()}
    func loadOffer() async throws -> String {await coordinator.loadOffer()}
    func purchase(request:String) async throws -> String {try await run {try await coordinator.purchase(request)}}
    func restorePurchases() async throws -> String {await coordinator.restorePurchases()}
    func retryPendingPurchase(intentId:String) async throws -> String {try await run {try await coordinator.retryPendingPurchase(intentId)}}
    func cancelIntent(intentId:String) async throws -> String {try await run {try await coordinator.cancelIntent(intentId)}}
}
