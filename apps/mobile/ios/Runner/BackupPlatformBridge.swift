import Flutter
import UIKit
import UniformTypeIdentifiers
import VerdiNative

@MainActor
final class BackupPlatformBridge: NSObject, BackupPlatformHostApi, UIDocumentPickerDelegate {
  let repository: CoreRepository
  private var selection: CheckedContinuation<String?,Error>?
  init(repository:CoreRepository) {self.repository=repository}
  private func call(_ method:String,_ request:String) async throws -> String {
    let repository=self.repository
    return try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos:.userInitiated).async {
        do {continuation.resume(returning:try repository.backupCall(method:method,request:request))}
        catch {continuation.resume(throwing:MediaPlatformBridge.error(error))}
      }
    }
  }
  func startExport(request:String) async throws -> String {try await call("startExport",request)}
  func startImport(request:String) async throws -> String {try await call("startImport",request)}
  func backupStatus(request:String) async throws -> String {try await call("backupStatus",request)}
  func latestBackupOperation(request:String) async throws -> String {try await call("latestBackupOperation",request)}
  func confirmImport(request:String) async throws -> String {try await call("confirmImport",request)}
  func cancelBackup(request:String) async throws -> String {try await call("cancelBackup",request)}
  func retryImport(request:String) async throws -> String {try await call("retryImport",request)}
  func renewExportHandle(request:String) async throws -> String {try await call("renewExportHandle",request)}
  func chooseBackup() async throws -> String? {
    guard selection == nil else {throw PigeonError(code:"BUSY",message:nil,details:nil)}
    let lease=try repository.acquirePlatformLease()
    defer {repository.releasePlatformLease(lease)}
    let presenter=try MediaPlatformBridge(repository:repository).presenter()
    return try await withCheckedThrowingContinuation { continuation in
      selection=continuation
      let picker=UIDocumentPickerViewController(forOpeningContentTypes:[.zip],asCopy:false)
      picker.allowsMultipleSelection=false;picker.delegate=self
      presenter.present(picker,animated:true)
    }
  }
  func documentPickerWasCancelled(_ controller:UIDocumentPickerViewController) {finish(.success(nil))}
  func documentPicker(_ controller:UIDocumentPickerViewController,didPickDocumentsAt urls:[URL]) {
    guard urls.count==1,let url=urls.first else {finish(.failure(PigeonError(code:"FIELD_INVALID",message:nil,details:nil)));return}
    let repository=self.repository
    DispatchQueue.global(qos:.userInitiated).async {
      let scoped=url.startAccessingSecurityScopedResource()
      defer {if scoped {url.stopAccessingSecurityScopedResource()}}
      var coordinationError:NSError?, outcome:Result<String?,Error>?
      NSFileCoordinator().coordinate(readingItemAt:url,options:.withoutChanges,error:&coordinationError) { readable in
        do {outcome = .success(try repository.retainBackupSelection(source:readable))}
        catch {outcome = .failure(error)}
      }
      let result=outcome ?? .failure(coordinationError ?? NSError(domain:"VerdiBackup",code:1))
      DispatchQueue.main.async {self.finish(result)}
    }
  }
  private func finish(_ result:Result<String?,Error>) {
    let continuation=selection;selection=nil
    continuation?.resume(with:result.mapError(MediaPlatformBridge.error))
  }
  func shareBackup(request:String) async throws -> String {
    let repository=self.repository
    let lease=try repository.acquirePlatformLease()
    defer {repository.releasePlatformLease(lease)}
    let (id,url):(String,URL)=try await withCheckedThrowingContinuation { continuation in
      DispatchQueue.global(qos:.userInitiated).async {
        do {continuation.resume(returning:try repository.backupShareURL(request:request))}
        catch {continuation.resume(throwing:MediaPlatformBridge.error(error))}
      }
    }
    do {
      let parent=try MediaPlatformBridge(repository:repository).presenter()
      let result:String=await withCheckedContinuation { continuation in
        let sheet=UIActivityViewController(activityItems:[url],applicationActivities:nil)
        sheet.popoverPresentationController?.sourceView=parent.view
        sheet.popoverPresentationController?.sourceRect=CGRect(x:parent.view.bounds.midX,y:parent.view.bounds.midY,width:1,height:1)
        sheet.completionWithItemsHandler={_,completed,_,error in continuation.resume(returning:error != nil ? "failed":completed ? "handedToOS":"cancelled")}
        parent.present(sheet,animated:true)
      }
      try await withCheckedThrowingContinuation { (continuation:CheckedContinuation<Void,Error>) in
        DispatchQueue.global(qos:.userInitiated).async {
          do {try repository.finishBackupShare(operationID:id,result:result);continuation.resume()}
          catch {continuation.resume(throwing:MediaPlatformBridge.error(error))}
        }
      }
      return result
    } catch {try? repository.finishBackupShare(operationID:id,result:"failed");throw error}
  }
}
