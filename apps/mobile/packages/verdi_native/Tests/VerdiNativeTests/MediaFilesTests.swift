import XCTest
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import VerdiNative

final class MediaFilesTests:XCTestCase {
 var root:URL!
 var files:MediaFiles!
 override func setUpWithError() throws {root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString);files=try MediaFiles(root:root)}
 override func tearDownWithError() throws {try? FileManager.default.removeItem(at:root)}
 func source() throws -> URL {try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))}
 func testOriginalBytesHashAndBoundedPreview() throws {
  let source=try source(),data=try Data(contentsOf:source)
  try files.importSelection(source,to:"staging/one.copy")
  let info=try files.inspect("staging/one.copy"),path="media/00000000-0000-4000-8000-000000000001/\(info.hash).png"
  XCTAssertEqual(info.mime,"image/png");XCTAssertEqual(info.bytes,Int64(data.count))
  XCTAssertEqual(try root.appendingPathComponent("staging/one.copy").resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup,true)
  try files.publish("staging/one.copy",to:path)
  XCTAssertNotEqual(try root.appendingPathComponent(path).resourceValues(forKeys:[.isExcludedFromBackupKey]).isExcludedFromBackup,true)
  XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent(path)),data)
  let preview=try files.preview(path);XCTAssertLessThanOrEqual(preview.count,2*1024*1024)
  let image=try XCTUnwrap(CGImageSourceCreateWithData(preview as CFData,nil)),props=try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(image,0,nil) as? [CFString:Any])
  XCTAssertLessThanOrEqual((props[kCGImagePropertyPixelWidth] as! NSNumber).intValue,1024)
  XCTAssertLessThanOrEqual((props[kCGImagePropertyPixelHeight] as! NSNumber).intValue,1024)
 }
 func testJPEGAndHEICOriginalRepresentations() throws {
  let source=try XCTUnwrap(CGImageSourceCreateWithURL(self.source() as CFURL,nil)),image=try XCTUnwrap(CGImageSourceCreateImageAtIndex(source,0,nil))
  for type in [UTType.jpeg,UTType.heic] {
   let url=root.appendingPathComponent("input.\(type.preferredFilenameExtension!)"),destination=try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL,type.identifier as CFString,1,nil))
   CGImageDestinationAddImage(destination,image,[kCGImageDestinationLossyCompressionQuality:0.9] as CFDictionary);XCTAssertTrue(CGImageDestinationFinalize(destination))
   let path="staging/\(type.preferredFilenameExtension!).copy";try files.importSelection(url,to:path)
   let info=try files.inspect(path);XCTAssertEqual(info.mime,type==UTType.jpeg ? "image/jpeg":"image/heic")
   XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent(path)),try Data(contentsOf:url))
  }
 }
 func testCorruptAndTruncatedRejectWithoutChangingExistingFile() throws {
  let data=try Data(contentsOf:source()),good="media/good/original.png"
  try files.importSelection(source(),to:good)
  for (index,bad) in [Data("not an image".utf8),Data(data.prefix(40))].enumerated() {
   let url=root.appendingPathComponent("bad\(index)");try bad.write(to:url);let path="staging/bad\(index)";try files.importSelection(url,to:path)
   XCTAssertThrowsError(try files.inspect(path))
  }
  XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent(good)),data)
 }
 func testTraversalSymlinkAndOverwriteAreRejected() throws {
  let source=try source()
  XCTAssertThrowsError(try files.importSelection(source,to:"../escape"))
  try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("alias"),withDestinationURL:root)
  XCTAssertThrowsError(try files.importSelection(source,to:"alias/escape"))
  try files.importSelection(source,to:"staging/one")
  XCTAssertThrowsError(try files.importSelection(source,to:"staging/one"))
  try FileManager.default.createSymbolicLink(at:root.appendingPathComponent("staging/link"),withDestinationURL:source)
  XCTAssertThrowsError(try files.inspect("staging/link"))
 }
 func testOversizeSelectionRejectedAtStreamingBoundary() throws {
  let url=root.appendingPathComponent("large"),handle=try FileHandle(forWritingTo:createEmpty(url))
  try handle.truncate(atOffset:67108865);try handle.close()
  XCTAssertThrowsError(try files.importSelection(url,to:"selections/large.source")) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"MEDIA_TOO_LARGE")}
 }
 func createEmpty(_ url:URL) throws -> URL {try Data().write(to:url);return url}
 func testEveryPhysicalFailureRetainsPriorOriginal() throws {
  let source=try source(),original=try Data(contentsOf:source)
  try files.importSelection(source,to:"media/old/original.png")
  for (index,boundary) in [MediaFileBoundary.create,.write,.flush,.parentFlush].enumerated() {
   let faulty=try MediaFiles(root:root,fault:{if $0==boundary {throw CoreRepositoryError("IO_FAILURE")}})
   XCTAssertThrowsError(try faulty.importSelection(source,to:"staging/fault\(index)"))
   XCTAssertEqual(try Data(contentsOf:root.appendingPathComponent("media/old/original.png")),original)
  }
  try files.importSelection(source,to:"staging/rename")
  let faulty=try MediaFiles(root:root,fault:{if $0 == .publish{throw CoreRepositoryError("IO_FAILURE")}})
  XCTAssertThrowsError(try faulty.publish("staging/rename",to:"media/new/file.png"))
  XCTAssertTrue(files.exists("staging/rename"));XCTAssertFalse(files.exists("media/new/file.png"))
 }
}
