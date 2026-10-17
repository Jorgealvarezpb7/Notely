import Foundation
import NotelyCore
@testable import NotelySQLite
import Testing

private func rowCount(_ url: URL) throws -> Int {
    let statement = try SQLiteConnection(url: url).prepare("SELECT COUNT(*) FROM notes")
    try statement.step()
    return statement.int(at: 0) ?? -1
}

struct NotesDatabaseTests {
    @Test func defaultLocationIsUnderTheHomeFolder() {
        let path = NotesDatabase.defaultURL.path
        #expect(path.hasSuffix("/.Notely/db/data.sqlite3"))
        #expect(path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path))
    }

    @Test func insertAppendsInOrder() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let notes = fullNotes()
        for note in notes { try database.insert(note) }
        #expect(try database.all().map(\.id) == notes.map(\.id))
    }

    @Test func duplicateIdThrows() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let note = Note(id: UUID(), text: "a")
        try database.insert(note)
        #expect(throws: (any Error).self) { try database.insert(note) }
        #expect(try database.all().count == 1)
    }

    @Test func noteByIdReturnsTheNoteOrNil() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let note = Note(id: UUID(), text: "a")
        try database.insert(note)
        #expect(try database.note(id: note.id)?.text == "a")
        #expect(try database.note(id: UUID()) == nil)
    }

    @Test func updateChangesFieldsAndKeepsPosition() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let notes = fullNotes()
        for note in notes { try database.insert(note) }
        var changed = notes[0]
        changed.text = "Changed"
        changed.tint = "#000000"
        try database.update(changed)
        let loaded = try database.all()
        #expect(loaded.map(\.id) == notes.map(\.id))
        #expect(loaded[0].text == "Changed")
        #expect(loaded[0].tint == "#000000")
    }

    @Test func updateOfAnUnknownIdThrows() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let note = Note(id: UUID(), text: "a")
        #expect(throws: NotesDatabaseError.noteNotFound(note.id)) { try database.update(note) }
    }

    @Test func deleteRemovesTheRowAndIgnoresUnknownIds() throws {
        let folder = TempFolder()
        let database = try NotesDatabase(url: folder.databaseURL)
        let notes = fullNotes()
        for note in notes { try database.insert(note) }
        try database.delete(id: notes[1].id)
        try database.delete(id: UUID())
        #expect(try database.all().map(\.id) == [notes[0].id, notes[2].id])
        #expect(try rowCount(folder.databaseURL) == 2)
    }

    @Test func everyFieldAndTheOrderRoundTrip() throws {
        let folder = TempFolder()
        let notes = fullNotes()
        try NotesDatabase(url: folder.databaseURL).replaceAll(notes)

        let loaded = try NotesDatabase(url: folder.databaseURL).all()
        #expect(loaded.map(\.id) == notes.map(\.id))
        let list = loaded[1]
        #expect(list.isList)
        #expect(list.title == "Groceries")
        #expect(list.origin == "{5, 6}")
        #expect(list.size == "{300, 400}")
        #expect(list.isOpen == false)
        #expect(list.tint == "#FFD60A")
        #expect(list.githubRepo == "owner/repo")
        #expect(list.items == notes[1].items)
        #expect(loaded[0].styles == [StyleRun(location: 0, length: 4, bold: true, underline: true)])
        #expect(loaded[0].isOpen == nil)
        #expect(loaded[0].kind == nil)
    }

    @Test func replaceAllLeavesOnlyTheGivenNotes() throws {
        let folder = TempFolder()
        let database = try NotesDatabase(url: folder.databaseURL)
        let notes = fullNotes()
        try database.replaceAll(notes)
        #expect(try rowCount(folder.databaseURL) == 3)
        try database.replaceAll(Array(notes.dropFirst()))
        #expect(try rowCount(folder.databaseURL) == 2)
        #expect(try database.all().map(\.id) == notes.dropFirst().map(\.id))
    }

    @Test func emptyListStaysEmpty() throws {
        let folder = TempFolder()
        try NotesDatabase(url: folder.databaseURL).replaceAll([])
        #expect(try NotesDatabase(url: folder.databaseURL).all().isEmpty)
    }

    @Test func failedReplaceAllKeepsPreviousRows() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        let before = fullNotes()
        try database.replaceAll(before)
        let id = UUID()
        #expect(throws: (any Error).self) {
            try database.replaceAll([Note(id: id, text: "a"), Note(id: id, text: "duplicate id")])
        }
        #expect(try database.all().map(\.id) == before.map(\.id))
    }

    @Test func unreadableRowsAreSkipped() throws {
        let folder = TempFolder()
        let database = try NotesDatabase(url: folder.databaseURL)
        let good = Note(id: UUID(), text: "good")
        try database.replaceAll([good])
        try SQLiteConnection(url: folder.databaseURL).execute("""
            INSERT INTO notes (id, position, text) VALUES ('not-a-uuid', 1, 'bad id');
            INSERT INTO notes (id, position, text, items)
            VALUES ('6F9E2C1A-0000-4000-8000-000000000009', 2, 'bad items', '{oops');
            """)
        #expect(try database.all().map(\.id) == [good.id])
    }

    @Test func damagedStyleRunsAreTrimmed() throws {
        let database = try NotesDatabase(url: TempFolder().databaseURL)
        try database.replaceAll([Note(id: UUID(), text: "abc",
                                      styles: [StyleRun(location: 1, length: 10, bold: true),
                                               StyleRun(location: 5, length: 2, italic: true)])])
        #expect(try database.all().first?.styles == [StyleRun(location: 1, length: 2, bold: true)])
    }
}
