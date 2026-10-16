import Foundation
import NotelyCore
import NotelySQLite
import Testing

struct SQLiteNoteRepositoryTests {
    @Test func saveThenLoadRoundTrips() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let notes = fullNotes()
        try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults).save(notes)
        let loaded = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults).load()
        #expect(loaded.map(\.id) == notes.map(\.id))
    }

    @Test func firstOpenCopiesUserDefaultsAndLeavesThemAlone() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let notes = fullNotes()
        UserDefaultsNoteRepository(defaults: defaults.defaults).save(notes)

        let repository = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults)
        #expect(repository.load().map(\.id) == notes.map(\.id))
        #expect(defaults.savedNotes()?.map(\.id) == notes.map(\.id))
    }

    @Test func singleNoteKeysAreCopiedWithoutBeingRemoved() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        defaults.defaults.set("Hello", forKey: "noteText")
        defaults.defaults.set("{1, 2}", forKey: "panelOrigin")

        let loaded = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults).load()
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
            let repository = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults)
            repository.save(Array(repository.load().dropFirst()))
        }
        let again = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults)
        #expect(again.load().map(\.id) == notes.dropFirst().map(\.id))
    }

    @Test func freshInstallHasOneEmptyNote() throws {
        let folder = TempFolder()
        let defaults = TestDefaults()
        let loaded = try SQLiteNoteRepository(url: folder.databaseURL, legacy: defaults.defaults).load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.text == "")
    }
}
