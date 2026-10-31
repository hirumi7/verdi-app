import Foundation

extension CoreRegistry {
    static func validatePayload(_ type: String, _ p: [String:CanonicalValue]) throws {
        func keys(_ expected: [String]) throws { try require(Set(p.keys) == Set(expected),"FIELD_INVALID") }
        func id(_ key: String) throws { try CoreSchema.uuid(CoreSchema.string(p[key])) }
        func revision(_ key: String, nullable: Bool = false) throws {
            if nullable && p[key]?.isNull == true { return }
            let n = try CoreSchema.number(p[key]); try require(n >= 1 && n <= CoreSchema.maxRevision,"FIELD_INVALID")
        }
        func date(_ key: String, nullable: Bool = false) throws {
            if nullable && p[key]?.isNull == true { return }; try validDate(CoreSchema.string(p[key]))
        }
        func targetShape(_ value: CanonicalValue?) throws {
            let t = try CoreSchema.object(value)
            try require(Set(t.keys) == Set(["plantId","plantRevision","routineId","routineRevision","headId","headRevision"]),"FIELD_INVALID")
            for key in ["plantId","routineId","headId"] { try CoreSchema.uuid(CoreSchema.string(t[key])) }
            for key in ["plantRevision","routineRevision","headRevision"] { let n = try CoreSchema.number(t[key]); try require(n >= 1 && n <= CoreSchema.maxRevision,"FIELD_INVALID") }
        }
        func outcome() throws { try require(["actual_care","checked_not_needed","skipped"].contains(p["outcome"]?.text ?? ""),"FIELD_INVALID") }
        switch type {
        case "SaveDraft":
            try keys(["draftId","expectedRevision","mode","plantId","basePlantRevision","rawFields","photoIds"])
            try id("draftId"); try revision("expectedRevision",nullable:true)
            try require(p["photoIds"]?.array?.isEmpty == true,"FIELD_INVALID")
            let mode = try CoreSchema.string(p["mode"])
            try validateRawFields(p["rawFields"],mode:mode)
            if mode == "add" { try require(p["plantId"]?.isNull == true && p["basePlantRevision"]?.isNull == true,"FIELD_INVALID") }
            else { try id("plantId"); try revision("basePlantRevision") }
        case "SavePlant", "DiscardDraft":
            try keys(type == "SavePlant" ? ["draftId","draftRevision"] : ["draftId","draftRevision","confirmed"])
            try id("draftId"); try revision("draftRevision")
            if type == "DiscardDraft" { try require(p["confirmed"]?.json() == "true","NOT_ELIGIBLE") }
        case "ArchivePlant", "RestorePlant", "DeletePlant": try keys(["plantId","plantRevision"]); try id("plantId"); try revision("plantRevision")
        case "Undo": try keys(["originalCommandId"]); try id("originalCommandId")
        case "BulkComplete":
            try keys(["targets","careKind","customTypeId","careDate"]); try date("careDate")
            try require(p["customTypeId"]?.isNull == true && ["water","fertilize","mist","repot","rotate"].contains(p["careKind"]?.text ?? ""),"FIELD_INVALID")
            let targets = try CoreSchema.array(p["targets"]); try require(!targets.isEmpty && targets.count <= 200,"FIELD_INVALID")
            for t in targets { try targetShape(t) }
            let ids = try targets.map { try CoreSchema.string($0.object?["routineId"]) }
            try require(ids == ids.sorted() && Set(ids).count == ids.count,"FIELD_INVALID")
        default:
            try targetShape(p["target"])
            switch type {
            case "CompleteCurrent": try keys(["target","careDate"]); try date("careDate")
            case "AddPastCare": try keys(["target","careDate","outcome"]); try date("careDate"); try outcome()
            case "CorrectEvent", "RestoreEvent": try keys(["target","eventId","eventRevision","careDate","outcome"]); try id("eventId"); try revision("eventRevision"); try date("careDate"); try outcome()
            case "VoidEvent": try keys(["target","eventId","eventRevision"]); try id("eventId"); try revision("eventRevision")
            case "CheckNotNeeded": try keys(["target","checkDate","nextCheckDate"]); try date("checkDate"); try date("nextCheckDate")
            case "Snooze": try keys(["target","nextCheckDate"]); try date("nextCheckDate")
            case "SetInterval":
                try keys(["target","interval","firstCheckDate"]); try date("firstCheckDate",nullable:true)
                let i = try CoreSchema.object(p["interval"]), n = try CoreSchema.number(i["count"])
                try require(Set(i.keys) == Set(["count","unit"]) && n >= 1 && n <= 9999 && ["day","week","month","year"].contains(i["unit"]?.text ?? ""),"FIELD_INVALID")
            case "ClearOverride": try keys(["target","firstCheckDate"]); try date("firstCheckDate",nullable:true)
            case "PauseRoutine", "ResumeRoutine", "RetireRoutine", "Skip": try keys(["target"])
            default: throw CoreRepositoryError("FIELD_INVALID")
            }
        }
    }
    static func validateRawFields(_ value: CanonicalValue?, mode: String) throws {
        let fields = try CoreSchema.object(value)
        try require(["add","edit"].contains(mode) && Set(fields.keys) == Set(["name","location","notes","identityKind","coverPhotoId","speciesId","catalogSelection","customSpeciesName","customLight","customToxicity","routineInputs","baseRoutineRevisions","speciesChoices"]),"FIELD_INVALID")
        try require(["name","location","notes","customSpeciesName"].allSatisfy {fields[$0]?.units != nil},"FIELD_INVALID")
        try require(fields["identityKind"]?.text == "custom" && ["coverPhotoId","speciesId","catalogSelection"].allSatisfy {fields[$0]?.isNull == true},"FIELD_INVALID")
        try require(["unknown","low","medium","bright-indirect","direct"].contains(fields["customLight"]?.text ?? "") && ["unknown","toxic","non-toxic"].contains(fields["customToxicity"]?.text ?? ""),"FIELD_INVALID")
        let routines = try CoreSchema.array(fields["routineInputs"]), bases = try CoreSchema.array(fields["baseRoutineRevisions"]), choices = try CoreSchema.array(fields["speciesChoices"])
        try require(mode == "add" ? bases.isEmpty && choices.isEmpty : routines.isEmpty,"FIELD_INVALID")
        for value in routines {
            let r = try CoreSchema.object(value)
            try require(Set(r.keys) == Set(["kind","count","unit","seed"]) && ["water","fertilize","mist","repot","rotate"].contains(r["kind"]?.text ?? "") && r["count"]?.units != nil && ["day","week","month","year"].contains(r["unit"]?.text ?? ""),"FIELD_INVALID")
            if r["seed"]?.isNull == true { continue }
            let seed = try CoreSchema.object(r["seed"]), kind = seed["kind"]?.text
            try require(kind == "known" || kind == "unknown","FIELD_INVALID")
            let key = kind == "known" ? "careDate" : "firstCheckDate"
            try require(Set(seed.keys) == Set(["kind",key]) && seed[key]?.units != nil,"FIELD_INVALID")
        }
        var baseIDs: [String] = [], choiceIDs: [String] = []
        for value in bases {
            let b = try CoreSchema.object(value), id = try CoreSchema.string(b["routineId"]), revision = try CoreSchema.number(b["revision"])
            try CoreSchema.uuid(id); try require(Set(b.keys) == Set(["routineId","revision"]) && revision >= 1 && revision <= CoreSchema.maxRevision,"FIELD_INVALID"); baseIDs.append(id)
        }
        for value in choices {
            let c = try CoreSchema.object(value), id = try CoreSchema.string(c["routineId"]); try CoreSchema.uuid(id)
            try require(Set(c.keys) == Set(["routineId","decision","interval"]) && c["decision"]?.text == "keep" && c["interval"]?.isNull == true,"FIELD_INVALID"); choiceIDs.append(id)
        }
        try require(baseIDs == baseIDs.sorted() && Set(baseIDs).count == baseIDs.count && choiceIDs == choiceIDs.sorted() && Set(choiceIDs).count == choiceIDs.count,"FIELD_INVALID")
    }
}
