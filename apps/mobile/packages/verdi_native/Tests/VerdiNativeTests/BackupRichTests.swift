import Foundation
import XCTest
@testable import VerdiNative

extension CoreRepositoryTests {
    func testBackupRichCollectionDraftsMediaSettingsRoundTrip() throws {
        defer{removeBackupSidecars()}
        for i in 0..<19 {try execute(i)}
        let time=mediaInstant(),plant=try CoreSchema.text(allRows("plants")[0][0])
        let raw=steps[0]["intent"]!.object!["normalisedPayload"]!.object!["rawFields"]!
        func plantDraft() throws -> String {
            let id=UUID().uuidString.lowercased(),fields=try CanonicalValue.object(["version":.integer(1),"fields":raw]).json()
            _=try repo.queue.sync {try repo.database!.transaction {try $0.execute("INSERT INTO plant_drafts VALUES(?,1,'add',NULL,NULL,?,?,?)",[.text(id),.text(fields),.text(time),.text(time)])}}
            return id
        }
        func photo(_ draft:String) throws -> [SQLValue] {
            let source=try XCTUnwrap(Bundle.module.url(forResource:"generic",withExtension:"png",subdirectory:"Fixtures/catalog")),selection=try repo.retainMediaSelection(source:source,kind:"library"),id=UUID().uuidString.lowercased()
            _=try call("preparePhoto",["datasetId":.string(dataset),"draftId":.string(draft),"draftRevision":.integer(1),"preparationId":.string(id),"selectionId":.string(selection),"observedDate":.string("2026-10-20")])
            repo.mediaWorker.sync{}
            XCTAssertEqual(try call("photoPreparation",["preparationId":.string(id)]).object?["kind"]?.text,"ready")
            return try XCTUnwrap(allRows("photos").first{$0[2] == .text(draft)})
        }
        let sourceDraft=try plantDraft(),cover=try photo(sourceDraft),coverID=try CoreSchema.text(cover[0]),journalID=UUID().uuidString.lowercased(),mediaDraft=UUID().uuidString.lowercased()
        var settings=BackupSettings.defaults.object!;settings["theme"] = .string("dark");settings["localeOverride"] = .string("en-GB")
        try repo.queue.sync {try repo.database!.transaction {sql in
            try sql.execute("UPDATE photos SET plant_id=?,draft_id=NULL WHERE id=?",[.text(plant),cover[0]])
            try repo.tombstonePreparation(sql,photo:coverID,state:"consumed")
            try sql.execute("DELETE FROM plant_drafts WHERE id=?",[.text(sourceDraft)])
            try sql.execute("INSERT INTO plant_covers VALUES(?,?)",[.text(plant),cover[0]])
            try sql.execute("INSERT INTO journal_entries VALUES(?,?,1,'2026-10-20','New frond',?,?,?)",[.text(journalID),.text(plant),.text(try CanonicalValue.array([.string(coverID)]).json()),.text(time),.text(time)])
            let journalFields=try CanonicalValue.object(["entryDate":.utf16([0xd800]),"text":.string("Unfinished journal"),"selectedPhotoIds":.array([])]).json()
            try sql.execute("INSERT INTO journal_drafts VALUES(?,1,?,NULL,NULL,?,'[]',?,?)",[.text(UUID().uuidString.lowercased()),.text(plant),.text(journalFields),.text(time),.text(time)])
            try sql.execute("INSERT INTO media_drafts VALUES(?,1,?,?,1,'[]',?,?)",[.text(mediaDraft),.text(plant),cover[0],.text(time),.text(time)])
            let original=try sql.query("SELECT * FROM plants WHERE id=?",[.text(plant)])[0]
            for i in 0..<6 {
                var clone=original;clone[0] = .text(UUID().uuidString.lowercased());clone[2] = .text("Backup QA plant \(i)");clone[8] = .integer(i==5 ? 1:0)
                try sql.execute("INSERT INTO plants VALUES(?,?,?,?,?,?,?,?,?,?,?)",clone)
            }
            try sql.execute("UPDATE user_settings SET payload_json=?",[.text(try CanonicalValue.object(settings).json())])
        }}
        _=try photo(mediaDraft);_=try photo(plantDraft())
        let before=try Dictionary(uniqueKeysWithValues:CoreSchema.tables.map{($0,try allRows($0))}),old=dataset
        let (_,zip)=try exportBackup()
        if let fixture=ProcessInfo.processInfo.environment["VERDI_BACKUP_FIXTURE_OUTPUT"] {
            try Data(contentsOf:zip).write(to:URL(fileURLWithPath:fixture))
        }
        let (id,preview)=try previewBackup(zip)
        XCTAssertEqual(preview.object?["counts"]?.object?["activePlants"]?.integer,6)
        XCTAssertEqual(preview.object?["counts"]?.object?["archivedPlants"]?.integer,1)
        _=try backup("confirmImport",["operationId":.string(id),"preview":preview,"confirmed":.boolean(true)])
        XCTAssertEqual(try awaitBackup(id,terminal:["complete","failed"]).object?["operation"]?.object?["state"]?.object?["kind"]?.text,"complete")
        try open();XCTAssertNotEqual(dataset,old)
        for table in CoreSchema.tables {XCTAssertEqual(try allRows(table),before[table],table)}
        XCTAssertEqual(try call("getSettings").json(),try CanonicalValue.object(settings).json())
        let restored=try repo.queue.sync {try repo.database!.read {try $0.query("SELECT state,result_json FROM media_preparations")}}
        XCTAssertEqual(restored.count,1);XCTAssertEqual(restored[0][0],.text("ready"))
        let hashes=try repo.queue.sync {try BackupControl.mediaHash(repo.database!,root:repo.directory)}
        XCTAssertEqual(hashes.count,64)
        try open();XCTAssertEqual(try allRows("media_drafts"),before["media_drafts"])
    }
}
