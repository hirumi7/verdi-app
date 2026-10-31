import Foundation

struct CorePlan {
    let body: [String: CanonicalValue]
    let id: String
    let type: String
    let payload: [String: CanonicalValue]
    let payloadHash: String
    let hash: String
}
struct CoreDelta {
    let table: String
    let action: String
    let id: String
    let before: [SQLValue]?
    let values: [SQLValue]
    let raw: [CanonicalValue]
}

enum CoreRegistry {
    static let commands: Set<String> = ["SaveDraft","SavePlant","DiscardDraft","CompleteCurrent","BulkComplete","CheckNotNeeded","Snooze","Skip","SetInterval","ClearOverride","PauseRoutine","ResumeRoutine","RetireRoutine","AddPastCare","CorrectEvent","RestoreEvent","VoidEvent","ArchivePlant","RestorePlant","DeletePlant","Undo"]
    static let history: Set<String> = ["AddPastCare","CorrectEvent","RestoreEvent","VoidEvent"]
    static let schedule: Set<String> = ["Snooze","SetInterval","ClearOverride","PauseRoutine","ResumeRoutine","RetireRoutine"]
    static let eligibleUndo: Set<String> = ["CompleteCurrent","BulkComplete","CheckNotNeeded","Skip","Snooze"]
    static func needsPreview(_ type: String) -> Bool { !["SaveDraft","DiscardDraft","Undo"].contains(type) }
    static func require(_ condition: Bool, _ code: String = "PLAN_INVALID") throws { if !condition { throw CoreRepositoryError(code) } }
    static func parse(_ p: [String: CanonicalValue], session: String, dataset: String) throws -> CorePlan {
        try require(Set(p.keys) == Set(["sessionId","datasetId","commandId","commandType","normalisedPayload","payloadHash","expectedCollectionRevision","draftGuards","accessRevision","expectedToday","previewToken","effectsHash","planHash","statements","result","changeKind"]))
        let id = try CoreSchema.string(p["commandId"]), type = try CoreSchema.string(p["commandType"])
        try CoreSchema.uuid(id); try require(commands.contains(type))
        try require(p["sessionId"]?.text == session, "SESSION_INVALID"); try require(p["datasetId"]?.text == dataset, "DATASET_CHANGED")
        let payload = try CoreSchema.object(p["normalisedPayload"]), payloadHash = try CoreSchema.string(p["payloadHash"])
        try require(try CanonicalCommand.commandHash(type:type,payload:payload) == payloadHash)
        var hashed = p; hashed.removeValue(forKey:"planHash"); hashed.removeValue(forKey:"previewToken")
        let hash = try CanonicalCommand.hash(.object(hashed)); try require(p["planHash"]?.text == hash)
        try validatePayload(type,payload)
        let statements = try CoreSchema.array(p["statements"]); try require(statements.count <= 10000, "PLAN_LIMIT")
        try require(p["changeKind"]?.text == (["SaveDraft","DiscardDraft"].contains(type) ? "draft" : "collection"))
        try require(needsPreview(type) ? p["effectsHash"]?.text?.count == 64 : p["effectsHash"]?.isNull == true)
        return CorePlan(body:p,id:id,type:type,payload:payload,payloadHash:payloadHash,hash:hash)
    }
    static func validate(_ sql: SQLiteSession, _ p: CorePlan, clock: CoreClockFrame, grants: [String:CoreUndoGrant], elapsed: TimeInterval) throws -> [CoreDelta] {
        guard let frozenRow = try sql.query("SELECT hash,body,status FROM intents WHERE id=?", [.text(p.id)]).first else { throw CoreRepositoryError("NOT_FOUND") }
        try require(frozenRow[0] == .text(p.payloadHash), "COMMAND_ID_REUSED"); try require(frozenRow[2] == .text("pending"), "NOT_ELIGIBLE")
        let frozen = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(frozenRow[1])))
        try require(frozen["commandType"]?.text == p.type && (try CoreSchema.same(frozen["normalisedPayload"],.object(p.payload))))
        let allocated = try CoreSchema.array(frozen["allocatedIds"]).map { try CoreSchema.string($0) }
        let metadata = try sql.query("SELECT collection_revision FROM metadata")[0]
        try require(try CoreSchema.integer(metadata[0]) == CoreSchema.number(p.body["expectedCollectionRevision"]), "PREVIEW_STALE")
        let draftOnly = ["SaveDraft","DiscardDraft"].contains(p.type)
        try require(draftOnly ? p.body["expectedToday"]?.isNull == true : p.body["expectedToday"]?.text == clock.today, "PREVIEW_STALE")
        let guards = try CoreSchema.array(p.body["draftGuards"])
        var draftIDs: Set<String> = []
        for value in guards {
            let g = try CoreSchema.object(value), id = try CoreSchema.string(g["draftId"]); try CoreSchema.uuid(id)
            try require(Set(g.keys) == Set(["draftId","revision"]) && draftIDs.insert(id).inserted)
            let row = try CoreSchema.row(sql,"plant_drafts",id)
            try require(try CoreSchema.same(g["revision"],row.map { CoreSchema.canonical($0[1]) } ?? .null), "STALE_TARGET")
        }
        let statements = try CoreSchema.array(p.body["statements"])
        var changes: [CoreDelta] = []; var changed: Set<String> = []; var inserted: Set<String> = []
        for value in statements {
            let statement = try CoreSchema.object(value), key = try CoreSchema.string(statement["key"])
            try require(Set(statement.keys) == Set(["key","beforeHash","values"]))
            let parts = key.split(separator:".").map(String.init); try require(parts.count == 2)
            let table = parts[0], action = parts[1], raw = try CoreSchema.array(statement["values"])
            try require(CoreSchema.tables.contains(table) && ["insert","update","delete","deleteTree"].contains(action))
            let id = try CoreSchema.string(raw.first); try CoreSchema.uuid(id); try require(changed.insert(table+":"+id).inserted)
            let before = try CoreSchema.row(sql,table,id)
            if action == "insert" { try require(before == nil && statement["beforeHash"]?.isNull == true, "STALE_TARGET") }
            else { try require(before != nil, "STALE_TARGET"); try require(try CoreSchema.rowHash(before!) == CoreSchema.string(statement["beforeHash"]), "STALE_TARGET") }
            if action == "deleteTree" {
                try require(table == "plants" && p.type == "DeletePlant" && raw.count == 10)
                changes.append(CoreDelta(table:table,action:action,id:id,before:before,values:[],raw:raw)); continue
            }
            if action == "delete" {
                try require(((table == "plant_drafts" && ["SavePlant","DiscardDraft"].contains(p.type)) || (table == "plant_catalog" && p.type == "SavePlant")) && raw.count == 1)
                changes.append(CoreDelta(table:table,action:action,id:id,before:before,values:[],raw:raw)); continue
            }
            try require(raw.count == CoreSchema.columns[table]!.count)
            var values: [SQLValue] = []
            for (i, value) in raw.enumerated() {
                let native = value.object?["native"]?.text
                let recording = CoreSchema.instantColumns[table]?.contains(i) == true
                let needsInstant = recording && (before == nil || (table == "plants" && i == 10) || (table == "routines" && i == 12) || (table == "plant_drafts" && i == 7))
                if needsInstant { try require(native == "transaction_instant" && value.object?.count == 1); values.append(.text(clock.instant)); continue }
                if before == nil && ((table == "care_events" && i == 9) || (table == "routine_changes" && i == 7)) {
                    try require(native == "transaction_zone" && value.object?.count == 1); values.append(.text(clock.zone)); continue
                }
                if before == nil && ((table == "routine_changes" && i == 5) || (table == "care_events" && i == 6 && p.type == "Skip")) {
                    try require(native == "transaction_local_date" && value.object?.count == 1); values.append(.text(clock.today)); continue
                }
                try require(native == nil && value.object == nil)
                let scalar = try CoreSchema.scalar(value)
                if scalar == .null { try require(CoreSchema.nullableColumns[table]?.contains(i) == true) }
                else if CoreSchema.integerColumns[table]?.contains(i) == true { _ = try CoreSchema.integer(scalar) }
                else { _ = try CoreSchema.text(scalar) }
                values.append(scalar)
            }
            if let before {
                guard let mutable = CoreSchema.mutable[table] else { throw CoreRepositoryError("PLAN_INVALID") }
                for i in values.indices where !mutable.contains(i) { try require(values[i] == before[i]) }
                if let revision = CoreSchema.revisions[table] { try require(try CoreSchema.integer(values[revision]) == CoreSchema.integer(before[revision]) + 1) }
            } else {
                if !CoreSchema.linkedTables.contains(table) {try require(inserted.insert(id).inserted)}
                if table == "plant_drafts" {
                    let reservation = try sql.query("SELECT kind,used FROM reservations WHERE id=?", [.text(id)])
                    try require(reservation.count == 1 && reservation[0][0] == .text("draft") && reservation[0][1] == .integer(0), "NOT_ELIGIBLE")
                } else if !CoreSchema.linkedTables.contains(table) { try require(allocated.contains(id)); if let revision = CoreSchema.revisions[table] { try require(values[revision] == .integer(1)) } }
            }
            changes.append(CoreDelta(table:table,action:action,id:id,before:before,values:values,raw:raw))
        }
        try require(inserted.subtracting(changes.filter{$0.table == "plant_drafts"}.map(\.id)) == Set(allocated))
        try commandScope(sql,p,changes,allocated:allocated,guards:guards,clock:clock,grants:grants,elapsed:elapsed)
        return changes
    }
    static func requiredRow(_ sql: SQLiteSession, _ table: String, _ id: String) throws -> [SQLValue] {
        guard let row = try CoreSchema.row(sql,table,id) else { throw CoreRepositoryError("NOT_FOUND") }; return row
    }
    static func target(_ sql: SQLiteSession, _ value: CanonicalValue) throws -> ([SQLValue],[SQLValue],[SQLValue]) {
        let t = try CoreSchema.object(value)
        let plant = try requiredRow(sql,"plants",CoreSchema.string(t["plantId"])), routine = try requiredRow(sql,"routines",CoreSchema.string(t["routineId"])), head = try requiredRow(sql,"heads",CoreSchema.string(t["headId"]))
        try require(routine[1] == plant[0] && head[1] == routine[0])
        try require(plant[1] == .integer(try CoreSchema.number(t["plantRevision"])) && routine[2] == .integer(try CoreSchema.number(t["routineRevision"])) && head[2] == .integer(try CoreSchema.number(t["headRevision"])), "STALE_TARGET")
        return (plant,routine,head)
    }
    static func commandScope(_ sql: SQLiteSession, _ p: CorePlan, _ d: [CoreDelta], allocated: [String], guards: [CanonicalValue], clock: CoreClockFrame, grants: [String:CoreUndoGrant], elapsed: TimeInterval) throws {
        func of(_ table: String, _ action: String? = nil) -> [CoreDelta] { d.filter { $0.table == table && (action == nil || $0.action == action) } }
        func only(_ tables: Set<String>) throws { try require(d.allSatisfy { tables.contains($0.table) }) }
        func guardDraft(_ id: String, _ revision: CanonicalValue?) throws {
            try require(guards.count == 1 && guards[0].object?["draftId"]?.text == id && (try CoreSchema.same(guards[0].object?["revision"],revision)))
        }
        var requiresAccess = p.type == "RestorePlant"
        if p.type == "SaveDraft" {
            try only(["plant_drafts"]); try require(d.count == 1 && d[0].action != "delete")
            let id = try CoreSchema.string(p.payload["draftId"]); try require(d[0].id == id); try guardDraft(id,p.payload["expectedRevision"])
            let v = d[0].values
            try require(v[2] == .text(try CoreSchema.string(p.payload["mode"])) && v[3] == CoreSchema.scalar(p.payload["plantId"]!) && v[4] == CoreSchema.scalar(p.payload["basePlantRevision"]!))
            let envelope = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(v[5])))
            try require(envelope["version"]?.integer == 1 && envelope.count == 2 && (try CoreSchema.same(envelope["fields"],p.payload["rawFields"])))
            if v[2] == .text("edit") { _ = try requiredRow(sql,"plants",CoreSchema.text(v[3])) }
            try require(allocated.isEmpty)
        } else if p.type == "DiscardDraft" {
            try require(d.count == 1 && d[0].table == "plant_drafts" && d[0].action == "delete" && p.payload["confirmed"]?.json() == "true")
            try require(d[0].id == CoreSchema.string(p.payload["draftId"])); try guardDraft(d[0].id,p.payload["draftRevision"])
        } else if p.type == "SavePlant" {
            let draftID = try CoreSchema.string(p.payload["draftId"]); try guardDraft(draftID,p.payload["draftRevision"])
            let draft = try requiredRow(sql,"plant_drafts",draftID), adding = draft[2] == .text("add")
            requiresAccess = adding
            try only(["plants","routines","heads","care_events","plant_drafts","plant_catalog","suggestion_snapshots","routine_suggestions","routine_changes"])
            try require(of("plant_drafts").count == 1 && of("plant_drafts")[0].action == "delete" && of("plant_drafts")[0].id == draftID)
            try require(of("plants").count == 1)
            let plant = of("plants")[0], fields = try CoreSchema.object(CoreSchema.object(CanonicalParser.parse(CoreSchema.text(draft[5])))["fields"])
            let selection=try validateCatalogSelection(sql,plant:plant,fields:fields,changes:of("plant_catalog"))
            try require(plant.values[2] == .text(try validatedText(fields["name"],max:60,required:true)) && plant.values[3] == .text(try validatedText(fields["location"],max:40)) && plant.values[4] == .text(try validatedText(fields["notes"],max:2000,trim:false)))
            if let selection {
                try require(plant.values[5] == .text(try CoreSchema.string(selection.object?["speciesNameSnapshot"])) && plant.values[6] == .text("unknown") && plant.values[7] == .text("unknown"))
            } else {
                try require(plant.values[5] == .text(try validatedText(fields["customSpeciesName"],max:120,required:true)))
                let light=try CoreSchema.string(fields["customLight"]),toxicity=try CoreSchema.string(fields["customToxicity"])
                try require(plant.values[6] == .text(light == "bright-indirect" ? "brightIndirect":light) && plant.values[7] == .text(toxicity == "non-toxic" ? "nonToxic":toxicity))
            }
            if adding {
                let inputs = try CoreSchema.array(fields["routineInputs"])
                try require(inputs.count <= 5 && plant.action == "insert" && plant.id == allocated.first && plant.values[8] == .integer(0))
                try require(of("routines").count == inputs.count && of("heads").count == inputs.count)
                var slot = 1, kinds: Set<String> = [], seedEvents = 0, snapshotCount = 0
                for input in inputs {
                    let raw = try CoreSchema.object(input), seed = try CoreSchema.object(raw["seed"]), kind = try CoreSchema.string(raw["kind"])
                    try require(kinds.insert(kind).inserted && slot + 1 < allocated.count)
                    let r = of("routines").first { $0.id == allocated[slot] }, h = of("heads").first { $0.id == allocated[slot+1] }; slot += 2
                    guard let r, let h else { throw CoreRepositoryError("PLAN_INVALID") }
                    try require(r.action == "insert" && h.action == "insert" && r.values[1] == plant.values[0] && h.values[1] == r.values[0] && r.values[3] == .text(kind))
                    try require(r.values[6] == .integer(Int64(try CoreSchema.string(raw["count"])) ?? -1) && r.values[7] == .text(try CoreSchema.string(raw["unit"])) && r.values[5] == .text("active"))
                    if seed["kind"]?.text == "known" {
                        try require(slot < allocated.count)
                        guard let event = of("care_events").first(where:{$0.id == allocated[slot]}) else { throw CoreRepositoryError("PLAN_INVALID") }
                        slot += 1; seedEvents += 1
                        try validateNewEvent(event,routine:r.values,command:p,date:CoreSchema.string(seed["careDate"]),outcome:"actual_care",clock:clock)
                    } else {
                        try require(seed["kind"]?.text == "unknown" && r.values[9] == .integer(1) && r.values[10] == .text(try CoreSchema.string(seed["firstCheckDate"])) && h.values[3] == r.values[10])
                    }
                    if let suggestion=selection?.object?["suggestions"]?.array?.first(where:{$0.object?["careKind"]?.text==kind}) {
                        try require(slot<allocated.count)
                        try validateSuggestion(d, snapshotID:allocated[slot], routine:r.values, plant:plant.id, fields:fields, suggestion:suggestion, original:nil, adding:true)
                        slot += 1;snapshotCount += 1
                    }
                }
                try require(slot == allocated.count && of("care_events").count == seedEvents && of("suggestion_snapshots").count==snapshotCount && of("routine_suggestions").count==snapshotCount && of("routine_changes").isEmpty)
            } else {
                try require(plant.action == "update" && plant.values[0] == draft[3] && plant.before?[1] == draft[4] && plant.values[8] == plant.before?[8])
                let routines = try sql.query("SELECT id,revision FROM routines WHERE plant_id=? AND state!='retired' ORDER BY id", [plant.values[0]])
                let bases: CanonicalValue = .array(routines.map { .object(["routineId":CoreSchema.canonical($0[0]),"revision":CoreSchema.canonical($0[1])]) })
                try require(try CoreSchema.same(fields["baseRoutineRevisions"],bases), "DRAFT_CONFLICT")
                let oldCatalog=try CoreSchema.row(sql,"plant_catalog",plant.id)
                let sameSelection = try CoreSchema.same(selection,oldCatalog.map {try CanonicalParser.parse(CoreSchema.text($0[3]))})
                let changed = [5,6,7].contains { plant.values[$0] != plant.before![$0] } || !sameSelection || oldCatalog?[1].stringValue != fields["speciesId"]?.text
                let choices=try CoreSchema.array(fields["speciesChoices"])
                try require(choices.compactMap{$0.object?["routineId"]?.text} == (changed ? routines.compactMap{$0[0].stringValue}:[]))
                var slot=0, applied=0
                for c in choices {
                    let choice=try CoreSchema.object(c), id=try CoreSchema.string(choice["routineId"])
                    if choice["decision"]?.text == "keep" {try require(!of("routines").contains{$0.id==id} && !of("heads").contains{$0.values[1] == .text(id)});continue}
                    let old=try requiredRow(sql,"routines",id)
                    guard let r=of("routines").first(where:{$0.id==id}),let suggestion=selection?.object?["suggestions"]?.array?.first(where:{$0.object?["careKind"]?.text == old[3].stringValue}) else {throw CoreRepositoryError("PLAN_INVALID")}
                    let oldHead=try sql.query("SELECT id, routine_id, revision, next_check, override_date FROM heads WHERE routine_id=?",[.text(id)])[0]
                    let head=of("heads").first{$0.values[1] == .text(id)}, interval=try CoreSchema.object(choice["interval"])
                    try require(r.action == "update" && r.values[6] == .integer(try CoreSchema.number(interval["count"])) && r.values[7] == .text(try CoreSchema.string(interval["unit"])))
                    for i in [0,1,3,4,5,11] {try require(r.values[i]==old[i])}
                    try intervalTransition(r,head:head,storedHead:oldHead,interval:interval)
                    try require(slot+1<allocated.count)
                    let oldLink=try CoreSchema.row(sql,"routine_suggestions",id)
                    try validateSuggestion(d,snapshotID:allocated[slot],routine:r.values,plant:plant.id,fields:fields,suggestion:suggestion,original:oldLink?[1],adding:false)
                    guard let audit=of("routine_changes").first(where:{$0.id==allocated[slot+1]}),let link=of("routine_suggestions").first(where:{$0.id==id}) else {throw CoreRepositoryError("PLAN_INVALID")}
                    try validateAudit(sql,audit,routine:r,head:head,command:p,kind:"speciesApply",beforeArchived:plant.values[8] == .integer(1),afterArchived:plant.values[8] == .integer(1),storedHead:oldHead,afterSuggestions:link.values)
                    slot += 2;applied += 1
                }
                try require(slot==allocated.count && of("routines").count==applied && of("routine_changes").count==applied && of("suggestion_snapshots").count==applied && of("routine_suggestions").count==applied && of("care_events").isEmpty)
                try require(of("heads").allSatisfy{h in of("routines").contains{$0.id==h.values[1].stringValue}})
            }
        } else if ["ArchivePlant","RestorePlant","DeletePlant"].contains(p.type) {
            let plantID = try CoreSchema.string(p.payload["plantId"]), plant = try requiredRow(sql,"plants",plantID)
            try require(plant[1] == .integer(try CoreSchema.number(p.payload["plantRevision"])), "STALE_TARGET")
            if p.type == "DeletePlant" {
                try require(d.count == 1 && d[0].action == "deleteTree" && d[0].id == plantID && plant[8] == .integer(1))
                try deleteGuards(sql,p,d[0],guards)
            } else {
                try require(guards.isEmpty); try only(["plants","routines","heads","routine_changes"])
                let restoring = p.type == "RestorePlant"
                try require(plant[8] == .integer(restoring ? 1 : 0), "NOT_ELIGIBLE")
                try require(of("plants").count == 1 && of("plants")[0].id == plantID && of("plants")[0].values[8] == .integer(restoring ? 0 : 1))
                for i in 2...7 { try require(of("plants")[0].values[i] == plant[i]) }
                let routines = try sql.query("SELECT id FROM routines WHERE plant_id=? ORDER BY id", [.text(plantID)]).map { try CoreSchema.text($0[0]) }
                try require(of("routines").count == routines.count && of("heads").count == routines.count && of("routine_changes").count == routines.count && allocated.count == routines.count)
                for (index,id) in routines.enumerated() {
                    guard let r = of("routines").first(where:{$0.id == id}), let h = of("heads").first(where:{$0.values[1] == .text(id)}), let audit = of("routine_changes").first(where:{$0.id == allocated[index]}) else { throw CoreRepositoryError("PLAN_INVALID") }
                    for i in 5...10 { try require(r.values[i] == r.before![i]) }
                    try validateAudit(sql,audit,routine:r,head:h,command:p,kind:restoring ? "restore" : "archive",beforeArchived:restoring,afterArchived:restoring ? false : true)
                }
            }
        } else if p.type == "Undo" {
            try require(guards.isEmpty); try only(["routines","heads","care_events","event_corrections","routine_changes"])
            let original = try CoreSchema.string(p.payload["originalCommandId"])
            guard let grant = grants[original], let started = grant.started else { throw CoreRepositoryError("UNDO_UNAVAILABLE") }
            try require(elapsed >= started && elapsed - started < 8,"UNDO_EXPIRED")
            let receipt = try sql.query("SELECT undone FROM receipts WHERE id=?", [.text(original)])
            try require(receipt.count == 1 && receipt[0][0] == .integer(0),"UNDO_UNAVAILABLE")
            try checkUndoMembers(sql,grant.context)
            let members = try CoreSchema.array(CoreSchema.object(grant.context)["members"])
            try require(of("routines").count == members.count && of("routine_changes").count == members.count)
            var slot = 0, expectedEvents: Set<String> = [], expectedHeads: Set<String> = []
            for member in members {
                let m = try CoreSchema.object(member), before = try CoreSchema.array(m["routine"]).map(CoreSchema.scalar), oldHead = try CoreSchema.array(m["head"]).map(CoreSchema.scalar)
                guard let r = of("routines").first(where:{$0.values[0] == before[0]}) else { throw CoreRepositoryError("PLAN_INVALID") }
                for i in 5...10 { try require(r.values[i] == before[i]) }
                let h = of("heads").first(where:{$0.values[1] == before[0]})
                let currentHead = try requiredRow(sql,"heads",CoreSchema.text(oldHead[0]))
                let nextHead = h?.values ?? currentHead
                for i in 3...4 { try require(nextHead[i] == oldHead[i]) }
                if let h { expectedHeads.insert(h.id) }
                for event in try CoreSchema.array(m["events"]) {
                    let eventID = try CoreSchema.string(event); expectedEvents.insert(eventID)
                    try require(slot < allocated.count)
                    guard let c = of("event_corrections").first(where:{$0.id == allocated[slot]}) else { throw CoreRepositoryError("PLAN_INVALID") }
                    slot += 1
                    try correction(sql,c,command:p,routineID:CoreSchema.text(before[0]),eventID:eventID,voiding:true,restoring:false,reason:"undo",clock:clock)
                    let e = try requiredRow(sql,"care_events",eventID); try require(e[10] == .text(original))
                }
                try require(slot < allocated.count)
                guard let audit = of("routine_changes").first(where:{$0.id == allocated[slot]}) else { throw CoreRepositoryError("PLAN_INVALID") }; slot += 1
                try validateAudit(sql,audit,routine:r,head:h,command:p,kind:"undo",beforeArchived:false,afterArchived:false,storedHead:currentHead)
            }
            try require(slot == allocated.count && Set(of("care_events").map(\.id)) == expectedEvents && of("event_corrections").count == expectedEvents.count && Set(of("heads").map(\.id)) == expectedHeads)
        } else {
            try require(guards.isEmpty); try only(["routines","heads","care_events","event_corrections","routine_changes"])
            let targets = p.type == "BulkComplete" ? try CoreSchema.array(p.payload["targets"]) : [p.payload["target"] ?? .null]
            try require(!targets.isEmpty && targets.count <= 200 && of("routines").count == targets.count)
            var seen: Set<String> = [], expectedEvents = 0, expectedCorrections = 0, expectedAudits = 0, expectedHeads: Set<String> = []
            for (index,t) in targets.enumerated() {
                let (plant,old,head) = try target(sql,t), id = try CoreSchema.text(old[0])
                try require(seen.insert(id).inserted)
                guard let r = of("routines").first(where:{$0.id == id}) else { throw CoreRepositoryError("PLAN_INVALID") }
                let h = of("heads").first(where:{$0.values[1] == old[0]})
                if let h { try require(h.id == CoreSchema.text(head[0])); expectedHeads.insert(h.id) }
                try require(allocated.count == targets.count)
                let allocatedID = allocated[index]
                if history.contains(p.type) {
                    try require(h == nil); for i in 5...10 { try require(r.values[i] == old[i]) }
                } else if ["CompleteCurrent","BulkComplete","CheckNotNeeded","Snooze","Skip","PauseRoutine"].contains(p.type) {
                    try require(plant[8] == .integer(0) && old[5] == .text("active"), "NOT_ELIGIBLE")
                } else if p.type == "ResumeRoutine" { try require(plant[8] == .integer(0) && old[5] == .text("paused"), "NOT_ELIGIBLE") }
                else { try require(old[5] != .text("retired"), "NOT_ELIGIBLE") }
                try transition(p, routine:r, head:h, storedHead:head, clock:clock)
                if p.type == "BulkComplete" { try require(old[3] == .text(try CoreSchema.string(p.payload["careKind"]))) }
                if schedule.contains(p.type) {
                    expectedAudits += 1
                    guard let audit = of("routine_changes").first(where:{$0.id == allocatedID}) else { throw CoreRepositoryError("PLAN_INVALID") }
                    let kind = ["SetInterval":"interval","PauseRoutine":"pause","ResumeRoutine":"resume","RetireRoutine":"retire"][p.type] ?? "override"
                    try validateAudit(sql,audit,routine:r,head:h,command:p,kind:kind,beforeArchived:plant[8] == .integer(1),afterArchived:plant[8] == .integer(1),storedHead:head)
                } else if ["CorrectEvent","RestoreEvent","VoidEvent"].contains(p.type) {
                    expectedCorrections += 1
                    let eventID = try CoreSchema.string(p.payload["eventId"])
                    guard let c = of("event_corrections").first(where:{$0.id == allocatedID}), let e = of("care_events").first(where:{$0.id == eventID}) else { throw CoreRepositoryError("PLAN_INVALID") }
                    try require(e.action == "update" && e.before?[3] == .integer(try CoreSchema.number(p.payload["eventRevision"])),"STALE_TARGET")
                    try correction(sql,c,command:p,routineID:id,eventID:eventID,voiding:p.type == "VoidEvent",restoring:p.type == "RestoreEvent",reason:p.type == "VoidEvent" ? "void" : "correction",clock:clock)
                } else {
                    expectedEvents += 1
                    guard let e = of("care_events").first(where:{$0.id == allocatedID}) else { throw CoreRepositoryError("PLAN_INVALID") }
                    let date = p.type == "Skip" ? clock.today : try CoreSchema.string(p.payload[p.type == "CheckNotNeeded" ? "checkDate" : "careDate"])
                    let outcome = p.type == "Skip" ? "skipped" : p.type == "CheckNotNeeded" ? "checked_not_needed" : p.type == "AddPastCare" ? try CoreSchema.string(p.payload["outcome"]) : "actual_care"
                    try validateNewEvent(e,routine:old,command:p,date:date,outcome:outcome,clock:clock)
                }
            }
            try require(of("care_events").count == expectedEvents + expectedCorrections && of("event_corrections").count == expectedCorrections && of("routine_changes").count == expectedAudits && Set(of("heads").map(\.id)) == expectedHeads)
        }
        if requiresAccess {
            try require(p.body["accessRevision"]?.integer == 1,"PREVIEW_STALE")
            let count = try CoreSchema.integer(sql.query("SELECT count(*) FROM plants WHERE archived=0")[0][0])
            try require(count < 5,"ACTIVE_LIMIT")
        } else { try require(p.body["accessRevision"]?.isNull == true) }
    }
    // Native field-scope checks bind transitions to the immutable payload.
    // Calendar recurrence arithmetic remains in the single Dart planner.
    static func transition(_ p: CorePlan, routine r: CoreDelta, head: CoreDelta?, storedHead: [SQLValue], clock: CoreClockFrame) throws {
        let old = r.before!, nextHead = head?.values ?? storedHead
        let allowed: Set<Int>
        switch p.type {
        case "CompleteCurrent", "BulkComplete": allowed = [8,9]
        case "SetInterval": allowed = [6,7,8,9,10]
        case "ClearOverride": allowed = [8,9,10]
        case "PauseRoutine", "ResumeRoutine", "RetireRoutine": allowed = [5]
        default: allowed = []
        }
        for i in 5...10 where !allowed.contains(i) { try require(r.values[i] == old[i]) }
        for i in [3,4] { if nextHead[i] != .null { try validDate(CoreSchema.text(nextHead[i])) } }
        switch p.type {
        case "Snooze", "CheckNotNeeded":
            let date = try CoreSchema.string(p.payload["nextCheckDate"]); try validDate(date)
            try require(nextHead[3] == .text(date) && nextHead[4] == .text(date))
            if p.type == "Snooze" { try require(date >= clock.today) }
        case "Skip": try require(nextHead[4] == .null && CoreSchema.text(nextHead[3]) > clock.today)
        case "CompleteCurrent", "BulkComplete":
            try require(r.values[8] == .text(try CoreSchema.string(p.payload["careDate"])) && r.values[9] == .integer(0) && nextHead[4] == .null && CoreSchema.text(nextHead[3]) >= clock.today)
        case "PauseRoutine", "RetireRoutine":
            try require(r.values[5] == .text(p.type == "PauseRoutine" ? "paused" : "retired") && nextHead[3] == storedHead[3] && nextHead[4] == storedHead[4] && head != nil)
        case "ResumeRoutine":
            let date = max(try CoreSchema.text(storedHead[3]),clock.today)
            try require(r.values[5] == .text("active") && nextHead[3] == .text(date) && nextHead[4] == (storedHead[4] == .null ? .null : .text(date)) && head != nil)
        case "SetInterval":
            try intervalTransition(r,head:head,storedHead:storedHead,interval:CoreSchema.object(p.payload["interval"]))
        case "ClearOverride": try require(nextHead[4] == .null)
        default: break
        }
    }
    static func intervalTransition(_ r: CoreDelta, head: CoreDelta?, storedHead: [SQLValue], interval: [String:CanonicalValue]) throws {
        let old=r.before!, next=head?.values ?? storedHead
        try require(r.values[6] == .integer(try CoreSchema.number(interval["count"])) && r.values[7] == .text(try CoreSchema.string(interval["unit"])))
        for i in [3,4] {if next[i] != .null {try validDate(CoreSchema.text(next[i]))}}
        if storedHead[4] != .null {
            for i in 8...10 {try require(r.values[i]==old[i])}
            try require(head==nil)
        } else {try require(next[4] == .null)}
    }
    /// Pinned Dart String.trim White_Space plus BOM, verified over all BMP units.
    static func trimLikeDart(_ value: String) -> String {
        let whitespace: Set<UInt32> = [9,10,11,12,13,32,133,160,5760,8192,8193,8194,8195,8196,8197,8198,8199,8200,8201,8202,8232,8233,8239,8287,12288,65279]
        let scalars = Array(value.unicodeScalars)
        var first = 0, last = scalars.count
        while first < last && whitespace.contains(scalars[first].value) { first += 1 }
        while last > first && whitespace.contains(scalars[last-1].value) { last -= 1 }
        return String(String.UnicodeScalarView(scalars[first..<last]))
    }
    static func validateNewEvent(_ e: CoreDelta, routine: [SQLValue], command p: CorePlan, date: String, outcome: String, clock: CoreClockFrame) throws {
        try require(e.action == "insert" && e.values[1] == routine[1] && e.values[2] == routine[0] && e.values[4] == routine[3] && e.values[5] == routine[4] && e.values[6] == .text(date) && e.values[7] == .text(outcome) && e.values[10] == .text(p.id))
        try validDate(date); try require(date <= clock.today,"FUTURE_CARE_DATE")
    }
    static func validDate(_ value: String) throws {
        let f = DateFormatter(); f.calendar = Calendar(identifier:.gregorian); f.timeZone = TimeZone(secondsFromGMT:0)
        f.locale = Locale(identifier:"en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false
        guard value.count == 10, let date = f.date(from:value), f.string(from:date) == value else { throw CoreRepositoryError("FIELD_INVALID") }
    }
    static func correction(_ sql: SQLiteSession, _ c: CoreDelta, command p: CorePlan, routineID: String, eventID: String, voiding: Bool, restoring: Bool, reason: String, clock: CoreClockFrame) throws {
        let event = try requiredRow(sql,"care_events",eventID)
        try require(event[2] == .text(routineID))
        let last = try sql.query("SELECT after_date,after_outcome,after_voided FROM event_corrections WHERE event_id=? ORDER BY sequence DESC LIMIT 1", [.text(eventID)]).first
        let before = last ?? [event[6],event[7],.integer(0)]
        try require(c.action == "insert" && c.values[1] == .text(eventID) && c.values[2] == event[3] && Array(c.values[3...5]) == before && c.values[10] == .text(p.id) && c.values[11] == .text(reason))
        try require(before[2] == .integer(restoring ? 1 : 0),"NOT_ELIGIBLE")
        if voiding { try require(Array(c.values[6...8]) == [before[0],before[1],.integer(1)]) }
        else {
            let date = try CoreSchema.string(p.payload["careDate"]); try validDate(date); try require(date <= clock.today,"FUTURE_CARE_DATE")
            try require(c.values[6] == .text(date) && c.values[7] == .text(try CoreSchema.string(p.payload["outcome"])) && c.values[8] == .integer(0))
        }
    }
    static func headSnapshot(_ routine: [SQLValue], _ head: [SQLValue], archived: Bool, link: [SQLValue]? = nil) -> CanonicalValue {
        var value: [String:CanonicalValue] = ["version":.integer(1),"headId":CoreSchema.canonical(head[0]),"intervalCount":CoreSchema.canonical(routine[6]),"intervalUnit":CoreSchema.canonical(routine[7]),"anchor":CoreSchema.canonical(routine[8]),"firstCheckAnchor":.boolean(routine[9] == .integer(1)),"firstCheckDate":CoreSchema.canonical(routine[10]),"nextCheck":CoreSchema.canonical(head[3]),"overrideDate":CoreSchema.canonical(head[4]),"status":CoreSchema.canonical(routine[5]),"archived":.boolean(archived)]
        if let link {value["version"] = .integer(2);value["originalSuggestionId"] = CoreSchema.canonical(link[1]);value["appliedSuggestionId"] = CoreSchema.canonical(link[2])}
        return .object(value)
    }
    static func validateAudit(_ sql: SQLiteSession, _ audit: CoreDelta, routine r: CoreDelta, head: CoreDelta?, command p: CorePlan, kind: String, beforeArchived: Bool, afterArchived: Bool, storedHead: [SQLValue]? = nil, afterSuggestions: [SQLValue]? = nil) throws {
        guard let old = r.before, let oldHead = head?.before ?? storedHead else { throw CoreRepositoryError("PLAN_INVALID") }
        let nextHead = head?.values ?? oldHead
        try require(audit.action == "insert" && audit.values[1] == old[1] && audit.values[2] == old[0] && audit.values[3] == .text(p.id) && audit.values[4] == .text(kind))
        let link=try CoreSchema.row(sql,"routine_suggestions",r.id)
        try require(audit.values[8] == .text(try headSnapshot(old,oldHead,archived:beforeArchived,link:link).json()) && audit.values[9] == .text(try headSnapshot(r.values,nextHead,archived:afterArchived,link:afterSuggestions ?? link).json()))
    }
    static func checkUndoMembers(_ sql: SQLiteSession, _ context: CanonicalValue) throws {
        for member in try CoreSchema.array(CoreSchema.object(context)["members"]) {
            let m = try CoreSchema.object(member), post = try CoreSchema.array(m["postRoutine"]).map(CoreSchema.scalar), head = try CoreSchema.array(m["postHead"]).map(CoreSchema.scalar)
            let actual = try requiredRow(sql,"routines",CoreSchema.text(post[0])), actualHead = try requiredRow(sql,"heads",CoreSchema.text(head[0]))
            try require(actual[2] == post[2] && actualHead[2] == head[2],"UNDO_CHANGED")
        }
    }
    static func captureUndo(_ sql: SQLiteSession, _ p: CorePlan, _ changes: [CoreDelta]) throws -> CanonicalValue? {
        guard eligibleUndo.contains(p.type) else { return nil }
        let routines = changes.filter { $0.table == "routines" }.sorted { $0.id < $1.id }
        var members: [CanonicalValue] = []
        for r in routines {
            let headRow = try sql.query("SELECT id FROM heads WHERE routine_id=?", [.text(r.id)])[0]
            let head = try requiredRow(sql,"heads",CoreSchema.text(headRow[0]))
            let newHead = changes.first { $0.table == "heads" && $0.values[1] == .text(r.id) }?.values ?? head
            let events = changes.filter { $0.table == "care_events" && $0.action == "insert" && $0.values[2] == .text(r.id) }.map { CanonicalValue.string($0.id) }
            members.append(.object(["plantId":CoreSchema.canonical(r.values[1]),"routine":CoreSchema.vector(r.before!),"head":CoreSchema.vector(head),"postRoutine":CoreSchema.vector(r.values),"postHead":CoreSchema.vector(newHead),"events":.array(events)]))
        }
        return .object(["members":.array(members)])
    }
    static func ownedDrafts(_ sql: SQLiteSession, _ plant: String) throws -> CanonicalValue {
        .array(try sql.query("SELECT id,revision FROM plant_drafts WHERE plant_id=? ORDER BY id", [.text(plant)]).map { .object(["draftId":CoreSchema.canonical($0[0]),"revision":CoreSchema.canonical($0[1])]) })
    }
    static func deleteGuards(_ sql: SQLiteSession, _ p: CorePlan, _ d: CoreDelta, _ guards: [CanonicalValue]) throws {
        try require(d.raw[1].integer == CoreSchema.number(p.payload["plantRevision"]))
        let queries = ["SELECT count(*) FROM routines WHERE plant_id=?", "SELECT count(*) FROM care_events WHERE plant_id=?",
            "SELECT count(*) FROM event_corrections WHERE event_id IN (SELECT id FROM care_events WHERE plant_id=?)", "SELECT count(*) FROM routine_changes WHERE plant_id=?"]
        for (index,query) in queries.enumerated() {
            let count = try CoreSchema.integer(sql.query(query,[.text(d.id)])[0][0]); try require(d.raw[index+2].integer == count,"PREVIEW_STALE")
        }
        for (i,query) in ["SELECT count(*) FROM suggestion_snapshots WHERE plant_id=?","SELECT count(*) FROM plant_catalog WHERE id=?","SELECT count(*) FROM routine_suggestions WHERE id IN (SELECT id FROM routines WHERE plant_id=?)"].enumerated() {try require(d.raw[7+i].integer == CoreSchema.integer(sql.query(query,[.text(d.id)])[0][0]),"PREVIEW_STALE")}
        let drafts = try ownedDrafts(sql,d.id)
        try require(try CoreSchema.same(d.raw[6],drafts) && CoreSchema.same(.array(guards),drafts),"PREVIEW_STALE")
    }
    static func apply(_ sql: SQLiteSession, _ p: CorePlan, _ changes: [CoreDelta]) throws {
        for d in changes {
            if d.action == "deleteTree" { try deleteTree(sql,d.id,p.id); continue }
            if d.action == "delete" {
                try require(try sql.execute("DELETE FROM \(d.table) WHERE id=?", [.text(d.id)]) == 1,"STALE_TARGET"); continue
            }
            let columns = CoreSchema.columns[d.table]!
            let count: Int
            if d.action == "insert" {
                count = try sql.execute("INSERT INTO \(d.table)(\(columns.joined(separator:","))) VALUES(\(Array(repeating:"?",count:columns.count).joined(separator:",")))",d.values)
            } else {
                count = try sql.execute("UPDATE \(d.table) SET \(columns.dropFirst().map { "\($0)=?" }.joined(separator:",")) WHERE id=?",Array(d.values.dropFirst()) + [.text(d.id)])
            }
            try require(count == 1,"STALE_TARGET")
        }
        let missingHeads = try sql.query("SELECT r.id FROM routines r LEFT JOIN heads h ON h.routine_id=r.id WHERE h.id IS NULL LIMIT 1")
        try require(missingHeads.isEmpty)
        let badEvents = try sql.query("SELECT e.id FROM care_events e JOIN routines r ON r.id=e.routine_id WHERE e.plant_id!=r.plant_id OR e.care_kind!=r.care_kind OR e.care_label!=r.label LIMIT 1")
        try require(badEvents.isEmpty)
    }
    static func deleteTree(_ sql: SQLiteSession, _ plant: String, _ command: String) throws {
        var owned: Set<String> = [plant]
        for query in ["SELECT id FROM routines WHERE plant_id=?","SELECT id FROM care_events WHERE plant_id=?","SELECT id FROM plant_drafts WHERE plant_id=?"] {
            for row in try sql.query(query,[.text(plant)]) { owned.insert(try CoreSchema.text(row[0])) }
        }
        for row in try sql.query("SELECT result FROM receipts") {
            let result = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[0])))
            if result["primaryId"]?.text == plant { for id in try CoreSchema.array(result["resourceIds"]) { owned.insert(try CoreSchema.string(id)) } }
        }
        for row in try sql.query("SELECT id,body FROM intents WHERE status='pending' AND id!=?", [.text(command)]) {
            let body = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[1]))), payload = try CoreSchema.object(body["normalisedPayload"])
            let related = payload["plantId"]?.text == plant || payload["target"]?.object?["plantId"]?.text == plant || payload["draftId"]?.text.map(owned.contains) == true || payload["targets"]?.array?.contains(where:{$0.object?["plantId"]?.text == plant}) == true
            if related { try sql.execute("UPDATE intents SET body=NULL,status='abandoned' WHERE id=?", [row[0]]) }
        }
        for row in try sql.query("SELECT id,undo_context FROM receipts WHERE undo_context IS NOT NULL") {
            let context = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(row[1])))
            if context["members"]?.array?.contains(where:{$0.object?["plantId"]?.text == plant}) == true {
                try sql.execute("UPDATE receipts SET undo_context=NULL WHERE id=?", [row[0]])
                for pending in try sql.query("SELECT id,body FROM intents WHERE type='Undo' AND status='pending'") {
                    let frozen = try CoreSchema.object(CanonicalParser.parse(CoreSchema.text(pending[1])))
                    if frozen["normalisedPayload"]?.object?["originalCommandId"]?.text == (try CoreSchema.text(row[0])) {
                        try sql.execute("UPDATE intents SET body=NULL,status='abandoned' WHERE id=?", [pending[0]])
                    }
                }
            }
        }
        for query in [
            "DELETE FROM routine_suggestions WHERE id IN (SELECT id FROM routines WHERE plant_id=?)",
            "DELETE FROM suggestion_snapshots WHERE plant_id=?", "DELETE FROM plant_catalog WHERE id=?",
            "DELETE FROM event_corrections WHERE event_id IN (SELECT id FROM care_events WHERE plant_id=?)",
            "DELETE FROM care_events WHERE plant_id=?", "DELETE FROM routine_changes WHERE plant_id=?",
            "DELETE FROM heads WHERE routine_id IN (SELECT id FROM routines WHERE plant_id=?)",
            "DELETE FROM routines WHERE plant_id=?", "DELETE FROM plant_drafts WHERE plant_id=?",
            "DELETE FROM plants WHERE id=?",
        ] { try sql.execute(query,[.text(plant)]) }
    }
    static func validateResult(_ sql: SQLiteSession, _ p: CorePlan, _ d: [CoreDelta]) throws {
        let result = try CoreSchema.object(p.body["result"])
        try require(Set(result.keys) == Set(["commandId","datasetId","collectionRevision","primaryId","primaryType","replayed","resourceIds","newRevisions","notices"]))
        let meta = try sql.query("SELECT dataset_id,collection_revision FROM metadata")[0]
        try require(result["commandId"]?.text == p.id && result["datasetId"]?.text == CoreSchema.text(meta[0]) && result["collectionRevision"]?.integer == CoreSchema.integer(meta[1]) && result["replayed"]?.json() == "false")
        var revisions: [String:CanonicalValue] = [:]; var resources = Set(d.map(\.id))
        for delta in d where delta.action != "delete" && delta.action != "deleteTree" {
            if let index = CoreSchema.revisions[delta.table] { revisions[delta.id] = CoreSchema.canonical(delta.values[index]) }
        }
        if p.type == "Undo" || p.type == "BulkComplete" || p.type == "SavePlant" {
            for r in d where r.table == "routines" {
                let head = try sql.query("SELECT id,revision FROM heads WHERE routine_id=?", [.text(r.id)])[0]
                let id = try CoreSchema.text(head[0]); revisions[id] = CoreSchema.canonical(head[1]); resources.insert(id)
            }
        }
        try require(try CoreSchema.same(result["newRevisions"],.object(revisions)))
        try require(try CoreSchema.array(result["resourceIds"]).map { try CoreSchema.string($0) } == resources.sorted())
        let primary: CanonicalValue, primaryType: CanonicalValue
        if p.type == "Undo" || p.type == "BulkComplete" { primary = .null; primaryType = .null }
        else if ["SaveDraft","DiscardDraft"].contains(p.type) { primary = p.payload["draftId"]!; primaryType = .string("draft") }
        else if p.type == "SavePlant" { primary = .string(d.first{$0.table == "plants"}!.id); primaryType = .string("plant") }
        else if ["ArchivePlant","RestorePlant","DeletePlant"].contains(p.type) { primary = p.payload["plantId"]!; primaryType = .string("plant") }
        else if ["CorrectEvent","RestoreEvent","VoidEvent"].contains(p.type) { primary = p.payload["eventId"]!; primaryType = .string("event") }
        else if p.type == "AddPastCare" { primary = .string(d.first{$0.table == "care_events"}!.id); primaryType = .string("event") }
        else { primary = p.payload["target"]!.object!["routineId"]!; primaryType = .string("routine") }
        try require(try CoreSchema.same(result["primaryId"],primary) && CoreSchema.same(result["primaryType"],primaryType))
        try require(try CoreSchema.same(result["notices"],.array(history.contains(p.type) ? [.string("HISTORY_CHANGED_CHECK_UNCHANGED")] : [])))
    }
}
