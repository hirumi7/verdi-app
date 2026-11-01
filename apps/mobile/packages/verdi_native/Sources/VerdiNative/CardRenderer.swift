import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

/// Creates a fresh raster. No source metadata, notes or location enter this API.
enum CardRenderer {
    static let maximumBytes = 16 * 1024 * 1024
    static func image(_ files:MediaFiles,_ path:String) throws -> CGImage {
        let fd=try files.openRead(path);defer{Darwin.close(fd)}
        guard let source=CGImageSourceCreateWithURL(files.root.appendingPathComponent(path) as CFURL,[kCGImageSourceShouldCache:false] as CFDictionary),
              let image=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceThumbnailMaxPixelSize:1350,kCGImageSourceCreateThumbnailWithTransform:true] as CFDictionary) else {throw CoreRepositoryError("MEDIA_INVALID")}
        return image
    }
    static func render(name:String,species:String,images:[CGImage],dates:[String]) throws -> Data {
        guard images.count<=2, dates.isEmpty || dates.count==2,
              let c=CGContext(data:nil,width:1080,height:1350,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipLast.rawValue) else {throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        func color(_ r:CGFloat,_ g:CGFloat,_ b:CGFloat)->CGColor {CGColor(red:r/255,green:g/255,blue:b/255,alpha:1)}
        let ink=color(19,27,22),leaf=color(31,107,65)
        c.setFillColor(color(242,243,239));c.fill(CGRect(x:0,y:0,width:1080,height:1350))
        func text(_ value:String,rect:CGRect,size:CGFloat,color:CGColor) throws {
            guard !value.isEmpty else{return}
            // Fit all UTF-16 characters with CoreText wrapping, including emoji/fallback fonts.
            var fitted=false
            for point in stride(from:size,through:12,by:-1) {
                let font=CTFontCreateWithName("Helvetica" as CFString,point,nil)
                let string=NSAttributedString(string:value,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):color])
                let setter=CTFramesetterCreateWithAttributedString(string)
                let path=CGPath(rect:rect,transform:nil),frame=CTFramesetterCreateFrame(setter,CFRange(location:0,length:0),path,nil)
                if CTFrameGetVisibleStringRange(frame).length==string.length {CTFrameDraw(frame,c);fitted=true;break}
            }
            guard fitted else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        }
        try text(name,rect:CGRect(x:64,y:1085,width:952,height:200),size:64,color:ink)
        try text(species,rect:CGRect(x:64,y:890,width:952,height:185),size:34,color:leaf)
        let panels = images.count==2 ? [CGRect(x:48,y:215,width:480,height:650),CGRect(x:552,y:215,width:480,height:650)] : [CGRect(x:64,y:215,width:952,height:650)]
        for (index,panel) in panels.enumerated() {
            c.saveGState();c.addPath(CGPath(roundedRect:panel,cornerWidth:32,cornerHeight:32,transform:nil));c.clip()
            c.setFillColor(color(225,232,220));c.fill(panel)
            if images.indices.contains(index) {
                let image=images[index],scale=min(panel.width/CGFloat(image.width),panel.height/CGFloat(image.height))
                let size=CGSize(width:CGFloat(image.width)*scale,height:CGFloat(image.height)*scale)
                c.interpolationQuality = .high;c.draw(image,in:CGRect(x:panel.midX-size.width/2,y:panel.midY-size.height/2,width:size.width,height:size.height))
            } else {
                // Fixed local vector illustration; no inferred species/health claims.
                c.setFillColor(leaf);c.fill(CGRect(x:panel.midX-8,y:panel.minY+175,width:16,height:290))
                for offset in [CGFloat(0),100] {
                    c.fillEllipse(in:CGRect(x:panel.midX-150,y:panel.minY+270+offset,width:150,height:85))
                    c.fillEllipse(in:CGRect(x:panel.midX,y:panel.minY+230+offset,width:150,height:85))
                }
                c.setFillColor(color(181,132,100));c.fill(CGRect(x:panel.midX-110,y:panel.minY+100,width:220,height:150))
            }
            c.restoreGState()
            if dates.indices.contains(index) {try text(dates[index],rect:CGRect(x:panel.minX,y:148,width:panel.width,height:50),size:30,color:ink)}
        }
        try text("Verdi · Plant care",rect:CGRect(x:64,y:55,width:952,height:50),size:28,color:leaf)
        guard let raster=c.makeImage() else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        let data=NSMutableData()
        guard let output=CGImageDestinationCreateWithData(data,UTType.png.identifier as CFString,1,nil) else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        CGImageDestinationAddImage(output,raster,nil)
        guard CGImageDestinationFinalize(output) else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        let result=try withoutMetadata(data as Data);try validate(result);return result
    }
    private static func withoutMetadata(_ data:Data) throws -> Data {
        // ImageIO may insert its own timestamp metadata even with nil properties.
        // Drop whole metadata chunks, preserving the CRC of every retained chunk.
        guard data.count<=maximumBytes,data.count>=8 else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        var result=Data(data.prefix(8)),offset=8
        while offset+12<=data.count {
            let length=data[offset..<offset+4].reduce(0){($0<<8)|Int($1)}
            guard length<=data.count-offset-12 else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
            let type=String(decoding:data[offset+4..<offset+8],as:UTF8.self)
            if !["eXIf","tEXt","zTXt","iTXt","tIME"].contains(type) {result.append(data[offset..<offset+12+length])}
            offset+=12+length
        }
        guard offset==data.count else{throw CoreRepositoryError("CARD_GENERATION_FAILED")};return result
    }
    static func validate(_ data:Data) throws {
        guard data.count<=maximumBytes,data.count>32,Array(data.prefix(8))==[137,80,78,71,13,10,26,10],
              let source=CGImageSourceCreateWithData(data as CFData,nil),CGImageSourceGetCount(source)==1,
              let p=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              (p[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue==1080,(p[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue==1350 else {throw CoreRepositoryError("CARD_GENERATION_FAILED")}
        // Reject metadata-bearing PNG chunks, including textual XMP/comment payloads.
        var offset=8
        while offset+12<=data.count {
            let length=data[offset..<offset+4].reduce(0){($0<<8)|Int($1)}
            guard length<=data.count-offset-12 else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
            let type=String(decoding:data[offset+4..<offset+8],as:UTF8.self)
            guard !["eXIf","tEXt","zTXt","iTXt"].contains(type) else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
            offset+=12+length
        }
        guard offset==data.count else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
    }
}
