import Foundation
import XCTest
@testable import VerdiNative

extension BackupParserTests {
    /// Independently assembled ZIP records, including forced ZIP64 at tiny sizes.
    func zipFixture(wide:Bool=false,descriptor:Int=0,names:[String]=["manifest.json","data.json"],flags:Int=0,external:UInt64=0x81a40000,expanded:UInt64=2,crc:UInt64=0xa3a6bf43) -> Data {
        var output=Data(),central=Data()
        func n(_ v:UInt64,_ width:Int)->Data {Data((0..<width).map{UInt8(truncatingIfNeeded:v >> ($0*8))})}
        func fields(_ values:[(UInt64,Int)])->Data {values.reduce(into:Data()){$0.append(n($1.0,$1.1))}}
        for name in names {
            let path=Data(name.utf8),offset=UInt64(output.count),f=UInt64(flags | (descriptor == 0 ? 0:8)),size:UInt64=wide ? 0xffffffff:expanded
            let localExtra=wide ? fields([(1,2),(16,2),(expanded,8),(2,8)]):Data()
            output.append(fields([(0x04034b50,4),(wide ? 45:20,2),(f,2),(0,2),(0,2),(0,2),(descriptor == 0 ? crc:0,4),(wide ? 0xffffffff:descriptor == 0 ? 2:0,4),(wide ? size:descriptor == 0 ? expanded:0,4),(UInt64(path.count),2),(UInt64(localExtra.count),2)]))
            output.append(path);output.append(localExtra);output.append(Data("{}".utf8))
            if descriptor != 0 {if descriptor==2 {output.append(n(0x08074b50,4))};output.append(fields([(crc,4),(2,wide ? 8:4),(expanded,wide ? 8:4)]))}
            let extra=wide ? fields([(1,2),(24,2),(expanded,8),(2,8),(offset,8)]):Data()
            central.append(fields([(0x02014b50,4),(0x032d,2),(wide ? 45:20,2),(f,2),(0,2),(0,2),(0,2),(crc,4),(wide ? 0xffffffff:2,4),(size,4),(UInt64(path.count),2),(UInt64(extra.count),2),(0,2),(0,2),(0,2),(external,4),(wide ? 0xffffffff:offset,4)]));central.append(path);central.append(extra)
        }
        let offset=UInt64(output.count),size=UInt64(central.count),count=UInt64(names.count)
        output.append(central)
        if wide {
            let record=UInt64(output.count)
            output.append(fields([(0x06064b50,4),(44,8),(45,2),(45,2),(0,4),(0,4),(count,8),(count,8),(size,8),(offset,8)]))
            output.append(fields([(0x07064b50,4),(0,4),(record,8),(1,4)]))
        }
        output.append(fields([(0x06054b50,4),(0,2),(0,2),(wide ? 0xffff:count,2),(wide ? 0xffff:count,2),(wide ? 0xffffffff:size,4),(wide ? 0xffffffff:offset,4),(0,2)]))
        return output
    }
    func extractFixture(_ bytes:Data) throws {
        let key=UUID().uuidString,zip=root.appendingPathComponent(key+".zip"),target=root.appendingPathComponent(key)
        try bytes.write(to:zip);try BackupIO.directory(target)
        let pre=try BackupIndex(root.appendingPathComponent(key+"-pre.sqlite"))
        do {try BackupZIPPreflight(zip,index:pre,cancel:{}).validate()} catch {throw NSError(domain:"Preflight \(error)",code:1)}
        let index=try BackupIndex(root.appendingPathComponent(key+".sqlite"))
        try BackupArchive.extract(zip,to:target,index:index,cancel:{})
        XCTAssertEqual(try Data(contentsOf:target.appendingPathComponent("data.json")),Data("{}".utf8))
    }
    func testZIP32ZIP64SignedUnsignedDescriptors() throws {
        for wide in [false,true] {for descriptor in 0...2 {do {try extractFixture(zipFixture(wide:wide,descriptor:descriptor))} catch {XCTFail("wide=\(wide) descriptor=\(descriptor): \(error)")}}}
    }
    func testHostileZIPMetadataCRCAndStreamedJSONLimits() throws {
        let cases:[Data]=[
            zipFixture(names:["manifest.json","manifest.json"]),
            zipFixture(names:["manifest.json","DATA.json"]),
            zipFixture(names:["manifest.json","../data.json"]),
            zipFixture(names:["manifest.json","/data.json"]),
            zipFixture(names:["manifest.json","media/../data.json"]),
            zipFixture(flags:1),zipFixture(external:0xa1ff0000),
            zipFixture(expanded:513*1024*1024),zipFixture(crc:0),
            zipFixture()+Data([0]),zipFixture().dropLast(8),
        ]
        for (i,bytes) in cases.enumerated() {XCTAssertThrowsError(try extractFixture(bytes),"case \(i)")}
        let deep=try reader(String(repeating:"[",count:18)+"0"+String(repeating:"]",count:18))
        XCTAssertThrowsError(try deep.value())
        let large=root.appendingPathComponent("large.json")
        try Data(("\""+String(repeating:"x",count:2*1024*1024)+"\"").utf8).write(to:large)
        let stream=try BackupJSONReader(large,limit:3*1024*1024)
        XCTAssertThrowsError(try stream.value())
    }
    func testDeflateExactChunkBoundaryRefillsInput() throws {
        // Independent Python/zlib fixture: 59 repeated bytes plus deterministic
        // random bytes; first input chunk fills the output chunk exactly.
        let zip=try XCTUnwrap(Bundle.module.url(forResource:"backup-deflate-boundary",withExtension:"zip",subdirectory:"Fixtures")),target=root.appendingPathComponent("boundary")
        try BackupIO.directory(target)
        let index=try BackupIndex(root.appendingPathComponent("boundary.sqlite"))
        try BackupArchive.extract(zip,to:target,index:index,cancel:{})
        let digest=try BackupIO.hash(target.appendingPathComponent("data.json"))
        XCTAssertEqual(digest.1,200059)
        XCTAssertEqual(digest.0,"110acaf03ca5692d681a8e6ec98a0268488060a1c114f02fae48c4e2639d3c15")
    }

}
