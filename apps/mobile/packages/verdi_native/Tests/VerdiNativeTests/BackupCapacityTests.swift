import Foundation
import XCTest
import Darwin
import zlib
@testable import VerdiNative

extension BackupParserTests {
    /// Header-only structural fixtures: holes are not valid deflate/image payloads.
    /// They deliberately exercise preflight without allocating multi-GiB content.
    func sparseZIP(_ entries:[(String,Int64,Int64)]) throws -> URL {
        let url = root.appendingPathComponent(UUID().uuidString + ".zip")
        XCTAssertTrue(FileManager.default.createFile(atPath:url.path,contents:nil))
        let file = try FileHandle(forWritingTo:url);defer{try? file.close()}
        func n(_ value:UInt64,_ width:Int) -> Data {Data((0..<width).map{UInt8(truncatingIfNeeded:value >> ($0*8))})}
        func fields(_ values:[(UInt64,Int)]) -> Data {values.reduce(into:Data()){$0.append(n($1.0,$1.1))}}
        var central = Data()
        for (name,expanded,compressed) in entries {
            let path = Data(name.utf8), offset = try file.offset()
            let extra = fields([(1,2),(16,2),(UInt64(expanded),8),(UInt64(compressed),8)])
            try file.write(contentsOf:fields([(0x04034b50,4),(45,2),(0,2),(8,2),(0,2),(0,2),(0,4),(0xffffffff,4),(0xffffffff,4),(UInt64(path.count),2),(UInt64(extra.count),2)]))
            try file.write(contentsOf:path);try file.write(contentsOf:extra)
            try file.seek(toOffset:try file.offset() + UInt64(compressed))
            let wide = fields([(1,2),(24,2),(UInt64(expanded),8),(UInt64(compressed),8),(offset,8)])
            central.append(fields([(0x02014b50,4),(0x032d,2),(45,2),(0,2),(8,2),(0,2),(0,2),(0,4),(0xffffffff,4),(0xffffffff,4),(UInt64(path.count),2),(UInt64(wide.count),2),(0,2),(0,2),(0,2),(0x81a40000,4),(0xffffffff,4)]))
            central.append(path);central.append(wide)
        }
        let offset = try file.offset(), count = UInt64(entries.count)
        try file.write(contentsOf:central)
        let record = try file.offset()
        try file.write(contentsOf:fields([(0x06064b50,4),(44,8),(45,2),(45,2),(0,4),(0,4),(count,8),(count,8),(UInt64(central.count),8),(offset,8)]))
        try file.write(contentsOf:fields([(0x07064b50,4),(0,4),(record,8),(1,4)]))
        try file.write(contentsOf:fields([(0x06054b50,4),(0,2),(0,2),(0xffff,2),(0xffff,2),(0xffffffff,4),(0xffffffff,4),(0,2)]))
        return url
    }
    func capacityPreflight(_ url:URL) throws -> (Int64,Int64) {
        let index = try BackupIndex(root.appendingPathComponent(UUID().uuidString + ".sqlite"))
        defer{try? index.database.close()}
        try BackupZIPPreflight(url,index:index,cancel:{}).validate()
        return try index.database.read {sql in let row = try sql.query("SELECT count(*),COALESCE(sum(expanded),0) FROM entries")[0];return(try CoreSchema.integer(row[0]),try CoreSchema.integer(row[1]))}
    }
    func capacityMedia(_ i:Int) -> String {"media/00000000-0000-4000-8000-" + String(format:"%012x",i) + "/" + String(repeating:"a",count:64) + ".png"}
    func expectCapacityLimit(_ url:URL) {
        XCTAssertThrowsError(try capacityPreflight(url)) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"BACKUP_LIMIT")}
    }
    func testBackupExactArchiveAndPerFileCapacityPreflight() throws {
        let base:[(String,Int64,Int64)] = [("manifest.json",0,0),("data.json",0,0)]
        let empty = try sparseZIP(base), overhead = try BackupIO.size(empty)
        for delta:Int64 in [-1,0,1] {
            let zip = try sparseZIP([base[0],("data.json",0,BackupIO.archiveLimit-overhead+delta)])
            XCTAssertEqual(try BackupIO.size(zip),BackupIO.archiveLimit+delta)
            var info = stat();XCTAssertEqual(lstat(zip.path,&info),0)
            XCTAssertLessThan(info.st_blocks*512,2*1024*1024,"Sparse boundary fixture must stay physically small")
            if delta > 0 {expectCapacityLimit(zip)} else {XCTAssertEqual(try capacityPreflight(zip).0,2)}
            try FileManager.default.removeItem(at:zip)
        }
        for (name,limit) in [("manifest.json",Int64(16*1024*1024)),("data.json",Int64(512*1024*1024)),(capacityMedia(1),Int64(64*1024*1024))] {
            for delta:Int64 in [-1,0,1] {
                var entries = base.filter{$0.0 != name};entries.append((name,limit+delta,0))
                let zip = try sparseZIP(entries)
                if delta > 0 {expectCapacityLimit(zip)} else {XCTAssertEqual(try capacityPreflight(zip).1,limit+delta)}
            }
        }
    }
    func testBackupExactExpandedAndEntryCountCapacityPreflight() throws {
        let base:[(String,Int64,Int64)] = [("manifest.json",0,0),("data.json",0,0)]
        for delta:Int64 in [-1,0,1] {
            var entries = base + (0..<192).map{(capacityMedia($0),Int64(64*1024*1024),Int64(0))}
            if delta < 0 {entries[entries.count-1].1 -= 1}
            if delta > 0 {entries.append((capacityMedia(192),1,0))}
            let zip = try sparseZIP(entries)
            if delta > 0 {expectCapacityLimit(zip)} else {XCTAssertEqual(try capacityPreflight(zip).1,BackupIO.expandedLimit+delta)}
        }
        for count in [50001,50002,50003] {
            let entries = base + (0..<(count-2)).map{(capacityMedia($0),Int64(0),Int64(0))}
            let zip = try sparseZIP(entries)
            if count > 50002 {expectCapacityLimit(zip)} else {XCTAssertEqual(try capacityPreflight(zip).0,Int64(count))}
        }
    }
    func testBackupMaximumDataStreamAndOverflow() throws {
        guard ProcessInfo.processInfo.environment["VERDI_CAPACITY_STREAM"] == "1" else {throw XCTSkip("Opt-in 512 MiB streaming boundary; run separately with VERDI_CAPACITY_STREAM=1")}
        let url = root.appendingPathComponent("maximum-data.json"), limit:Int64 = 512*1024*1024
        let writer = try BackupWriter(url,limit:limit+1)
        let block = Data(repeating:32,count:BackupIO.chunk)
        try writer.write("{}")
        var remaining = limit-2
        while remaining > 0 {try writer.write(block.prefix(Int(min(Int64(block.count),remaining))));remaining -= min(Int64(block.count),remaining)}
        try writer.finish()
        let exact = try BackupJSONReader(url,limit:limit)
        try exact.object{_ in XCTFail("Empty object")};try exact.end()
        let file = try FileHandle(forWritingTo:url);try file.seekToEnd();try file.write(contentsOf:Data([32]));try file.close()
        let overflow = try BackupJSONReader(url,limit:limit)
        try overflow.object{_ in XCTFail("Empty object")}
        XCTAssertThrowsError(try overflow.end()) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"BACKUP_LIMIT")}
    }
    func testBackupDirectoryPublicationFailuresAndTraversal() throws {
        for boundary:BackupFileBoundary in [.directoryCreate,.directoryCreated,.protection,.directorySync] {
            let base = root.appendingPathComponent(UUID().uuidString), nested = base.appendingPathComponent("parent/child")
            let latch = BackupFaultLatch()
            let io = BackupFileIO(fault:{point,url in
                if point == boundary && url.lastPathComponent == "parent" && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
            })
            XCTAssertThrowsError(try BackupIO.directory(nested,io:io,relativeTo:root))
            XCTAssertGreaterThan(latch.count,0)
            XCTAssertFalse(FileManager.default.fileExists(atPath:nested.path))
            try BackupIO.directory(nested,io:io,relativeTo:root)
            XCTAssertTrue(FileManager.default.fileExists(atPath:nested.path))
            let sentinel = nested.appendingPathComponent("kept");try Data("retained".utf8).write(to:sentinel)
            try BackupIO.directory(nested,io:io,relativeTo:root)
            XCTAssertEqual(try String(contentsOf:sentinel),"retained")
        }
        let untrusted = root.appendingPathComponent("missing-parent/child")
        XCTAssertThrowsError(try BackupIO.directory(untrusted))
        XCTAssertFalse(FileManager.default.fileExists(atPath:untrusted.deletingLastPathComponent().path))
        try BackupIO.directory(untrusted,relativeTo:root)
        let external = root.appendingPathComponent("external"), alias = root.appendingPathComponent("alias")
        try BackupIO.directory(external);try FileManager.default.createSymbolicLink(at:alias,withDestinationURL:external)
        XCTAssertThrowsError(try BackupIO.directory(alias.appendingPathComponent("escaped"),relativeTo:root))
        XCTAssertFalse(FileManager.default.fileExists(atPath:external.appendingPathComponent("escaped").path))
        let file = root.appendingPathComponent("file");try Data("retained".utf8).write(to:file)
        XCTAssertThrowsError(try BackupIO.directory(file.appendingPathComponent("child"),relativeTo:root))
        XCTAssertEqual(try String(contentsOf:file),"retained")
    }
    func testMediaRootDirectoryFailureRetriesDurablePublication() throws {
        let target = root.appendingPathComponent("media-root"), latch = BackupFaultLatch()
        let io = BackupFileIO(fault:{point,url in
            if point == .protection && url == target && latch.take() {throw CoreRepositoryError("IO_FAILURE")}
        })
        XCTAssertThrowsError(try MediaFiles(root:target,directoryIO:io))
        _ = try MediaFiles(root:target,directoryIO:io)
        XCTAssertGreaterThan(latch.count,0)
    }
}

/// Valid tiny image with a large ancillary PNG chunk; decoder and hash validation
/// still execute on the complete original. Construction uses bounded buffers.
func capacityPNG(at url:URL, size:Int64) throws {
    let original = try Data(contentsOf:XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog")))
    let extra = size - Int64(original.count) - 12
    precondition(extra >= 0 && extra < Int64(UInt32.max))
    func big(_ n:UInt32)->Data {Data((0..<4).reversed().map{UInt8(truncatingIfNeeded:n >> ($0*8))})}
    let writer = try BackupWriter(url,limit:size)
    try writer.write(original.dropLast(12));try writer.write(big(UInt32(extra)))
    let type = Data("vpAg".utf8);try writer.write(type)
    var crc = type.withUnsafeBytes{crc32(0,$0.bindMemory(to:Bytef.self).baseAddress,uInt(type.count))}
    var left = extra;let chunk = Data(repeating:0,count:BackupIO.chunk)
    while left > 0 {
        let bytes = chunk.prefix(Int(min(left,Int64(chunk.count))))
        try writer.write(bytes);crc = bytes.withUnsafeBytes{crc32(crc,$0.bindMemory(to:Bytef.self).baseAddress,uInt(bytes.count))};left -= Int64(bytes.count)
    }
    try writer.write(big(UInt32(crc)));try writer.write(original.suffix(12));try writer.finish()
}

extension CoreRepositoryTests {
    func testBackupMaximumPhotoOriginalRoundTrip() throws {
        defer{removeBackupSidecars()}
        let (photo,_) = try seedSavedPhoto(), source = directory.appendingPathComponent("maximum.png")
        try capacityPNG(at:source,size:64*1024*1024)
        let files = try MediaFiles(root:directory)
        try files.importSelection(source,to:"staging/maximum.copy")
        let info = try files.inspect("staging/maximum.copy"), path = "media/\(photo)/\(info.hash).png"
        XCTAssertEqual(info.bytes,64*1024*1024)
        try files.publish("staging/maximum.copy",to:path)
        try repo.queue.sync {try repo.database!.transaction {sql in
            let old = try CoreSchema.text(sql.query("SELECT content_path FROM photos WHERE id=?",[.text(photo)])[0][0])
            try sql.execute("UPDATE photos SET content_path=?,sha256=?,byte_count=?,width=?,height=? WHERE id=?",[.text(path),.text(info.hash),.integer(info.bytes),.integer(info.width),.integer(info.height),.text(photo)])
            try sql.execute("DELETE FROM media_files WHERE relative_path=?",[.text(old)])
            try repo.registerMediaPath(sql,path)
        }}
        try FileManager.default.removeItem(at:source)
        let before = try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))}), identity = dataset
        let (_,zip) = try exportBackup(), (id,preview) = try previewBackup(zip)
        _ = try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertNotEqual(dataset,identity)
        for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
        let restored = try BackupIO.hash(repo.directory.appendingPathComponent(path))
        XCTAssertEqual(restored.0,info.hash);XCTAssertEqual(restored.1,info.bytes)
        XCTAssertEqual(try BackupIO.hash(directory.appendingPathComponent(path)).0,info.hash)
    }
}

#if os(macOS)
extension BackupParserTests {
    func isolatedCapacityVolume() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["VERDI_CAPACITY_VOLUME"] else {throw XCTSkip("Requires the explicitly created isolated APFS fault volume")}
        let volume = URL(fileURLWithPath:path)
        try BackupIO.require(try String(contentsOf:volume.appendingPathComponent("verdi-synthetic-volume")) == "verdi-test-volume-v1","TEST_VOLUME_INVALID")
        let bytes = try XCTUnwrap(FileManager.default.attributesOfFileSystem(forPath:path)[.systemSize] as? NSNumber).int64Value
        try BackupIO.require(bytes >= 64*1024*1024 && bytes <= 300*1024*1024,"TEST_VOLUME_INVALID")
        let test = volume.appendingPathComponent(UUID().uuidString)
        try BackupIO.directory(test)
        return test
    }
    func fillIsolatedVolume(_ directory:URL, leaving:Int64 = 1024*1024) throws -> URL {
        let file = directory.appendingPathComponent("filler"), fd = Darwin.open(file.path,O_WRONLY | O_CREAT | O_EXCL,0o600)
        try BackupIO.require(fd >= 0,"TEST_IO");defer{Darwin.close(fd)}
        let chunk = [UInt8](repeating:0x5a,count:1024*1024)
        for _ in 0..<300 {
            let free = try XCTUnwrap(FileManager.default.attributesOfFileSystem(forPath:directory.path)[.systemFreeSize] as? NSNumber).int64Value
            if free <= leaving {break}
            let n = Darwin.write(fd,chunk,Int(min(Int64(chunk.count),free-leaving)))
            if n < 0 && errno == ENOSPC {break}
            try BackupIO.require(n > 0,"TEST_IO")
        }
        _ = fsync(fd)
        return file
    }
    func testBackupRealDiskFullZIPFoundationPreservesSourceAndRetries() throws {
        let volume = try isolatedCapacityVolume();defer{try? FileManager.default.removeItem(at:volume)}
        try Data("{}".utf8).write(to:root.appendingPathComponent("data.json"))
        try Data("{}".utf8).write(to:root.appendingPathComponent("manifest.json"))
        let path = capacityMedia(1), source = root.appendingPathComponent(path)
        try BackupIO.directory(source.deletingLastPathComponent(),relativeTo:root)
        let writer = try BackupWriter(source,limit:8*1024*1024), chunk = Data(repeating:23,count:BackupIO.chunk)
        for _ in 0..<128 {try writer.write(chunk)};try writer.finish()
        let hash = try BackupIO.hash(source), index = try BackupIndex(root.appendingPathComponent("archive.sqlite"))
        try index.database.transaction {try $0.execute("INSERT INTO files VALUES(?,?,?,?,?)",[.text("00000000-0000-4000-8000-000000000001"),.text(path),.text(hash.0),.integer(hash.1),.text("image/png")])}
        let filler = try fillIsolatedVolume(volume)
        // Component-level writer test: production reserve is not bypassed in app flows.
        XCTAssertThrowsError(try BackupIO.reserve(at:volume,additional:8*1024*1024)) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"DISK_FULL")}
        XCTAssertThrowsError(try BackupArchive.create(volume.appendingPathComponent("partial.zip"),dataRoot:root,mediaRoot:root,index:index,cancel:{}))
        XCTAssertEqual(try BackupIO.hash(source).0,hash.0)
        try FileManager.default.removeItem(at:filler)
        let retry = volume.appendingPathComponent("retry.zip")
        try BackupArchive.create(retry,dataRoot:root,mediaRoot:root,index:index,cancel:{})
        XCTAssertEqual(try capacityPreflight(retry).0,3)
    }
    func testBackupRealDiskFullMediaCopyRetainsOriginalAndRetries() throws {
        let volume = try isolatedCapacityVolume();defer{try? FileManager.default.removeItem(at:volume)}
        let source = root.appendingPathComponent("valid.png");try capacityPNG(at:source,size:8*1024*1024)
        let files = try MediaFiles(root:volume)
        let tiny = try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog"))
        try files.importSelection(tiny,to:"media/original.png")
        let original = try files.inspect("media/original.png"), filler = try fillIsolatedVolume(volume)
        XCTAssertThrowsError(try files.importSelection(source,to:"staging/partial.copy"))
        XCTAssertEqual(try files.inspect("media/original.png").hash,original.hash)
        try FileManager.default.removeItem(at:filler)
        try files.importSelection(source,to:"staging/retry.copy")
        XCTAssertEqual(try files.inspect("staging/retry.copy").bytes,8*1024*1024)
    }
    func testBackupRealDiskFullSQLiteTransactionPreservesRows() throws {
        for mode in ["same-owner", "fresh-owner", "wrong-schema", "wrong-identity", "migration"] {
            try checkDiskFullSQLiteRecovery(mode)
        }
    }
    private func checkDiskFullSQLiteRecovery(_ mode:String) throws {
        let volume = try isolatedCapacityVolume();defer{try? FileManager.default.removeItem(at:volume)}
        let schema = CompiledSchema(applicationID:0x54535431,version:1,statements:["CREATE TABLE kept(id INTEGER PRIMARY KEY,value TEXT NOT NULL)","INSERT INTO kept VALUES(1,'retained')"],validate:{sql in
            try BackupIO.require(try sql.query("SELECT value FROM kept WHERE id=1") == [[.text("retained")]],"TEST_SCHEMA")
        })
        let url = volume.appendingPathComponent("test.sqlite"), db = try SQLiteDatabase.create(at:url,schema:schema,controlProfile:true)
        defer{try? db.close()}
        let filler = try fillIsolatedVolume(volume), large = String(repeating:"x",count:8*1024*1024)
        XCTAssertThrowsError(try db.transaction {try $0.execute("INSERT INTO kept VALUES(2,?)",[.text(large)])}) {XCTAssertEqual($0 as? StorageFailure,.unknownOutcome)}
        XCTAssertThrowsError(try db.read{try $0.query("SELECT * FROM kept")})
        try FileManager.default.removeItem(at:filler)
        let recovered:SQLiteDatabase
        var reopenedSchema = schema
        if mode == "same-owner" {
            // Missing main storage must never be recreated, even with a journal.
            let held = volume.appendingPathComponent("held.sqlite")
            try FileManager.default.moveItem(at:url,to:held)
            XCTAssertThrowsError(try db.recoverControlConnection(at:url,schema:schema))
            XCTAssertFalse(FileManager.default.fileExists(atPath:url.path))
            try FileManager.default.moveItem(at:held,to:url)
            try db.recoverControlConnection(at:url,schema:schema)
            recovered = db
        } else {
            try db.close()
            if mode == "wrong-schema" {
                let wrong = CompiledSchema(applicationID:0x54535431,version:2,statements:schema.statements,validate:{_ in})
                XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:wrong,controlProfile:true)) {XCTAssertEqual($0 as? StorageFailure,.schemaMismatch)}
            }
            if mode == "wrong-identity" {
                let wrong = CompiledSchema(applicationID:schema.applicationID,version:schema.version,statements:schema.statements,validate:{_ in throw CoreRepositoryError("STORAGE_UNAVAILABLE")})
                XCTAssertThrowsError(try SQLiteDatabase.open(at:url,schema:wrong,controlProfile:true)) {XCTAssertEqual(($0 as? CoreRepositoryError)?.code,"STORAGE_UNAVAILABLE")}
            }
            if mode == "migration" {
                let migration = "CREATE TABLE migrated(value TEXT NOT NULL)"
                let upgraded = CompiledSchema(applicationID:schema.applicationID,version:2,statements:schema.statements+[migration],validate:{sql in
                    try BackupIO.require(try sql.query("SELECT name FROM sqlite_master WHERE name='migrated'") == [[.text("migrated")]],"TEST_SCHEMA")
                })
                recovered = try SQLiteDatabase.open(at:url,schema:upgraded,upgradeFrom:schema,migrationStatements:[migration],controlProfile:true)
                reopenedSchema = upgraded
            } else {
                recovered = try SQLiteDatabase.open(at:url,schema:schema,controlProfile:true)
            }
        }
        defer{try? recovered.close()}
        XCTAssertEqual(try recovered.read{try $0.query("SELECT * FROM kept")},[[.integer(1),.text("retained")]],mode)
        try recovered.transaction {try $0.execute("INSERT INTO kept VALUES(3,'retry')")}
        try recovered.close()
        let reopened = try SQLiteDatabase.open(at:url,schema:reopenedSchema,controlProfile:true);defer{try? reopened.close()}
        XCTAssertEqual(try reopened.read{try $0.query("SELECT id FROM kept ORDER BY id")},[[.integer(1)],[.integer(3)]],mode)
    }
}
#endif
