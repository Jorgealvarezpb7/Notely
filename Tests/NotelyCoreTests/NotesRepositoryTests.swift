import Foundation
import NotelyCore
import Testing

private func fullNotes() -> [Note] {
    var list = Note(id: UUID(), text: "Groceries\n[ ] Milk", origin: "{5, 6}", size: "{300, 400}",
                    isOpen: false, kind: Note.listKind, title: "Groceries",
                    items: [ListItem(id: UUID(), text: "Milk", done: false, issueNumber: 7,
                                     remoteTitle: "Milk", remoteClosed: false, issueAuthor: "me",
                                     body: "2%", remoteBody: "whole", heldBody: "skim"),
                            ListItem(id: UUID(), text: "Eggs", done: true)],
                    tint: "#FFD60A", githubRepo: "owner/repo")
    list.styles = nil
    let note = Note(id: UUID(), text: "Bold start", origin: "{1, 2}", size: "{220, 150}",
                    styles: [StyleRun(location: 0, length: 4, bold: true, underline: true)])
    return [note, list, Note(id: UUID(), text: "")]
}

private func rowCount(_ url: URL) throws -> Int {
    let repository = try NotelyRepository(databaseURL: url)
    let statement = try repository.prepare("SELECT COUNT(*) FROM notes")
    try statement.step()
    return statement.int(at: 0) ?? -1
}

struct NotesRepositoryTests {
    @Test func everyFieldAndTheOrderRoundTrip() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let notes = fullNotes()
        try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).save(notes)

        let loaded = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).load()
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

    @Test func oneRowPerNoteAndDeletedNotesLeaveNone() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        let notes = fullNotes()
        repository.save(notes)
        #expect(try rowCount(folder.databaseURL) == 3)
        repository.save(Array(notes.dropFirst()))
        #expect(try rowCount(folder.databaseURL) == 2)
        #expect(repository.load().map(\.id) == notes.dropFirst().map(\.id))
    }

    @Test func emptyListStaysEmpty() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).save([])
        #expect(try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).load().isEmpty)
    }

    @Test func firstOpenCopiesUserDefaultsAndLeavesThemAlone() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let notes = fullNotes()
        UserDefaultsNoteRepository(defaults: defaults.defaults).save(notes)

        let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        #expect(repository.load().map(\.id) == notes.map(\.id))
        #expect(defaults.savedNotes()?.map(\.id) == notes.map(\.id))
    }

    @Test func singleNoteKeysAreCopiedWithoutBeingRemoved() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        defaults.defaults.set("Hello", forKey: "noteText")
        defaults.defaults.set("{1, 2}", forKey: "panelOrigin")

        let loaded = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.text == "Hello")
        #expect(loaded.first?.origin == "{1, 2}")
        #expect(defaults.defaults.string(forKey: "noteText") == "Hello")
    }

    @Test func secondOpenDoesNotBringBackDeletedNotes() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let notes = fullNotes()
        UserDefaultsNoteRepository(defaults: defaults.defaults).save(notes)

        do {
            let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
            repository.save(Array(repository.load().dropFirst()))
        }
        let again = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        #expect(again.load().map(\.id) == notes.dropFirst().map(\.id))
    }

    @Test func freshInstallHasOneEmptyNote() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let loaded = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults).load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.text == "")
        #expect(try rowCount(folder.databaseURL) == 1)
    }

    @Test func unreadableRowsAreSkipped() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let good = Note(id: UUID(), text: "good")
        let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        repository.save([good])
        try repository.execute("""
            INSERT INTO notes (id, position, text) VALUES ('not-a-uuid', 1, 'bad id');
            INSERT INTO notes (id, position, text, items)
            VALUES ('6F9E2C1A-0000-4000-8000-000000000009', 2, 'bad items', '{oops');
            """)
        #expect(repository.load().map(\.id) == [good.id])
    }

    @Test func failedSaveKeepsPreviousRows() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        let before = fullNotes()
        repository.save(before)

        let id = UUID()
        repository.save([Note(id: id, text: "a"), Note(id: id, text: "duplicate id")])
        #expect(repository.load().map(\.id) == before.map(\.id))
    }

    @Test func damagedStyleRunsAreTrimmed() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let repository = try NotesRepository(databaseURL: folder.databaseURL, legacy: defaults.defaults)
        repository.save([Note(id: UUID(), text: "abc",
                              styles: [StyleRun(location: 1, length: 10, bold: true),
                                       StyleRun(location: 5, length: 2, italic: true)])])
        #expect(repository.load().first?.styles == [StyleRun(location: 1, length: 2, bold: true)])
    }
}

struct SavedNotesReadOnlyTests {
    @Test func savedNotesLeavesEveryKeyUnchanged() {
        let defaults = TestDefaults()
        defaults.defaults.set("Hello", forKey: "noteText")
        defaults.defaults.set("{1, 2}", forKey: "panelOrigin")

        let notes = UserDefaultsNoteRepository(defaults: defaults.defaults).savedNotes()
        #expect(notes.first?.text == "Hello")
        #expect(defaults.defaults.string(forKey: "noteText") == "Hello")
        #expect(defaults.defaults.string(forKey: "panelOrigin") == "{1, 2}")
        #expect(defaults.defaults.data(forKey: "notes") == nil)
    }

    @Test func savedNotesOnJunkIsOneEmptyNoteWithoutWriting() {
        let defaults = TestDefaults()
        defaults.defaults.set(Data("junk".utf8), forKey: "notes")
        let notes = UserDefaultsNoteRepository(defaults: defaults.defaults).savedNotes()
        #expect(notes.count == 1)
        #expect(defaults.defaults.data(forKey: "notes") == Data("junk".utf8))
    }
}
