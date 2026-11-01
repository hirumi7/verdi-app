import Foundation

extension CoreRegistry {
    static let customCommands:Set<String> = ["CreateCustomCareType","RenameCustomCareType","RetireCustomCareType","CreateRoutine"]
    static let standardKinds=["water","fertilize","mist","repot","rotate"]
    static let standardLabels=["Water","Fertilize","Mist","Repot","Rotate"]
    static func customPayload(_ type:String,_ p:[String:CanonicalValue]) throws {
        func keys(_ expected:[String]) throws {try require(Set(p.keys)==Set(expected),"FIELD_INVALID")}
        func id(_ key:String) throws {try CoreSchema.uuid(CoreSchema.string(p[key]))}
        func revision(_ key:String) throws {try require((1...CoreSchema.maxRevision).contains(try CoreSchema.number(p[key])),"FIELD_INVALID")}
        if type == "CreateRoutine" {
            try keys(["plantId","plantRevision","careKind","customTypeId","customTypeRevision","interval","seed","catalogSelection"])
            try id("plantId");try revision("plantRevision")
            let custom=p["careKind"]?.text == "custom"
            try require(custom || standardKinds.contains(p["careKind"]?.text ?? ""),"FIELD_INVALID")
            if custom {try id("customTypeId");try revision("customTypeRevision");try require(p["catalogSelection"]?.isNull == true)}
            else {try require(p["customTypeId"]?.isNull == true && p["customTypeRevision"]?.isNull == true)}
            let interval=try CoreSchema.object(p["interval"])
            try require(Set(interval.keys)==Set(["count","unit"]) && (1...9999).contains(try CoreSchema.number(interval["count"])) && ["day","week","month","year"].contains(interval["unit"]?.text ?? ""),"FIELD_INVALID")
            let seed=try CoreSchema.object(p["seed"]),known=seed["kind"]?.text == "known",key=known ? "careDate":"firstCheckDate"
            try require(known || seed["kind"]?.text == "unknown");try require(Set(seed.keys)==Set(["kind",key]));try validDate(CoreSchema.string(seed[key]))
            if p["catalogSelection"]?.isNull != true {
                let s=try CoreSchema.object(p["catalogSelection"])
                try CatalogPackage.keys(s,["speciesId","catalogVersion","speciesNameSnapshot","suggestions"])
                _=try CatalogPackage.matches(s["speciesId"],"^[A-Za-z0-9_-]{1,128}$")
                _=try CatalogPackage.matches(s["catalogVersion"],"^[a-z0-9][a-z0-9._-]{0,79}$")
                _=try CatalogPackage.text(s["speciesNameSnapshot"],160);try CatalogPackage.suggestions(s["suggestions"])
            }
        } else {
            try keys(type == "CreateCustomCareType" ? ["label"]:type == "RenameCustomCareType" ? ["customTypeId","revision","label"]:["customTypeId","revision"])
            if type != "CreateCustomCareType" {try id("customTypeId");try revision("revision")}
            if type != "RetireCustomCareType" {_ = try validatedText(p["label"],max:24,required:true)}
        }
    }
    static func customScope(_ sql:SQLiteSession,_ p:CorePlan,_ d:[CoreDelta],allocated:[String],guards:[CanonicalValue],clock:CoreClockFrame,access:StoreCapability) throws {
        try require(guards.isEmpty)
        let gated=p.type == "CreateCustomCareType" || (p.type == "CreateRoutine" && p.payload["careKind"]?.text == "custom")
        if gated {try require(p.body["accessRevision"]?.integer == access.revision,"PREVIEW_STALE");try require(access.pro,"PRO_REQUIRED")}
        else {try require(p.body["accessRevision"]?.isNull == true)}
        if p.type != "CreateRoutine" {
            try require(d.allSatisfy{["custom_care_types","routines"].contains($0.table)})
            let types=d.filter{$0.table == "custom_care_types"}
            try require(types.count==1)
            let t=types[0]
            if p.type == "CreateCustomCareType" {
                try require(allocated.count==1 && d.count==1 && t.action=="insert" && t.id==allocated[0] && t.values==[.text(t.id),.integer(1),.text(try validatedText(p.payload["label"],max:24,required:true)),.integer(0)])
                return
            }
            let id=try CoreSchema.string(p.payload["customTypeId"]),old=try requiredRow(sql,"custom_care_types",id)
            try require(allocated.isEmpty && t.action=="update" && t.id==id && old[1] == .integer(try CoreSchema.number(p.payload["revision"])),"STALE_TARGET")
            let rename=p.type == "RenameCustomCareType"
            let label=rename ? try validatedText(p.payload["label"],max:24,required:true):try CoreSchema.text(old[2])
            try require(t.values[2] == .text(label) && t.values[3]==(rename ? old[3]:.integer(1)))
            if !rename {try require(old[3] == .integer(0),"NOT_ELIGIBLE");try require(d.count==1);return}
            let affected=try sql.query("SELECT r.id FROM routines r JOIN routine_custom_types l ON l.id=r.id WHERE l.custom_type_id=? AND r.state!='retired'",[.text(id)]).map{try CoreSchema.text($0[0])}
            let changed=d.filter{$0.table == "routines"}
            try require(Set(changed.map(\.id))==Set(affected) && d.count==affected.count+1)
            for r in changed {
                try require(r.action=="update" && r.values[4] == .text(label))
                for i in r.values.indices where ![2,4,12].contains(i) {try require(r.values[i]==r.before![i])}
            }
            return
        }
        try require(d.allSatisfy{["routines","heads","care_events","routine_custom_types","suggestion_snapshots","routine_suggestions"].contains($0.table)} && d.allSatisfy{$0.action=="insert"})
        let plant=try requiredRow(sql,"plants",CoreSchema.string(p.payload["plantId"]))
        try require(plant[1] == .integer(try CoreSchema.number(p.payload["plantRevision"])),"STALE_TARGET")
        try require(plant[8] == .integer(0),"NOT_ELIGIBLE")
        let kind=try CoreSchema.string(p.payload["careKind"]),custom=kind=="custom"
        let label:String
        if custom {
            let type=try requiredRow(sql,"custom_care_types",CoreSchema.string(p.payload["customTypeId"]))
            try require(type[1] == .integer(try CoreSchema.number(p.payload["customTypeRevision"])),"STALE_TARGET")
            try require(type[3] == .integer(0),"NOT_ELIGIBLE");label=try CoreSchema.text(type[2])
        } else {
            try require(try sql.query("SELECT id FROM routines WHERE plant_id=? AND care_kind=? AND state!='retired'",[plant[0],.text(kind)]).isEmpty,"NOT_ELIGIBLE")
            label=standardLabels[standardKinds.firstIndex(of:kind)!]
        }
        let rs=d.filter{$0.table=="routines"},hs=d.filter{$0.table=="heads"},es=d.filter{$0.table=="care_events"},links=d.filter{$0.table=="routine_custom_types"}
        let seed=try CoreSchema.object(p.payload["seed"]),known=seed["kind"]?.text=="known",date=try CoreSchema.string(seed[known ? "careDate":"firstCheckDate"])
        let selected=p.payload["catalogSelection"]?.isNull != true
        try require(allocated.count==2+(known ? 1:0)+(selected ? 1:0) && rs.count==1 && hs.count==1 && es.count==(known ? 1:0) && links.count==(custom ? 1:0))
        let r=rs[0],h=hs[0],interval=try CoreSchema.object(p.payload["interval"])
        let expected:[SQLValue]=[.text(allocated[0]),plant[0],.integer(1),.text(kind),.text(label),.text("active"),.integer(try CoreSchema.number(interval["count"])),.text(try CoreSchema.string(interval["unit"])),.text(date),.integer(known ? 0:1),known ? .null:.text(date),.text(clock.instant),.text(clock.instant)]
        try require(r.values==expected && h.id==allocated[1] && h.values[1]==r.values[0] && h.values[2] == .integer(1) && h.values[4] == .null)
        try validDate(CoreSchema.text(h.values[3]))
        if known {try validateNewEvent(es[0],routine:r.values,command:p,date:date,outcome:"actual_care",clock:clock);try require(es[0].id==allocated[2] && CoreSchema.text(h.values[3])>=clock.today)}
        else {try require(h.values[3] == .text(date))}
        if custom {try require(links[0].values==[r.values[0],try CoreSchema.scalar(p.payload["customTypeId"]!)])}
        if selected {
            var selection=try CoreSchema.object(p.payload["catalogSelection"])
            let species=selection.removeValue(forKey:"speciesId")!
            let stored=try requiredRow(sql,"plant_catalog",CoreSchema.text(plant[0]))
            try require(stored[1]==CoreSchema.scalar(species) && stored[2]==CoreSchema.scalar(selection["catalogVersion"]!) && CoreSchema.same(.object(selection),CanonicalParser.parse(CoreSchema.text(stored[3]))),"CATALOG_SELECTION_STALE")
            guard let suggestion=selection["suggestions"]?.array?.first(where:{$0.object?["careKind"]?.text==kind}) else {throw CoreRepositoryError("CATALOG_SELECTION_STALE")}
            try require(d.filter{$0.table=="suggestion_snapshots"}.count==1 && d.filter{$0.table=="routine_suggestions"}.count==1)
            try validateSuggestion(d,snapshotID:allocated.last!,routine:r.values,plant:CoreSchema.text(plant[0]),fields:["speciesId":species,"catalogSelection":.object(selection)],suggestion:suggestion,original:nil,adding:true)
        } else {try require(!d.contains{["suggestion_snapshots","routine_suggestions"].contains($0.table)})}
    }
}
