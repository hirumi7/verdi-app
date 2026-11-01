import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// No source-sized bitmap allocation. The returned JPEG is a deliberate lossy
/// replacement; the caller keeps the original until its domain command commits.
enum PhotoOptimizer {
    static func render(_ files:MediaFiles,_ path:String,expectedHash:String) throws -> Data {
        let info=try files.inspect(path)
        try CoreRegistry.require(info.hash==expectedHash,"MEDIA_INVALID")
        guard let source=CGImageSourceCreateWithURL(files.root.appendingPathComponent(path) as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any] else{throw CoreRepositoryError("MEDIA_INVALID")}
        // Conservatively reject alpha-bearing input, even if all samples happen
        // to be opaque. Never flatten transparency to a guessed background.
        if (properties[kCGImagePropertyHasAlpha] as? NSNumber)?.boolValue==true {throw CoreRepositoryError("MEDIA_UNSUPPORTED")}
        let edge=Int(min(1280,max(info.width,info.height)))
        guard let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:edge,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceShouldCacheImmediately:true] as CFDictionary),
              image.width>0,image.height>0,max(image.width,image.height)<=edge,
              let context=CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else{throw CoreRepositoryError("MEDIA_INVALID")}
        context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        guard let raster=context.makeImage() else{throw CoreRepositoryError("MEDIA_INVALID")}
        let data=NSMutableData()
        guard let destination=CGImageDestinationCreateWithData(data,UTType.jpeg.identifier as CFString,1,nil) else{throw CoreRepositoryError("IO_FAILURE")}
        CGImageDestinationAddImage(destination,raster,[kCGImageDestinationLossyCompressionQuality:85/100.0] as CFDictionary)
        guard CGImageDestinationFinalize(destination),data.length>0,data.length<=16*1024*1024,
              let checked=CGImageSourceCreateWithData(data,nil),CGImageSourceGetStatus(checked) == .statusComplete,
              CGImageSourceGetType(checked) as String? == UTType.jpeg.identifier,
              let p=CGImageSourceCopyPropertiesAtIndex(checked,0,nil) as? [CFString:Any],
              (p[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue==image.width,
              (p[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue==image.height,
              CGImageSourceCreateImageAtIndex(checked,0,nil) != nil else{throw CoreRepositoryError("MEDIA_INVALID")}
        return data as Data
    }
}
