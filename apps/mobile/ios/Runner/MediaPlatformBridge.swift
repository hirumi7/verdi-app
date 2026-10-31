import Flutter
import UIKit
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import VerdiNative

@MainActor
final class MediaPlatformBridge: NSObject, MediaPlatformHostApi, PHPickerViewControllerDelegate {
  let repository: CoreRepository
  var selection: CheckedContinuation<String?, Error>?
  init(repository: CoreRepository) { self.repository=repository }
  func presenter() throws -> UIViewController {
    guard let window=UIApplication.shared.connectedScenes.compactMap({$0 as? UIWindowScene}).flatMap(\.windows).first(where:{$0.isKeyWindow}),var controller=window.rootViewController else {throw PigeonError(code:"MEDIA_UNAVAILABLE",message:nil,details:nil)}
    while let next=controller.presentedViewController {controller=next}
    return controller
  }
  func choosePhoto(source: String) async throws -> String? {
    let lease=try repository.acquirePlatformLease()
    defer {repository.releasePlatformLease(lease)}
    guard selection==nil else {throw PigeonError(code:"MEDIA_BUSY",message:nil,details:nil)}
    if source=="camera" {
      guard AVCaptureDevice.default(for:.video) != nil else {throw PigeonError(code:"CAMERA_UNAVAILABLE",message:nil,details:nil)}
      var authorization=AVCaptureDevice.authorizationStatus(for:.video)
      if authorization == .notDetermined { _=await AVCaptureDevice.requestAccess(for:.video);authorization=AVCaptureDevice.authorizationStatus(for:.video) }
      guard authorization == .authorized else {throw PigeonError(code:"CAMERA_DENIED",message:nil,details:nil)}
      let parent=try presenter()
      return try await withCheckedThrowingContinuation { continuation in
        selection=continuation
        let camera=VerdiCameraController()
        camera.finished={ [weak self,weak camera] result in
          camera?.dismiss(animated:true)
          guard let self else{return}
          switch result {
          case .success(nil):self.finishSelection(.success(nil))
          case .success(let data?):
            let repository=self.repository
            DispatchQueue.global(qos:.userInitiated).async {
              let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".camera")
              do {try data.write(to:url,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication]);defer{try? FileManager.default.removeItem(at:url)}
                let id=try repository.retainMediaSelection(source:url,kind:"camera")
                DispatchQueue.main.async {self.finishSelection(.success(id))}
              } catch {DispatchQueue.main.async {self.finishSelection(.failure(error))}}
            }
          case .failure(let error):self.finishSelection(.failure(error))
          }
        }
        parent.present(camera,animated:true)
      }
    }
    guard source=="library" else {throw PigeonError(code:"FIELD_INVALID",message:nil,details:nil)}
    let parent=try presenter()
    return try await withCheckedThrowingContinuation { continuation in
      selection=continuation
      var configuration=PHPickerConfiguration();configuration.filter = .images;configuration.selectionLimit=1;configuration.preferredAssetRepresentationMode = .current
      let picker=PHPickerViewController(configuration:configuration);picker.delegate=self
      parent.present(picker,animated:true)
    }
  }
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated:true)
    guard let provider=results.first?.itemProvider else {finishSelection(.success(nil));return}
    let repository=self.repository
    guard let type=provider.registeredTypeIdentifiers.first(where:{UTType($0)?.conforms(to:.image)==true}) else {finishSelection(.failure(PigeonError(code:"MEDIA_INVALID",message:nil,details:nil)));return}
    provider.loadFileRepresentation(forTypeIdentifier:type) { [weak self] url,error in
      // The supplied URL expires when this callback returns; retain synchronously.
      let result:Result<String?,Error>
      do {guard let url,error==nil else {throw error ?? PigeonError(code:"IO_FAILURE",message:nil,details:nil)};result = .success(try repository.retainMediaSelection(source:url,kind:"library"))}
      catch {result = .failure(error)}
      DispatchQueue.main.async {self?.finishSelection(result)}
    }
  }
  func finishSelection(_ result:Result<String?,Error>) {
    let continuation=selection;selection=nil
    continuation?.resume(with:result.mapError(Self.error))
  }
  static func error(_ error:Error)->Error {
    if let error=error as? CoreRepositoryError {return PigeonError(code:error.code,message:nil,details:nil)}
    if error is PigeonError {return error}
    return PigeonError(code:"IO_FAILURE",message:nil,details:nil)
  }
  func previewPhoto(photoId:String) async throws -> FlutterStandardTypedData {
    let data:Data=try await withCheckedThrowingContinuation { continuation in repository.mediaPreview(photoID:photoId) {continuation.resume(with:$0.mapError(Self.error))} }
    return FlutterStandardTypedData(bytes:data)
  }
  func exportPhoto(photoId:String,photoRevision:Int64) async throws -> String {
    let url:URL=try await withCheckedThrowingContinuation { continuation in repository.exportOriginal(photoID:photoId,revision:photoRevision) {continuation.resume(with:$0.mapError(Self.error))} }
    do {
      let parent=try presenter()
      return await withCheckedContinuation { continuation in
        let sheet=UIActivityViewController(activityItems:[url],applicationActivities:nil)
        sheet.popoverPresentationController?.sourceView=parent.view
        sheet.popoverPresentationController?.sourceRect=CGRect(x:parent.view.bounds.midX,y:parent.view.bounds.midY,width:1,height:1)
        sheet.completionWithItemsHandler={ [repository] _,completed,_,error in repository.releaseExport(url);continuation.resume(returning:error != nil ? "failed":completed ? "handedToOS":"cancelled") }
        parent.present(sheet,animated:true)
      }
    } catch {repository.releaseExport(url);throw error}
  }
  func openMediaSettings() async throws {
    guard let url=URL(string:UIApplication.openSettingsURLString),await UIApplication.shared.open(url) else {throw PigeonError(code:"MEDIA_UNAVAILABLE",message:nil,details:nil)}
  }
}

/// Camera retains AVCapturePhoto's original encoded file representation.
final class VerdiCameraController:UIViewController,AVCapturePhotoCaptureDelegate {
  var finished:((Result<Data?,Error>)->Void)?
  let session=AVCaptureSession(),output=AVCapturePhotoOutput(),worker=DispatchQueue(label:"verdi.camera")
  var layer:AVCaptureVideoPreviewLayer?
  let capture=UIButton(type:.system),cancel=UIButton(type:.system)
  var done=false
  override func viewDidLoad() {
    super.viewDidLoad();view.backgroundColor = .black;isModalInPresentation=true
    capture.setTitle("Take photo",for:.normal);capture.accessibilityLabel="Take photo"
    cancel.setTitle("Cancel",for:.normal)
    for button in [capture,cancel] {button.backgroundColor = .systemBackground;button.layer.cornerRadius=16;button.translatesAutoresizingMaskIntoConstraints=false;view.addSubview(button);button.heightAnchor.constraint(greaterThanOrEqualToConstant:52).isActive=true}
    NSLayoutConstraint.activate([capture.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-24),capture.centerXAnchor.constraint(equalTo:view.centerXAnchor),capture.widthAnchor.constraint(greaterThanOrEqualToConstant:160),cancel.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor,constant:16),cancel.leadingAnchor.constraint(equalTo:view.leadingAnchor,constant:16),cancel.widthAnchor.constraint(greaterThanOrEqualToConstant:90)])
    capture.addTarget(self,action:#selector(shoot),for:.touchUpInside);cancel.addTarget(self,action:#selector(abort),for:.touchUpInside)
    do {
      guard let device=AVCaptureDevice.default(for:.video) else{throw NSError(domain:"camera",code:1)}
      let input=try AVCaptureDeviceInput(device:device)
      session.beginConfiguration();session.sessionPreset = .photo
      guard session.canAddInput(input),session.canAddOutput(output) else{session.commitConfiguration();throw NSError(domain:"camera",code:2)}
      session.addInput(input);session.addOutput(output);session.commitConfiguration()
      let preview=AVCaptureVideoPreviewLayer(session:session);preview.videoGravity = .resizeAspectFill;view.layer.insertSublayer(preview,at:0);layer=preview
      worker.async {self.session.startRunning()}
    } catch {complete(.failure(error))}
  }
  override func viewDidLayoutSubviews(){super.viewDidLayoutSubviews();layer?.frame=view.bounds}
  @objc func shoot(){capture.isEnabled=false;output.capturePhoto(with:AVCapturePhotoSettings(),delegate:self)}
  @objc func abort(){complete(.success(nil))}
  func photoOutput(_ output:AVCapturePhotoOutput,didFinishProcessingPhoto photo:AVCapturePhoto,error:Error?) {
    DispatchQueue.main.async {if let error{self.complete(.failure(error))}else if let data=photo.fileDataRepresentation(){self.complete(.success(data))}else{self.complete(.failure(NSError(domain:"camera",code:3)))}}
  }
  func complete(_ result:Result<Data?,Error>){guard !done else{return};done=true;worker.async{self.session.stopRunning()};finished?(result)}
}
