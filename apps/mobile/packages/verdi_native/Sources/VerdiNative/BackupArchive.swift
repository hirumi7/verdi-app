import Foundation
import Darwin
import ZIPFoundation
import zlib

/// Disk-backed inventory shared by ZIP preflight and streamed manifest validation.
final class BackupIndex {
    let database: SQLiteDatabase
    static let definitions = [
        "CREATE TABLE entries(path TEXT PRIMARY KEY COLLATE NOCASE NOT NULL,crc INTEGER NOT NULL,compressed INTEGER NOT NULL,expanded INTEGER NOT NULL,start INTEGER NOT NULL UNIQUE,end INTEGER NOT NULL,method INTEGER NOT NULL,payload INTEGER NOT NULL,seen INTEGER NOT NULL DEFAULT 0)",
        "CREATE TABLE files(id TEXT PRIMARY KEY NOT NULL,path TEXT NOT NULL UNIQUE COLLATE NOCASE,hash TEXT NOT NULL,bytes INTEGER NOT NULL,mime TEXT NOT NULL)",
    ]
    init(_ url: URL) throws {
        database = try SQLiteDatabase.create(at:url,schema:CompiledSchema(applicationID:0x56424932,version:1,statements:Self.definitions,validate:{_ in}))
    }
    func eachFile(_ work: ([SQLValue]) throws -> Void) throws {
        var after = ""
        while let row = try database.read({try $0.query("SELECT id,path,hash,bytes,mime FROM files WHERE id>? ORDER BY id LIMIT 1",[.text(after)]).first}) {
            after = try CoreSchema.text(row[0]); try work(row)
        }
    }
    deinit { try? database.close() }
}

/// Verifies records and ranges independently of ZIPFoundation's interpretation.
final class BackupZIPPreflight {
    let fd: Int32, length: Int64, index: BackupIndex
    let cancel: () throws -> Void
    init(_ url: URL, index: BackupIndex, cancel: @escaping () throws -> Void) throws {
        fd = try BackupIO.read(url); length = try BackupIO.size(url); self.index = index; self.cancel = cancel
    }
    deinit { Darwin.close(fd) }
    func bytes(_ offset: Int64, _ count: Int) throws -> [UInt8] {
        try BackupIO.require(offset >= 0 && count >= 0 && offset <= length && Int64(count) <= length-offset, "BACKUP_ARCHIVE_INVALID")
        var result = [UInt8](repeating:0,count:count), position = 0
        while position < count {
            let n = result.withUnsafeMutableBytes { raw in pread(fd,raw.baseAddress!.advanced(by:position),count-position,offset+Int64(position)) }
            if n < 0 && errno == EINTR { continue }
            try BackupIO.require(n > 0,"BACKUP_ARCHIVE_INVALID"); position += n
        }
        return result
    }
    func number(_ b: [UInt8], _ position: Int, _ width: Int) throws -> Int64 {
        try BackupIO.require(position >= 0 && position + width <= b.count,"BACKUP_ARCHIVE_INVALID")
        var n: UInt64 = 0
        for j in 0..<width { n |= UInt64(b[position+j]) << UInt64(j*8) }
        try BackupIO.require(n <= UInt64(Int64.max),"BACKUP_LIMIT"); return Int64(n)
    }
    func extra(_ data: [UInt8], sentinels: [(Int64,Int)]) throws -> [Int64] {
        var position = 0, seen = Set<Int64>(), zip: [UInt8]?
        while position < data.count {
            let id = try number(data,position,2), size = Int(try number(data,position+2,2)); position += 4
            try BackupIO.require(position+size <= data.count && seen.insert(id).inserted,"BACKUP_ARCHIVE_INVALID")
            if id == 1 { zip = Array(data[position..<position+size]) }; position += size
        }
        var cursor = 0, result = [Int64]()
        for (value,width) in sentinels {
            let sentinel: Int64 = width == 4 ? 0xffff : 0xffffffff
            if value == sentinel {
                guard let zip else { throw CoreRepositoryError("BACKUP_ARCHIVE_INVALID") }
                result.append(try number(zip,cursor,width)); cursor += width
            } else { result.append(value) }
        }
        try BackupIO.require(zip == nil ? cursor == 0 : cursor == zip!.count,"BACKUP_ARCHIVE_INVALID")
        return result
    }
    func validate() throws {
        try BackupIO.require(length >= 22 && length <= BackupIO.archiveLimit,"BACKUP_LIMIT")
        let tailOffset = max(0,length-65557), tail = try bytes(tailOffset,Int(length-tailOffset))
        var candidates = [Int]()
        for i in 0...tail.count-22 where tail[i] == 0x50 && tail[i+1] == 0x4b && tail[i+2] == 5 && tail[i+3] == 6 {
            if Int64(i+22) + (try number(tail,i+20,2)) == Int64(tail.count) { candidates.append(i) }
        }
        try BackupIO.require(candidates.count == 1,"BACKUP_ARCHIVE_INVALID")
        let e = candidates[0], eocd = tailOffset+Int64(e)
        try BackupIO.require(try number(tail,e+4,2) == 0 && number(tail,e+6,2) == 0 && number(tail,e+8,2) == number(tail,e+10,2),"BACKUP_ARCHIVE_INVALID")
        var count = try number(tail,e+10,2), size = try number(tail,e+12,4), start = try number(tail,e+16,4), directoryEnd = eocd
        let locator = eocd >= 20 ? try bytes(eocd-20,20) : []
        if try locator.count == 20 && number(locator,0,4) == 0x07064b50 {
            try BackupIO.require(try number(locator,4,4) == 0 && number(locator,16,4) == 1,"BACKUP_ARCHIVE_INVALID")
            let offset = try number(locator,8,8), record = try bytes(offset,56)
            try BackupIO.require(try number(record,0,4) == 0x06064b50 && number(record,4,8) == 44 && offset+56 == eocd-20 && number(record,16,4) == 0 && number(record,20,4) == 0 && number(record,24,8) == number(record,32,8),"BACKUP_ARCHIVE_INVALID")
            let c = try number(record,32,8), s = try number(record,40,8), o = try number(record,48,8)
            try BackupIO.require((count == 0xffff || count == c) && (size == 0xffffffff || size == s) && (start == 0xffffffff || start == o),"BACKUP_ARCHIVE_INVALID")
            count = c; size = s; start = o; directoryEnd = offset
        } else { try BackupIO.require(count != 0xffff && size != 0xffffffff && start != 0xffffffff,"BACKUP_ARCHIVE_INVALID") }
        try BackupIO.require(count >= 2 && count <= 50002 && start <= directoryEnd && size == directoryEnd-start,"BACKUP_LIMIT")
        var position = start, expanded: Int64 = 0
        try index.database.transaction { sql in
            for _ in 0..<count {
                try cancel()
                let h = try bytes(position,46)
                try BackupIO.require(try number(h,0,4) == 0x02014b50,"BACKUP_ARCHIVE_INVALID")
                let flags = try number(h,8,2), method = try number(h,10,2), crc = try number(h,16,4)
                let nameLength = Int(try number(h,28,2)), extraLength = Int(try number(h,30,2)), commentLength = Int(try number(h,32,2))
                let external = try number(h,38,4), unixType = (external >> 16) & 0xf000
                try BackupIO.require(flags & ~0x808 == 0 && [0,8].contains(method) && [0,0x8000].contains(unixType) && external & 0x10 == 0,"BACKUP_ARCHIVE_INVALID")
                try BackupIO.require(nameLength > 0 && nameLength <= 180 && position+46+Int64(nameLength+extraLength+commentLength) <= directoryEnd,"BACKUP_PATH_INVALID")
                let name = try bytes(position+46,nameLength)
                guard name.allSatisfy({$0 < 128}), let path = String(bytes:name,encoding:.ascii) else {throw CoreRepositoryError("BACKUP_PATH_INVALID")}
                if path != "manifest.json" && path != "data.json" { try BackupIO.canonicalMedia(path) }
                let values = try extra(bytes(position+46+Int64(nameLength),extraLength),sentinels:[(number(h,24,4),8),(number(h,20,4),8),(number(h,42,4),8),(number(h,34,2),4)])
                let uncompressed = values[0], compressed = values[1], local = values[2]
                try BackupIO.require(values[3] == 0 && compressed <= BackupIO.archiveLimit && uncompressed <= (path == "data.json" ? 512*1024*1024 : path == "manifest.json" ? 16*1024*1024 : 64*1024*1024),"BACKUP_LIMIT")
                expanded += uncompressed; try BackupIO.require(expanded <= BackupIO.expandedLimit,"BACKUP_LIMIT")
                let l = try bytes(local,30), ln = Int(try number(l,26,2)), le = Int(try number(l,28,2))
                try BackupIO.require(try number(l,0,4) == 0x04034b50 && number(l,6,2) == flags && number(l,8,2) == method && ln == nameLength && bytes(local+30,ln) == name,"BACKUP_ARCHIVE_INVALID")
                let lv = try extra(bytes(local+30+Int64(ln),le),sentinels:[(number(l,22,4),8),(number(l,18,4),8)])
                let dataStart = local+30+Int64(ln+le)
                try BackupIO.require(dataStart <= start && compressed <= start-dataStart,"BACKUP_ARCHIVE_INVALID")
                var end = dataStart+compressed
                let lc = try number(l,14,4)
                if flags & 8 == 0 { try BackupIO.require(lc == crc && lv == [uncompressed,compressed],"BACKUP_ARCHIVE_INVALID") }
                else {
                    try BackupIO.require((lc == 0 || lc == crc) && (lv[0] == 0 || lv[0] == uncompressed) && (lv[1] == 0 || lv[1] == compressed),"BACKUP_ARCHIVE_INVALID")
                    let wide = try number(l,18,4) == 0xffffffff || number(l,22,4) == 0xffffffff || number(h,20,4) == 0xffffffff || number(h,24,4) == 0xffffffff
                    let width = wide ? 8 : 4
                    let signature = try number(bytes(end,4),0,4) == 0x08074b50
                    let d = try bytes(end,(signature ? 8 : 4)+2*width), shift = signature ? 4 : 0
                    try BackupIO.require(try number(d,shift,4) == crc && number(d,shift+4,width) == compressed && number(d,shift+4+width,width) == uncompressed,"BACKUP_ARCHIVE_INVALID")
                    end += Int64(d.count)
                }
                try BackupIO.require(end <= start && (method != 0 || compressed == uncompressed),"BACKUP_ARCHIVE_INVALID")
                try sql.execute("INSERT INTO entries(path,crc,compressed,expanded,start,end,method,payload) VALUES(?,?,?,?,?,?,?,?)",[.text(path),.integer(crc),.integer(compressed),.integer(uncompressed),.integer(local),.integer(end),.integer(method),.integer(dataStart)])
                position += 46+Int64(nameLength+extraLength+commentLength)
            }
            try BackupIO.require(position == directoryEnd,"BACKUP_ARCHIVE_INVALID")
            var offset: Int64 = 0
            while let row = try sql.query("SELECT start,end FROM entries WHERE start>=? ORDER BY start LIMIT 1",[.integer(offset)]).first {
                try BackupIO.require(row[0] == .integer(offset),"BACKUP_ARCHIVE_INVALID")
                offset = try CoreSchema.integer(row[1])
            }
            try BackupIO.require(offset == start,"BACKUP_ARCHIVE_INVALID")
        }
    }
}

enum BackupArchive {
    static func extract(_ zip: URL, to root: URL, index: BackupIndex, io: BackupFileIO = BackupFileIO(), cancel: @escaping () throws -> Void) throws {
        let reader=try BackupZIPPreflight(zip,index:index,cancel:cancel)
        try reader.validate()
        let reserve = try index.database.read { sql in
            try CoreSchema.integer(sql.query("SELECT COALESCE(sum(expanded),0)+4*COALESCE(sum(CASE WHEN path='data.json' THEN expanded ELSE 0 END),0) FROM entries")[0][0])
        }
        try BackupIO.reserve(at:root,additional:reserve)
        var cursor = ""
        while let row = try index.database.read({try $0.query("SELECT path,crc,compressed,expanded,method,payload FROM entries WHERE path>? ORDER BY path LIMIT 1",[.text(cursor)]).first}) {
            try cancel();let path=try CoreSchema.text(row[0]);cursor=path
            let compressed=try CoreSchema.integer(row[2]),expanded=try CoreSchema.integer(row[3]),method=try CoreSchema.integer(row[4]),payload=try CoreSchema.integer(row[5])
            let destination: URL
            if path == "data.json" || path == "manifest.json" { destination = root.appendingPathComponent(path) }
            else { try BackupIO.canonicalMedia(path); let files = try MediaFiles(root:root); let (dir,_) = try files.parent(path,create:true); Darwin.close(dir); destination = root.appendingPathComponent(path) }
            let writer=try BackupWriter(destination,limit:expanded,io:io)
            var checksum:uLong=0,offset:Int64=0
            func accept(_ data:Data) throws {
                try cancel();try writer.write(data)
                checksum=data.withUnsafeBytes{crc32(checksum,$0.bindMemory(to:Bytef.self).baseAddress,uInt(data.count))}
            }
            if method == 0 {
                while offset<compressed {
                    let bytes=try reader.bytes(payload+offset,Int(min(Int64(BackupIO.chunk),compressed-offset)))
                    try accept(Data(bytes));offset+=Int64(bytes.count)
                }
            } else {
                var stream=z_stream(),ended=false
                try BackupIO.require(inflateInit2_(&stream,-MAX_WBITS,ZLIB_VERSION,Int32(MemoryLayout<z_stream>.size)) == Z_OK,"BACKUP_ARCHIVE_INVALID")
                defer{inflateEnd(&stream)}
                while offset<compressed && !ended {
                    var input=try reader.bytes(payload+offset,Int(min(Int64(BackupIO.chunk),compressed-offset)))
                    offset+=Int64(input.count)
                    try input.withUnsafeMutableBufferPointer { buffer in
                        stream.next_in=buffer.baseAddress;stream.avail_in=uInt(buffer.count)
                        repeat {
                            try cancel();var output=[UInt8](repeating:0,count:BackupIO.chunk)
                            let before=stream.avail_in
                            let status=output.withUnsafeMutableBufferPointer { out -> Int32 in
                                stream.next_out=out.baseAddress;stream.avail_out=uInt(out.count)
                                return inflate(&stream,Z_NO_FLUSH)
                            }
                            let produced=BackupIO.chunk-Int(stream.avail_out)
                            // A full output chunk may exhaust input exactly. zlib
                            // then asks for another input chunk with Z_BUF_ERROR.
                            if status == Z_BUF_ERROR && stream.avail_in==0 && produced==0 && offset<compressed {break}
                            try BackupIO.require(status == Z_OK || status == Z_STREAM_END,"BACKUP_ARCHIVE_INVALID")
                            try accept(Data(output.prefix(produced)))
                            if status == Z_STREAM_END {ended=true;break}
                            try BackupIO.require(produced>0 || stream.avail_in<before,"BACKUP_ARCHIVE_INVALID")
                        } while stream.avail_in>0 || stream.avail_out==0
                        if ended {try BackupIO.require(stream.avail_in==0 && offset==compressed,"BACKUP_ARCHIVE_INVALID")}
                    }
                }
                try BackupIO.require(ended && stream.total_in==UInt(compressed),"BACKUP_ARCHIVE_INVALID")
            }
            try BackupIO.require(writer.count==expanded,"BACKUP_ARCHIVE_INVALID")
            try BackupIO.require(Int64(checksum)==CoreSchema.integer(row[1]),"BACKUP_CRC_MISMATCH")
            try writer.finish()
            try index.database.transaction {try $0.execute("UPDATE entries SET seen=1 WHERE path=?",[.text(path)])}
        }
    }

    static func create(_ destination: URL, dataRoot: URL, mediaRoot: URL, index: BackupIndex, io: BackupFileIO = BackupFileIO(), cancel: () throws -> Void) throws {
        do {
            let archive = try Archive(url:destination,accessMode:.create)
            try BackupIO.protect(destination)
            func add(_ path: String, _ root: URL, _ compression: CompressionMethod) throws {
                try cancel(); let url = root.appendingPathComponent(path), size = try BackupIO.size(url), fd = try BackupIO.read(url)
                defer { Darwin.close(fd) }
                try archive.addEntry(with:path,type:.file,uncompressedSize:size,permissions:0o600,compressionMethod:compression,bufferSize:BackupIO.chunk) { position, length in
                    try cancel(); var buffer = [UInt8](repeating:0,count:length), used = 0
                    while used < length {
                        let n = buffer.withUnsafeMutableBytes { raw in pread(fd,raw.baseAddress!.advanced(by:used),length-used,position+Int64(used)) }
                        if n < 0 && errno == EINTR {continue}; try BackupIO.require(n > 0,"IO_FAILURE"); used += n
                    }
                    return Data(buffer)
                }
                try BackupIO.require(try BackupIO.size(destination) <= BackupIO.archiveLimit,"BACKUP_LIMIT")
            }
            try add("manifest.json",dataRoot,.deflate); try add("data.json",dataRoot,.deflate)
            try index.eachFile { try add(CoreSchema.text($0[1]),mediaRoot,.none) }
        }
        try BackupIO.flush(destination,io:io)
    }
}
