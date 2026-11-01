import Foundation

extension CoreRegistry {
    static func photoScope(_ sql:SQLiteSession,_ p:CorePlan,_ d:[CoreDelta],allocated:[String],guards:[CanonicalValue],clock:CoreClockFrame) throws {
        let id=try CoreSchema.string(p.payload["photoId"]),old=try requiredRow(sql,"photos",id)
        try require(old[1] != .null && old[3] == .integer(try CoreSchema.number(p.payload["photoRevision"])),"STALE_TARGET")
        try require(allocated.isEmpty)
        let targets=d.filter{$0.table=="photos" && $0.id==id};try require(targets.count==1)
        let target=targets[0]
        if p.type=="UpdatePhotoObservation" {
            try require(d.count==1 && guards.isEmpty && target.action=="update")
            let date=try CoreSchema.string(p.payload["observedDate"]);try require(date<=clock.today,"FUTURE_OBSERVATION_DATE")
            try require(target.values[10] == .text(date))
            for i in old.indices where ![3,10].contains(i) {try require(target.values[i]==old[i])}
        } else if p.type=="ReplacePhoto" {
            let draftID=try CoreSchema.string(p.payload["draftId"]),draft=try requiredRow(sql,"media_drafts",draftID)
            try require(draft[1] == .integer(try CoreSchema.number(p.payload["draftRevision"])) && draft[2]==old[1] && draft[3]==old[0] && draft[4]==old[3],"DRAFT_CONFLICT")
            try require(guards.count==1 && guards[0].object?["draftId"]?.text==draftID && (try CoreSchema.same(guards[0].object?["revision"],p.payload["draftRevision"])))
            let ids=try storedIDs(draft[5]);try require(ids.count==1,"MEDIA_NOT_READY")
            let fresh=try requiredRow(sql,"photos",ids[0]),prepID=try CoreSchema.string(p.payload["preparationId"])
            let prep=try sql.query("SELECT state,photo_id,draft_id FROM media_preparations WHERE id=?",[.text(prepID)])
            try require(prep.count==1 && prep[0]==[.text("ready"),fresh[0],.text(draftID)],"MEDIA_NOT_READY")
            try require(d.count==3 && target.action=="update" && d.contains{$0.table=="media_drafts" && $0.id==draftID && $0.action=="delete"} && d.contains{$0.table=="photos" && $0.id==ids[0] && $0.action=="delete"})
            let ext=(try CoreSchema.text(fresh[4]) as NSString).pathExtension
            try require(target.values[4] == .text("media/\(id)/\(try CoreSchema.text(fresh[5])).\(ext)"))
            for i in [0,1,2,13] {try require(target.values[i]==old[i])}
            for i in 5...12 {try require(target.values[i]==fresh[i])}
            if fresh[12] != .null {try require(fresh[12]==old[5] && fresh[10]==old[10] && fresh[11]==old[11],"STALE_TARGET")}
        } else if p.type=="DeletePhoto" {
            try require(target.action=="delete" && d.allSatisfy{["photos","plant_covers","journal_entries","journal_drafts","plant_drafts"].contains($0.table)})
            try require(try sql.query("SELECT id FROM media_drafts WHERE photo_id=?",[.text(id)]).isEmpty,"DRAFT_CONFLICT")
            try require(d.filter{$0.table=="photos"}.count==1)
            var expected:Set<String>=["photos:"+id],expectedGuards:[String:CanonicalValue]=[:]
            for cover in try sql.query("SELECT id FROM plant_covers WHERE photo_id=?",[.text(id)]) {
                let plant=try CoreSchema.text(cover[0]);expected.insert("plant_covers:"+plant)
                try require(d.contains{$0.table=="plant_covers" && $0.id==plant && $0.action=="delete"})
            }
            for row in try sql.query("SELECT id FROM journal_entries") {
                let entryID=try CoreSchema.text(row[0]),e=try requiredRow(sql,"journal_entries",entryID),ids=try storedIDs(e[5]);if !ids.contains(id){continue}
                expected.insert("journal_entries:"+entryID)
                guard let change=d.first(where:{$0.table=="journal_entries" && $0.id==entryID}) else {throw CoreRepositoryError("PLAN_INVALID")}
                let remaining=ids.filter{$0 != id}
                if remaining.isEmpty && e[4] == .text("") {
                    try require(try sql.query("SELECT id FROM journal_drafts WHERE entry_id=?",[.text(entryID)]).isEmpty,"DRAFT_CONFLICT")
                    try require(change.action=="delete")
                } else {
                    try require(change.action=="update" && (try storedIDs(change.values[5]))==remaining)
                    for i in [0,1,3,4,6] {try require(change.values[i]==e[i])}
                }
            }
            for row in try sql.query("SELECT id FROM journal_drafts") {
                let draftID=try CoreSchema.text(row[0]),draft=try requiredRow(sql,"journal_drafts",draftID),fields=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(draft[5]))),ids=try mediaIDs(fields["selectedPhotoIds"])
                if !ids.contains(id){continue}
                expected.insert("journal_drafts:"+draftID);expectedGuards[draftID]=CoreSchema.canonical(draft[1])
                guard let change=d.first(where:{$0.table=="journal_drafts" && $0.id==draftID}) else {throw CoreRepositoryError("PLAN_INVALID")}
                var after=fields;after["selectedPhotoIds"] = .array(ids.filter{$0 != id}.map(CanonicalValue.string))
                try require(change.action=="update" && (try CoreSchema.same(CanonicalParser.parse(CoreSchema.text(change.values[5])),.object(after))))
                for i in [0,2,3,4,6,7] {try require(change.values[i]==draft[i])}
            }
            for row in try sql.query("SELECT id FROM plant_drafts") {
                let draftID=try CoreSchema.text(row[0]),draft=try requiredRow(sql,"plant_drafts",draftID)
                var envelope=try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(draft[5])))
                var fields=try CoreSchema.object(envelope["fields"])
                if fields["coverPhotoId"]?.text != id {continue}
                expected.insert("plant_drafts:"+draftID);expectedGuards[draftID]=CoreSchema.canonical(draft[1])
                guard let change=d.first(where:{$0.table=="plant_drafts" && $0.id==draftID}) else{throw CoreRepositoryError("PLAN_INVALID")}
                fields["coverPhotoId"] = .null;envelope["fields"] = .object(fields)
                try require(change.action=="update" && (try CoreSchema.same(CanonicalParser.parse(CoreSchema.text(change.values[5])),.object(envelope))))
                for i in [0,2,3,4,6] {try require(change.values[i]==draft[i])}
            }
            try require(Set(d.map{$0.table+":"+$0.id})==expected)
            let actual=try guards.reduce(into:[String:CanonicalValue]()){r,g in r[try CoreSchema.string(g.object?["draftId"])]=g.object?["revision"]}
            try require(try CoreSchema.same(.object(actual),.object(expectedGuards)))
        } else {throw CoreRepositoryError("PLAN_INVALID")}
    }
}

extension CoreRegistry {
    static func originalPath(_ row:[SQLValue]) throws -> String {
        let id=try CoreSchema.text(row[0]),hash=try CoreSchema.text(row[5]),path=try CoreSchema.text(row[4]),mime=try CoreSchema.text(row[7])
        try CoreSchema.uuid(id)
        try require(hash.range(of:"^[0-9a-f]{64}$",options:.regularExpression) != nil,"MEDIA_INVALID")
        guard let ext=["image/jpeg":"jpg","image/png":"png","image/heic":"heic"][mime] else{throw CoreRepositoryError("MEDIA_INVALID")}
        try require(path=="media/\(id)/\(hash).\(ext)","MEDIA_INVALID")
        return path
    }
}
