import Foundation
import Darwin
import CryptoKit

struct CardSnapshot {
    let request:[String:CanonicalValue],session:String,dataset:String,files:MediaFiles
    let plant:[SQLValue],cover:[SQLValue]?,photos:[[SQLValue]],capability:Int64?
    var name:String {plant[2].stringValue!}
    var species:String {plant[5].stringValue!}
    var dates:[String] {request["kind"]?.text=="comparison" ? photos.map{$0[10].stringValue!}:[]}
}
struct CardPreview {
    let snapshot:CardSnapshot,path:String,hash:String,created:TimeInterval
}
struct CardFileStamp:Equatable {
    let device:Int32,inode:UInt64,size:Int64,modified:Int64,modifiedNanos:Int64,changed:Int64,changedNanos:Int64
    init(_ files:MediaFiles,_ path:String) throws {
        let fd=try files.openRead(path);defer{Darwin.close(fd)}
        var s=stat();guard fstat(fd,&s)==0 else{throw CoreRepositoryError("MEDIA_MISSING")}
        device=s.st_dev;inode=s.st_ino;size=s.st_size;modified=Int64(s.st_mtimespec.tv_sec);modifiedNanos=Int64(s.st_mtimespec.tv_nsec);changed=Int64(s.st_ctimespec.tv_sec);changedNanos=Int64(s.st_ctimespec.tv_nsec)
    }
}
/// An opaque preflight, not permission to share. Final synchronous grant checks
/// the trusted rows/capability and unchanged inode stamps immediately before OS use.
public struct CardHandoffPreparation {
    let token:String,preview:CardPreview,stamps:[String:CardFileStamp]
}
public struct CardHandoff {
    public let leaseID:String,url:URL
}
extension CoreRepository {
    func expireCards() {
        let time=elapsed()
        cardPreviews=cardPreviews.filter{$0.value.snapshot.session==sessionID && time >= $0.value.created && time-$0.value.created<600}
    }
    func cardFileRetained(_ files:MediaFiles,_ path:String)->Bool {
        expireCards()
        let url=files.root.appendingPathComponent(path)
        return cardPreviews.values.contains{$0.snapshot.files.root.appendingPathComponent($0.path)==url} || cardOSFiles.values.contains(url)
    }
    func cardSnapshot(_ request:[String:CanonicalValue],access:StoreCapability) throws -> CardSnapshot {
        guard !replacementAdmissionClosed,let db=database,let files=mediaFiles,!sessionID.isEmpty else{throw CoreRepositoryError("BUSY")}
        guard Set(request.keys)==Set(["datasetId","kind","plantId","plantRevision","imageChoice","photos"]),
              let plant=request["plantId"]?.text,let revision=request["plantRevision"]?.integer,revision>0,
              let selection=request["photos"]?.array,let kind=request["kind"]?.text else{throw CoreRepositoryError("FIELD_INVALID")}
        try CoreSchema.uuid(plant)
        guard request["datasetId"]?.text==datasetID else{throw CoreRepositoryError("DATASET_CHANGED")}
        let comparison=kind=="comparison"
        guard (kind=="plant" && selection.isEmpty && ["cover","illustration"].contains(request["imageChoice"]?.text ?? "")) ||
              (comparison && request["imageChoice"]?.isNull==true && selection.count==2) else{throw CoreRepositoryError("FIELD_INVALID")}
        var selectedIDs=Set<String>()
        for item in selection {
            guard let m=item.object,Set(m.keys)==Set(["id","revision"]),let id=m["id"]?.text,let r=m["revision"]?.integer,r>0,selectedIDs.insert(id).inserted else{throw CoreRepositoryError("FIELD_INVALID")}
            try CoreSchema.uuid(id)
        }
        if comparison && !access.pro {throw CoreRepositoryError("PRO_REQUIRED")}
        return try db.read {sql in
            let p=try CoreRegistry.requiredRow(sql,"plants",plant)
            guard p[1] == .integer(revision) else{throw CoreRepositoryError("STALE_TARGET")}
            var rows:[[SQLValue]]=[],cover:[SQLValue]?
            if comparison {
                var seen=Set<String>()
                for item in selection {
                    guard let m=item.object,Set(m.keys)==Set(["id","revision"]),let id=m["id"]?.text,let r=m["revision"]?.integer,r>0,seen.insert(id).inserted else{throw CoreRepositoryError("FIELD_INVALID")}
                    try CoreSchema.uuid(id)
                    let photo=try CoreRegistry.requiredRow(sql,"photos",id)
                    guard photo[1] == .text(plant),photo[3] == .integer(r) else{throw CoreRepositoryError("STALE_TARGET")};rows.append(photo)
                }
                if rows[0][10].stringValue! > rows[1][10].stringValue! {rows.swapAt(0,1)}
            } else if request["imageChoice"]?.text=="cover" {
                cover=try CoreSchema.row(sql,"plant_covers",plant)
                guard let cover else{throw CoreRepositoryError("MEDIA_MISSING")}
                let photo=try CoreRegistry.requiredRow(sql,"photos",CoreSchema.text(cover[1]))
                guard photo[1] == .text(plant) else{throw CoreRepositoryError("MEDIA_INVALID")};rows=[photo]
            }
            return CardSnapshot(request:request,session:sessionID,dataset:datasetID,files:files,plant:p,cover:cover,photos:rows,capability:comparison ? access.revision:nil)
        }
    }
    func recheckCard(_ old:CardSnapshot,access:StoreCapability) throws {
        guard old.session==sessionID,old.dataset==datasetID,old.files.root==directory else{throw CoreRepositoryError("CARD_EXPIRED")}
        let current:CardSnapshot
        do {current=try cardSnapshot(old.request,access:access)}
        catch let e as CoreRepositoryError where ["STALE_TARGET","NOT_FOUND","MEDIA_MISSING"].contains(e.code) {throw CoreRepositoryError("PREVIEW_STALE")}
        guard current.plant==old.plant,current.cover==old.cover,current.photos==old.photos,current.capability==old.capability else{throw CoreRepositoryError("PREVIEW_STALE")}
    }
    func card(_ token:String) throws -> CardPreview {
        expireCards();guard let value=cardPreviews[token] else{throw CoreRepositoryError("CARD_EXPIRED")};return value
    }
    static func cardHash(_ data:Data)->String {SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()}
    func checkCardSource(_ photo:[SQLValue],_ files:MediaFiles) throws {
        let info=try files.inspect(CoreRegistry.originalPath(photo))
        guard .text(info.hash)==photo[5],.integer(info.bytes)==photo[6],.text(info.mime)==photo[7],.integer(info.width)==photo[8],.integer(info.height)==photo[9] else{throw CoreRepositoryError("MEDIA_INVALID")}
    }
    public func prepareCard(_ request:String,completion:@escaping(Result<String,Error>)->Void) {
        mediaWorker.async { [self] in
            do {
                let input:[String:CanonicalValue]
                do {guard request.utf8.count<=8192 else{throw CoreRepositoryError("FIELD_INVALID")};input=try CoreSchema.object(CanonicalParser.parse(request))}
                catch {throw CoreRepositoryError("FIELD_INVALID")}
                let snapshot:CardSnapshot=try queue.sync {
                    expireCards();guard cardPreviews.count<8 else{throw CoreRepositoryError("CARD_LIMIT")}
                    return try withCapability {try cardSnapshot(input,access:$0)}
                }
                for photo in snapshot.photos {try checkCardSource(photo,snapshot.files)}
                let images=try snapshot.photos.map{try CardRenderer.image(snapshot.files,CoreRegistry.originalPath($0))}
                let bytes=try CardRenderer.render(name:snapshot.name,species:snapshot.species,images:images,dates:snapshot.dates)
                let token=UUID().uuidString.lowercased(),path="exports/\(token).png",stage="exports/\(token).partial"
                try queue.sync {
                    try withCapability {try recheckCard(snapshot,access:$0)}
                    guard let db=database else{throw CoreRepositoryError("CARD_EXPIRED")}
                    try db.transaction {sql in for p in [stage,path] {try registerMediaPath(sql,p);try sql.execute("INSERT INTO media_cleanup VALUES(?,?)",[.text(p),.text(mediaClock())])}}
                }
                do {
                    try snapshot.files.writeCard(bytes,to:stage);try snapshot.files.publish(stage,to:path)
                    for photo in snapshot.photos {try checkCardSource(photo,snapshot.files)}
                    let stored=try snapshot.files.readCard(path)
                    guard stored==bytes else{throw CoreRepositoryError("CARD_GENERATION_FAILED")}
                    try queue.sync {
                        try withCapability {try recheckCard(snapshot,access:$0)}
                        cardPreviews[token]=CardPreview(snapshot:snapshot,path:path,hash:Self.cardHash(bytes),created:elapsed())
                    }
                } catch {cleanupMedia();throw error}
                completion(.success(try CanonicalValue.object(["token":.string(token),"kind":input["kind"]!,"width":.integer(1080),"height":.integer(1350),"plantName":.string(snapshot.name),"speciesName":.string(snapshot.species),"dates":.array(snapshot.dates.map(CanonicalValue.string)),"expiresInSeconds":.integer(600)]).json()))
            } catch {completion(.failure(error))}
        }
    }
    public func readCard(_ token:String,completion:@escaping(Result<Data,Error>)->Void) {
        mediaWorker.async { [self] in
            do {
                let preview=try queue.sync{try card(token)},bytes=try preview.snapshot.files.readCard(preview.path)
                guard Self.cardHash(bytes)==preview.hash else{throw CoreRepositoryError("PREVIEW_STALE")}
                _=try queue.sync{try card(token)};completion(.success(bytes))
            } catch {completion(.failure(error))}
        }
    }
    public func releaseCard(_ token:String) {
        queue.sync{_ = cardPreviews.removeValue(forKey:token)}
        mediaWorker.async{self.cleanupMedia()}
    }
    public func prepareCardHandoff(_ token:String,completion:@escaping(Result<CardHandoffPreparation,Error>)->Void) {
        mediaWorker.async { [self] in
            do {
                let preview=try queue.sync{try card(token)},files=preview.snapshot.files
                let paths=Set([preview.path]+(try preview.snapshot.photos.map{try CoreRegistry.originalPath($0)}))
                let before=try Dictionary(uniqueKeysWithValues:paths.map{($0,try CardFileStamp(files,$0))})
                for p in preview.snapshot.photos {try checkCardSource(p,files)}
                let bytes=try files.readCard(preview.path)
                guard Self.cardHash(bytes)==preview.hash else{throw CoreRepositoryError("PREVIEW_STALE")}
                for path in paths {guard try CardFileStamp(files,path)==before[path] else{throw CoreRepositoryError("PREVIEW_STALE")}}
                try queue.sync {_=try card(token);try withCapability{try recheckCard(preview.snapshot,access:$0)}}
                completion(.success(CardHandoffPreparation(token:token,preview:preview,stamps:before)))
            } catch {completion(.failure(error))}
        }
    }
    /// Call synchronously immediately before invoking the OS, after permissions.
    /// Heavy image/hash work already ran on mediaWorker. Stamps prevent a changed
    /// file from reusing that validation while queue/capability locks protect rows.
    public func grantCardHandoff(_ prepared:CardHandoffPreparation) throws -> CardHandoff {
        try queue.sync {try withCapability {access in
            let p=try card(prepared.token)
            try recheckCard(p.snapshot,access:access)
            guard cardOSFiles.isEmpty else{throw CoreRepositoryError("BUSY")}
            for (path,stamp) in prepared.stamps {guard try CardFileStamp(p.snapshot.files,path)==stamp else{throw CoreRepositoryError("PREVIEW_STALE")}}
            let id=UUID().uuidString.lowercased(),url=p.snapshot.files.root.appendingPathComponent(p.path)
            platformLeases[id]=datasetID;cardOSFiles[id]=url
            return CardHandoff(leaseID:id,url:url)
        }}
    }
    public func releaseCardHandoff(_ lease:String) {
        queue.sync {_=platformLeases.removeValue(forKey:lease);_=cardOSFiles.removeValue(forKey:lease)}
        mediaWorker.async{self.cleanupMedia()}
    }
}
