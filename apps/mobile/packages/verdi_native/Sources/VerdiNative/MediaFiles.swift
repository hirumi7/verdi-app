import Foundation
import Darwin
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

public enum MediaFileBoundary { case create, write, flush, publish, parentFlush }
struct MediaFileInfo {
    let hash:String, mime:String, ext:String
    let bytes:Int64, width:Int64, height:Int64
}
/// Physical operations only. Callers register every destination before creation.
/// All operations run on the media worker, never the SQLite executor.
final class MediaFiles {
    let root:URL
    let fault:((MediaFileBoundary)throws->Void)?
    init(root:URL,fault:((MediaFileBoundary)throws->Void)?=nil, directoryIO:BackupFileIO = BackupFileIO()) throws {
        self.root=root;self.fault=fault
        try BackupIO.directory(root,io:directoryIO)
        var info=stat();guard lstat(root.path,&info)==0,(info.st_mode&S_IFMT)==S_IFDIR else {throw CoreRepositoryError("MEDIA_PATH_INVALID")}
        try protection(root)
    }
    func protection(_ url:URL) throws {
        #if os(iOS)
        _ = try DraftProtection.apply(deviceRequired: CoreRepository.deviceProtectionRequired, set: {
            try FileManager.default.setAttributes([.protectionKey:FileProtectionType.completeUntilFirstUserAuthentication],ofItemAtPath:url.path)
        }, read: {
            let value=try FileManager.default.attributesOfItem(atPath:url.path)[.protectionKey]
            return (value as? FileProtectionType)?.rawValue ?? (value as? String)
        })
        #endif
    }
    func parent(_ relative:String,create:Bool) throws -> (Int32,String) {
        let parts=relative.split(separator:"/",omittingEmptySubsequences:false).map(String.init)
        guard !parts.isEmpty,parts.allSatisfy({!$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") && !$0.contains("\0")}) else {throw CoreRepositoryError("MEDIA_PATH_INVALID")}
        var fd=Darwin.open(root.path,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)
        guard fd>=0 else {throw CoreRepositoryError("IO_FAILURE")}
        do {
            var path=root
            for part in parts.dropLast() {
                path.appendPathComponent(part)
                if create {
                    if mkdirat(fd,part,S_IRWXU) != 0 && errno != EEXIST {throw CoreRepositoryError("IO_FAILURE")}
                    guard fsync(fd)==0 else {throw CoreRepositoryError("IO_FAILURE")}
                }
                let next=openat(fd,part,O_RDONLY|O_DIRECTORY|O_NOFOLLOW|O_CLOEXEC)
                guard next>=0 else {throw CoreRepositoryError(errno == ENOENT ? "MEDIA_MISSING":"MEDIA_PATH_INVALID")}
                guard Darwin.close(fd)==0 else {Darwin.close(next);fd = -1;throw CoreRepositoryError("IO_FAILURE")}
                fd=next
                if create {try protection(path)}
            }
            return (fd,parts.last!)
        } catch {if fd>=0 {Darwin.close(fd)};throw error}
    }
    func openRead(_ relative:String) throws -> Int32 {
        let (dir,name)=try parent(relative,create:false);defer{Darwin.close(dir)}
        let fd=openat(dir,name,O_RDONLY|O_NOFOLLOW|O_CLOEXEC)
        guard fd>=0 else {throw CoreRepositoryError("MEDIA_MISSING")}
        var info=stat();guard fstat(fd,&info)==0,(info.st_mode&S_IFMT)==S_IFREG else {Darwin.close(fd);throw CoreRepositoryError("MEDIA_PATH_INVALID")}
        return fd
    }
    func exists(_ relative:String)->Bool {guard let fd=try? openRead(relative) else{return false};Darwin.close(fd);return true}
    /// External source URLs come only from the native OS picker callback.
    func importSelection(_ source:URL,to relative:String) throws {
        let fd=Darwin.open(source.path,O_RDONLY|O_NOFOLLOW|O_CLOEXEC)
        guard fd>=0 else {throw CoreRepositoryError("IO_FAILURE")}
        defer{Darwin.close(fd)}
        try copy(fd,to:relative)
    }
    func copy(_ source:String,to destination:String) throws {
        let fd=try openRead(source);defer{Darwin.close(fd)};try copy(fd,to:destination)
    }
    private func copy(_ source:Int32,to relative:String) throws {
        let (dir,name)=try parent(relative,create:true);defer{Darwin.close(dir)}
        try fault?(.create)
        let fd=openat(dir,name,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,S_IRUSR|S_IWUSR)
        guard fd>=0 else {throw CoreRepositoryError("IO_FAILURE")}
        var closed=false;defer{if !closed{Darwin.close(fd)}}
        try protection(root.appendingPathComponent(relative))
        if ["selections","staging","exports"].contains(relative.split(separator:"/").first.map(String.init) ?? "") {
            var temporary=root.appendingPathComponent(relative.split(separator:"/").first.map(String.init)!)
            var values=URLResourceValues();values.isExcludedFromBackup=true;try temporary.setResourceValues(values)
            var file=root.appendingPathComponent(relative);try file.setResourceValues(values)
        }
        var buffer=[UInt8](repeating:0,count:65536),total=0
        while true {
            let n=Darwin.read(source,&buffer,buffer.count)
            if n<0 && errno==EINTR {continue}
            guard n>=0 else {throw CoreRepositoryError("IO_FAILURE")}
            if n==0 {break};total+=n
            guard total<=64*1024*1024 else {throw CoreRepositoryError("MEDIA_TOO_LARGE")}
            try buffer.withUnsafeBytes { raw in
                var offset=0
                while offset<n {
                    try fault?(.write)
                    let written=Darwin.write(fd,raw.baseAddress!.advanced(by:offset),n-offset)
                    if written<0 && errno==EINTR {continue}
                    guard written>0 else {throw CoreRepositoryError("IO_FAILURE")};offset+=written
                }
            }
        }
        guard total>0 else {throw CoreRepositoryError("MEDIA_INVALID")}
        try fault?(.flush)
        guard fsync(fd)==0,fcntl(fd,F_FULLFSYNC)==0 else {throw CoreRepositoryError("IO_FAILURE")}
        let status=Darwin.close(fd);closed=true;guard status==0 else {throw CoreRepositoryError("IO_FAILURE")}
        try fault?(.parentFlush);guard fsync(dir)==0 else {throw CoreRepositoryError("IO_FAILURE")}
    }
    func writeCard(_ data:Data,to relative:String) throws {try writeGeneratedImage(data,to:relative)}
    func writeGeneratedImage(_ data:Data,to relative:String) throws {
        guard !data.isEmpty,data.count<=CardRenderer.maximumBytes else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        let (dir,name)=try parent(relative,create:true);defer{Darwin.close(dir)}
        try fault?(.create)
        let fd=openat(dir,name,O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW|O_CLOEXEC,S_IRUSR|S_IWUSR)
        guard fd>=0 else{throw CoreRepositoryError("IO_FAILURE")}
        var closed=false;defer{if !closed{Darwin.close(fd)}}
        try protection(root.appendingPathComponent(relative))
        var url=root.appendingPathComponent(relative),values=URLResourceValues();values.isExcludedFromBackup=true;try url.setResourceValues(values)
        try data.withUnsafeBytes { raw in
            var offset=0
            while offset<data.count {
                try fault?(.write)
                let n=Darwin.write(fd,raw.baseAddress!.advanced(by:offset),data.count-offset)
                if n<0 && errno==EINTR{continue};guard n>0 else{throw CoreRepositoryError("IO_FAILURE")};offset+=n
            }
        }
        try fault?(.flush);guard fsync(fd)==0,fcntl(fd,F_FULLFSYNC)==0 else{throw CoreRepositoryError("IO_FAILURE")}
        let closeStatus=Darwin.close(fd);closed=true;guard closeStatus==0 else{throw CoreRepositoryError("IO_FAILURE")}
        try fault?(.parentFlush);guard fsync(dir)==0 else{throw CoreRepositoryError("IO_FAILURE")}
    }
    func readCard(_ relative:String) throws -> Data {
        let fd=try openRead(relative);defer{Darwin.close(fd)}
        var data=Data(),buffer=[UInt8](repeating:0,count:65536)
        while true {
            let n=Darwin.read(fd,&buffer,buffer.count)
            if n<0 && errno==EINTR{continue};guard n>=0 else{throw CoreRepositoryError("IO_FAILURE")};if n==0{break}
            guard data.count+n<=CardRenderer.maximumBytes else{throw CoreRepositoryError("CARD_GENERATION_FAILED")};data.append(contentsOf:buffer.prefix(n))
        }
        try CardRenderer.validate(data);return data
    }
    func inspect(_ relative:String) throws -> MediaFileInfo {
        let fd=try openRead(relative);defer{Darwin.close(fd)}
        var hash=SHA256(),buffer=[UInt8](repeating:0,count:65536),total:Int64=0
        while true {
            let n=Darwin.read(fd,&buffer,buffer.count);if n<0 && errno==EINTR{continue}
            guard n>=0 else{throw CoreRepositoryError("IO_FAILURE")};if n==0{break}
            total+=Int64(n);guard total<=67108864 else{throw CoreRepositoryError("MEDIA_TOO_LARGE")}
            hash.update(data:Data(buffer.prefix(n)))
        }
        guard let source=CGImageSourceCreateWithURL(root.appendingPathComponent(relative) as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),CGImageSourceGetCount(source)==1,CGImageSourceGetStatus(source) == .statusComplete,
              let type=CGImageSourceGetType(source) as String?,let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],let width=props[kCGImagePropertyPixelWidth] as? NSNumber,let height=props[kCGImagePropertyPixelHeight] as? NSNumber else{throw CoreRepositoryError("MEDIA_INVALID")}
        let w=width.int64Value,h=height.int64Value
        guard w>0,h>0,w<=100000000,h<=100000000,w*h<=100000000 else{throw CoreRepositoryError("MEDIA_TOO_LARGE")}
        let mime:String,ext:String
        switch type {case UTType.jpeg.identifier:mime="image/jpeg";ext="jpg";case UTType.png.identifier:mime="image/png";ext="png";case UTType.heic.identifier:mime="image/heic";ext="heic";default:throw CoreRepositoryError("MEDIA_INVALID")}
        // Force decoder validation using a bounded image, without full-size allocation.
        guard CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:64,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) != nil else{throw CoreRepositoryError("MEDIA_INVALID")}
        return MediaFileInfo(hash:hash.finalize().map{String(format:"%02x",$0)}.joined(),mime:mime,ext:ext,bytes:total,width:w,height:h)
    }
    func publish(_ staged:String,to destination:String) throws {
        let (from,name)=try parent(staged,create:false);defer{Darwin.close(from)}
        let (to,target)=try parent(destination,create:true);defer{Darwin.close(to)}
        try fault?(.publish)
        guard renameatx_np(from,name,to,target,UInt32(RENAME_EXCL))==0 else {throw CoreRepositoryError("IO_FAILURE")}
        // A rename preserves the staging inode's backup exclusion attribute.
        var original=root.appendingPathComponent(destination),values=URLResourceValues()
        values.isExcludedFromBackup=destination.hasPrefix("exports/")
        try original.setResourceValues(values)
        let fd=try openRead(destination);defer{Darwin.close(fd)}
        guard fsync(fd)==0 else{throw CoreRepositoryError("IO_FAILURE")}
        try fault?(.parentFlush);guard fsync(from)==0,fsync(to)==0 else{throw CoreRepositoryError("IO_FAILURE")}
    }
    func remove(_ relative:String) throws {
        let dir:Int32,name:String
        do {(dir,name)=try parent(relative,create:false)} catch let error as CoreRepositoryError where error.code=="MEDIA_MISSING" {return}
        defer{Darwin.close(dir)}
        if unlinkat(dir,name,0) != 0 && errno != ENOENT {throw CoreRepositoryError("IO_FAILURE")}
        guard fsync(dir)==0 else{throw CoreRepositoryError("IO_FAILURE")}
    }
    func preview(_ relative:String) throws -> Data {
        let fd=try openRead(relative);defer{Darwin.close(fd)}
        guard let source=CGImageSourceCreateWithURL(root.appendingPathComponent(relative) as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary) else{throw CoreRepositoryError("MEDIA_INVALID")}
        for size in [1024,768,512] {
            guard let thumbnail=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:size,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else{throw CoreRepositoryError("MEDIA_INVALID")}
            let data=NSMutableData()
            guard let destination=CGImageDestinationCreateWithData(data,UTType.png.identifier as CFString,1,nil) else{throw CoreRepositoryError("IO_FAILURE")}
            CGImageDestinationAddImage(destination,thumbnail,nil)
            guard CGImageDestinationFinalize(destination) else{throw CoreRepositoryError("IO_FAILURE")}
            if data.length<=2*1024*1024{return data as Data}
        }
        throw CoreRepositoryError("MEDIA_TOO_LARGE")
    }
}
