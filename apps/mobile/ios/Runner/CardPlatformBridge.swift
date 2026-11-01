import Flutter
import UIKit
import Photos
import VerdiNative

@MainActor
final class CardPlatformBridge: CardPlatformHostApi {
  let repository:CoreRepository
  private var busy=false
  init(repository:CoreRepository){self.repository=repository}
  private func outcome(_ value:String,_ code:String?=nil)->String {
    // Only constant protocol words enter this envelope.
    "{\"code\":\(code.map{"\"\($0)\""} ?? "null"),\"outcome\":\"\(value)\"}"
  }
  func prepareCard(requestJson:String) async throws -> String {
    try await withCheckedThrowingContinuation{ continuation in repository.prepareCard(requestJson){continuation.resume(with:$0.mapError(MediaPlatformBridge.error))} }
  }
  func readCard(token:String) async throws -> FlutterStandardTypedData {
    let bytes:Data=try await withCheckedThrowingContinuation{ continuation in repository.readCard(token){continuation.resume(with:$0.mapError(MediaPlatformBridge.error))} }
    return FlutterStandardTypedData(bytes:bytes)
  }
  func releaseCard(token:String) async throws {repository.releaseCard(token)}
  private func preflight(_ token:String) async throws -> CardHandoffPreparation {
    try await withCheckedThrowingContinuation{ continuation in repository.prepareCardHandoff(token){continuation.resume(with:$0.mapError(MediaPlatformBridge.error))} }
  }
  func shareCard(token:String) async throws -> String {
    guard !busy else{throw PigeonError(code:"BUSY",message:nil,details:nil)};busy=true;defer{busy=false}
    let prepared=try await preflight(token)
    let parent=try MediaPlatformBridge(repository:repository).presenter()
    guard parent.view.window != nil,!parent.isBeingDismissed else{throw PigeonError(code:"MEDIA_UNAVAILABLE",message:nil,details:nil)}
    return try await withCheckedThrowingContinuation { continuation in
      do {
        let handoff=try repository.grantCardHandoff(prepared)
        let sheet=UIActivityViewController(activityItems:[handoff.url],applicationActivities:nil)
        sheet.popoverPresentationController?.sourceView=parent.view
        sheet.popoverPresentationController?.sourceRect=CGRect(x:parent.view.bounds.midX,y:parent.view.bounds.midY,width:1,height:1)
        sheet.completionWithItemsHandler={ [repository] _,completed,_,error in
          repository.releaseCardHandoff(handoff.leaseID)
          continuation.resume(returning:self.outcome(error != nil ? "failed":completed ? "handedToOS":"cancelled",error == nil ? nil:"SHARE_FAILED"))
        }
        parent.present(sheet,animated:true)
      } catch {continuation.resume(throwing:MediaPlatformBridge.error(error))}
    }
  }
  func saveCard(token:String) async throws -> String {
    guard !busy else{throw PigeonError(code:"BUSY",message:nil,details:nil)};busy=true;defer{busy=false}
    var status=PHPhotoLibrary.authorizationStatus(for:.addOnly)
    if status == .notDetermined {status=await PHPhotoLibrary.requestAuthorization(for:.addOnly)}
    guard status == .authorized || status == .limited else{return outcome("failed","PHOTO_SAVE_DENIED")}
    let prepared=try await preflight(token)
    return try await withCheckedThrowingContinuation { continuation in
      do {
        let handoff=try repository.grantCardHandoff(prepared)
        var requestCreated=false
        PHPhotoLibrary.shared().performChanges({
          requestCreated = PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:handoff.url)?.placeholderForCreatedAsset != nil
        }) { [repository] saved,error in
          repository.releaseCardHandoff(handoff.leaseID)
          DispatchQueue.main.async {
            let result=CardSaveResult.resolve(requestCreated:requestCreated,completed:saved,errorReported:error != nil)
            continuation.resume(returning:self.outcome(result == .saved ? "saved":"failed",result.code))
          }
        }
      } catch {continuation.resume(throwing:MediaPlatformBridge.error(error))}
    }
  }
}
