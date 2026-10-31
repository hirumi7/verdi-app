import Foundation
import XCTest
import Darwin
@testable import VerdiNative

#if os(macOS)
/// Separate-process termination: no defer, SQLite close or in-process rollback.
final class BackupCrashWorkerTests: XCTestCase {
    func testCrashWorker() throws {
        let env=ProcessInfo.processInfo.environment
        guard let path=env["VERDI_CRASH_ROOT"],let boundary=env["VERDI_CRASH_BOUNDARY"] else {return}
        let repo=CoreRepository(directory:URL(fileURLWithPath:path))
        _=try repo.call(operation:"open",body:"{\"profile\":\"custom_core_v1\",\"protocolVersion\":1}")
        repo.backupFault={if String(describing:$0)==boundary {_exit(79)}}
        // Recreate the control owner so bootstrap and commit closures are identical.
        repo.backupEngine.worker.sync{};try repo.backupControl?.db.close();repo.backupControl=nil
        if boundary.hasPrefix("bootstrap") {_=try repo.backupCall(method:"latestBackupOperation",request:"{}");XCTFail("boundary not reached");return}
        let source=URL(fileURLWithPath:try XCTUnwrap(env["VERDI_CRASH_ZIP"]))
        let selection=try repo.retainBackupSelection(source:source),id=UUID().uuidString.lowercased()
        func call(_ method:String,_ args:[String:CanonicalValue]) throws -> CanonicalValue {try CanonicalParser.parse(repo.backupCall(method:method,request:CanonicalValue.object(args).json()))}
        _=try call("startImport",["operationId":.string(id),"selectionHandle":.string(selection)])
        for _ in 0..<1000 {
            let result=try call("backupStatus",["operationId":.string(id)]),state=result.object?["operation"]?.object?["state"]?.object
            if state?["kind"]?.text == "preview_ready" {
                repo.backupEngine.worker.sync{}
                _=try call("confirmImport",["operationId":.string(id),"preview":state!["preview"]!,"confirmed":.boolean(true)]);break
            }
            Thread.sleep(forTimeInterval:0.01)
        }
        Thread.sleep(forTimeInterval:15);XCTFail("boundary not reached")
    }
}
extension CoreRepositoryTests {
    func testBackupSeparateProcessCrashRecoversCoherentGeneration() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let old=dataset,before=try allRows("plants")
        let (_,zip)=try exportBackup()
        let source=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".zip")
        try FileManager.default.copyItem(at:zip,to:source);defer{try? FileManager.default.removeItem(at:source)}
        for boundary in ["staged","prepared","switched","verified"] {
            let current=dataset
            _=try call("close");repo.backupEngine.worker.sync{};try repo.backupControl?.db.close();repo.backupControl=nil
            let child=Process();child.executableURL=URL(fileURLWithPath:"/usr/bin/xcrun")
            child.arguments=["xctest","-XCTest","VerdiNativeTests.BackupCrashWorkerTests/testCrashWorker",Bundle(for:BackupCrashWorkerTests.self).bundleURL.path]
            var env=ProcessInfo.processInfo.environment
            env["VERDI_CRASH_ROOT"]=directory.path;env["VERDI_CRASH_BOUNDARY"]=boundary;env["VERDI_CRASH_ZIP"]=source.path
            child.environment=env;let output=Pipe();child.standardOutput=output;child.standardError=output
            try child.run();let log=String(decoding:output.fileHandleForReading.readDataToEndOfFile(),as:UTF8.self);child.waitUntilExit();XCTAssertEqual(child.terminationStatus,79,boundary+"\n"+log)
            try open();XCTAssertEqual(try allRows("plants"),before,boundary)
            if ["staged","prepared"].contains(boundary) {XCTAssertEqual(dataset,current)} else {XCTAssertNotEqual(dataset,current)}
        }
        XCTAssertNotEqual(dataset,old)
    }
    func testBackupBootstrapSeparateProcessCrashRetainsLegacy() throws {
        defer{removeBackupSidecars()}
        try execute(0);try execute(1)
        let old=dataset
        for boundary in ["bootstrapRecord","bootstrapDatabase","bootstrapPublished"] {
            _=try call("close");repo.backupEngine.worker.sync{};try repo.backupControl?.db.close();repo.backupControl=nil
            removeBackupSidecars()
            let child=Process();child.executableURL=URL(fileURLWithPath:"/usr/bin/xcrun")
            child.arguments=["xctest","-XCTest","VerdiNativeTests.BackupCrashWorkerTests/testCrashWorker",Bundle(for:BackupCrashWorkerTests.self).bundleURL.path]
            var env=ProcessInfo.processInfo.environment;env["VERDI_CRASH_ROOT"]=directory.path;env["VERDI_CRASH_BOUNDARY"]=boundary
            child.environment=env;let output=Pipe();child.standardOutput=output;child.standardError=output
            try child.run();let log=String(decoding:output.fileHandleForReading.readDataToEndOfFile(),as:UTF8.self);child.waitUntilExit();XCTAssertEqual(child.terminationStatus,79,boundary+"\n"+log)
            try open();_=try backup("latestBackupOperation")
            XCTAssertEqual(dataset,old);XCTAssertEqual(try allRows("plants").count,1)
        }
    }
}
#endif
