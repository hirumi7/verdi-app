import Foundation
import CryptoKit

struct ReminderPreferences: Equatable {
    let enabled:Bool
    let minute:Int, quietStart:Int, quietEnd:Int
    let revision:Int64
    init(_ value:CanonicalValue) throws {
        let v = try CoreSchema.object(value)
        guard case .boolean(let enabled) = v["enabled"] else {throw CoreRepositoryError("FIELD_INVALID")}
        self.enabled = enabled
        minute = Int(try CoreSchema.number(v["preferredMinute"]))
        quietStart = Int(try CoreSchema.number(v["quietStartMinute"]))
        quietEnd = Int(try CoreSchema.number(v["quietEndMinute"]))
        revision = try CoreSchema.number(v["settingsRevision"])
        guard [minute,quietStart,quietEnd].allSatisfy({(0...1439).contains($0)}), (1...CoreSchema.maxRevision).contains(revision) else {throw CoreRepositoryError("FIELD_INVALID")}
    }
}
struct ReminderHead: Codable, Equatable {
    let headId:String
    let headRevision:Int64
    var value:CanonicalValue {.object(["headId":.string(headId),"headRevision":.integer(headRevision)])}
    var ordered:String {get throws {"{\"headId\":\(try CanonicalValue.string(headId).json()),\"headRevision\":\(headRevision)}"}}
}
struct ReminderGroup {
    let fire:Date
    let heads:[ReminderHead]
    func ordered(dataset:String,settings:Int64,zone:String,revision:Int64? = nil) throws -> String {
        let p = revision.map{",\"planRevision\":\($0)"} ?? ""
        return "{\"datasetId\":\(try CanonicalValue.string(dataset).json())\(p),\"settingsRevision\":\(settings),\"timeZoneId\":\(try CanonicalValue.string(zone).json()),\"fireAt\":\(try CanonicalValue.string(ReminderPlan.instant(fire)).json()),\"heads\":[\(try heads.map{try $0.ordered}.joined(separator:","))]}"
    }
}
public struct ReminderRequest {
    public let identifier:String, fireAt:Date, payloadJSON:String
    public let count:Int
    let group:ReminderGroup
}
struct ReminderContext {
    let dataset:String, collection:Int64, settings:CanonicalValue, savedSchedule:Bool
    var revision:Int64 {settings.object!["revision"]!.integer!}
    var preferences:ReminderPreferences {get throws {try ReminderPreferences(settings.object!["reminders"]!)}}
}
struct ReminderPlan {
    static let prefix = "verdi.check.v1."
    static func instant(_ date:Date)->String {CoreClockFrame.capture(date,zone:TimeZone(secondsFromGMT:0)!).instant}
    static func date(_ text:String) throws -> Date {
        let f=ISO8601DateFormatter();f.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        guard let value=f.date(from:text) else{throw CoreRepositoryError("FIELD_INVALID")};return value
    }
    static func digest(_ text:String)->String {SHA256.hash(data:Data(text.utf8)).map{String(format:"%02x",$0)}.joined()}
    static func fire(_ local:String, preferences p:ReminderPreferences, zone:TimeZone) throws -> Date {
        let parts=local.split(separator:"-").compactMap{Int($0)}
        guard parts.count==3 else{throw CoreRepositoryError("FIELD_INVALID")}
        var cal=Calendar(identifier:.gregorian);cal.timeZone=zone
        guard let day=cal.date(from:DateComponents(year:parts[0],month:parts[1],day:parts[2],hour:12)) else{throw CoreRepositoryError("FIELD_INVALID")}
        func quiet(_ minute:Int)->Bool {p.quietStart != p.quietEnd && (p.quietStart < p.quietEnd ? minute >= p.quietStart && minute < p.quietEnd : minute >= p.quietStart || minute < p.quietEnd)}
        func resolve(_ day:Date,_ minute:Int) throws -> Date {
            var components=cal.dateComponents([.year,.month,.day],from:day)
            components.hour=minute/60;components.minute=minute%60;components.second=0
            guard let result=cal.nextDate(after:cal.startOfDay(for:day).addingTimeInterval(-1),matching:components,matchingPolicy:.nextTime,repeatedTimePolicy:.first,direction:.forward) else {throw CoreRepositoryError("FIELD_INVALID")}
            return result
        }
        var chosenDay=day, minute=p.minute
        if quiet(minute) {
            if p.quietStart > p.quietEnd && minute >= p.quietStart {guard let next=cal.date(byAdding:.day,value:1,to:day) else{throw CoreRepositoryError("FIELD_INVALID")};chosenDay=next}
            minute=p.quietEnd
        }
        var result=try resolve(chosenDay,minute)
        let actual=cal.component(.hour,from:result)*60+cal.component(.minute,from:result)
        if quiet(actual) {
            if p.quietStart > p.quietEnd && actual >= p.quietStart {guard let next=cal.date(byAdding:.day,value:1,to:result) else{throw CoreRepositoryError("FIELD_INVALID")};result=next}
            result=try resolve(result,p.quietEnd)
        }
        return result
    }
    static func requests(_ groups:[ReminderGroup],context:ReminderContext,zone:String,revision:Int64) throws -> [ReminderRequest] {
        try groups.map { group in
            let payload:CanonicalValue = .object(["version":.integer(1),"datasetId":.string(context.dataset),"planRevision":.integer(revision),"settingsRevision":.integer(try context.preferences.revision),"heads":.array(group.heads.map(\.value))])
            return ReminderRequest(identifier:prefix+digest(try group.ordered(dataset:context.dataset,settings:context.preferences.revision,zone:zone,revision:revision)),fireAt:group.fire,payloadJSON:try payload.json(),count:group.heads.count,group:group)
        }
    }
}

/// Keeps at most the first budget*16 sorted heads of a fire instant, even when
/// thousands share that date. Input fire instants must be nondecreasing.
struct ReminderAccumulator {
    let budget:Int
    var groups:[ReminderGroup]=[], current:Date?, heads:[ReminderHead]=[]
    var count=0, totalGroups=0, past=0
    mutating func add(_ head:ReminderHead,fire:Date) {
        if current != fire {flush();current=fire}
        count += 1
        let keep=max(0,budget-groups.count)*16
        if keep>0 {
            heads.append(head);heads.sort{$0.headId < $1.headId}
            if heads.count>keep {heads.removeLast()}
        }
    }
    mutating func flush() {
        guard let current, count>0 else{return}
        totalGroups += (count+15)/16
        for offset in stride(from:0,to:heads.count,by:16) where groups.count<budget {
            groups.append(ReminderGroup(fire:current,heads:Array(heads[offset..<min(offset+16,heads.count)])))
        }
        count=0;heads=[]
    }
}
