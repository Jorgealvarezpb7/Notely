import Foundation
import NotelyCore
import Testing

/// Keeps notes in memory and records every save.
final class InMemoryNoteRepository: NoteRepository {
    var stored: [Note]
    private(set) var saves: [[Note]] = []

    init(_ notes: [Note] = []) {
        stored = notes
    }

    func load() -> [Note] {
        stored
    }

    func save(_ notes: [Note]) {
        stored = notes
        saves.append(notes)
    }
}

/// A `UserDefaults` of its own per test, removed when the test ends.
final class TestDefaults {
    let name = "NotelyTests-\(UUID().uuidString)"
    let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: name)!
    }

    deinit {
        defaults.removePersistentDomain(forName: name)
    }

    func savedNotes() -> [Note]? {
        defaults.data(forKey: "notes").flatMap { try? JSONDecoder().decode([Note].self, from: $0) }
    }
}

struct UserDefaultsRepositoryTests {
    @Test func firstLaunchMigratesSingleNoteKeys() {
        let test = TestDefaults()
        test.defaults.set("Hello", forKey: "noteText")
        test.defaults.set("{1, 2}", forKey: "panelOrigin")

        let notes = UserDefaultsNoteRepository(defaults: test.defaults).load()

        #expect(notes.count == 1)
        #expect(notes.first?.text == "Hello")
        #expect(notes.first?.origin == "{1, 2}")
        #expect(test.defaults.object(forKey: "noteText") == nil)
        #expect(test.defaults.object(forKey: "panelOrigin") == nil)
        #expect(test.savedNotes()?.map(\.id) == notes.map(\.id))
    }

    @Test func firstLaunchWithNothingSavedOpensOneEmptyNote() {
        let test = TestDefaults()
        let notes = UserDefaultsNoteRepository(defaults: test.defaults).load()
        #expect(notes.count == 1)
        #expect(notes.first?.text == "")
        #expect(notes.first?.origin == nil)
        #expect(test.savedNotes()?.count == 1)
    }

    @Test func undecodableDataFallsBackToOneEmptyNote() {
        let test = TestDefaults()
        test.defaults.set(Data("junk".utf8), forKey: "notes")
        let notes = UserDefaultsNoteRepository(defaults: test.defaults).load()
        #expect(notes.count == 1)
        #expect(notes.first?.text == "")
        #expect(test.savedNotes()?.map(\.id) == notes.map(\.id))
    }

    @Test func emptyListStaysEmpty() {
        let test = TestDefaults()
        UserDefaultsNoteRepository(defaults: test.defaults).save([])
        #expect(UserDefaultsNoteRepository(defaults: test.defaults).load().isEmpty)
    }

    @Test func damagedStyleRunsAreTrimmedOrDropped() {
        let test = TestDefaults()
        let note = Note(id: UUID(), text: "abc",
                        styles: [StyleRun(location: 1, length: 10, bold: true),
                                 StyleRun(location: 5, length: 2, italic: true)])
        let repository = UserDefaultsNoteRepository(defaults: test.defaults)
        repository.save([note])
        #expect(repository.load().first?.styles == [StyleRun(location: 1, length: 2, bold: true)])
    }

    @Test func savedNotesLoadAgain() {
        let test = TestDefaults()
        let repository = UserDefaultsNoteRepository(defaults: test.defaults)
        let notes = [Note(id: UUID(), text: "One", origin: "{10, 20}", size: "{300, 200}", tint: "#FFD60A")]
        repository.save(notes)
        let loaded = repository.load()
        #expect(loaded.map(\.id) == notes.map(\.id))
        #expect(loaded.first?.text == "One")
        #expect(loaded.first?.origin == "{10, 20}")
        #expect(loaded.first?.size == "{300, 200}")
        #expect(loaded.first?.tint == "#FFD60A")
    }
}

/// Notes as builds before this change saved them under "notes".
private let savedFixture = """
[
  {"id": "6F9E2C1A-0000-4000-8000-000000000001", "text": "Plain note", "origin": "{100, 200}", "size": "{220, 150}"},
  {"id": "6F9E2C1A-0000-4000-8000-000000000002", "text": "Bold start", "styles": [{"location": 0, "length": 4, "bold": true}]},
  {"id": "6F9E2C1A-0000-4000-8000-000000000003", "text": "Tinted", "tint": "#FFD60A", "isOpen": true},
  {"id": "6F9E2C1A-0000-4000-8000-000000000004", "text": "Groceries\\n[ ] Milk\\n[x] Eggs", "kind": "list", "title": "Groceries",
   "items": [{"id": "6F9E2C1A-0000-4000-8000-0000000000A1", "text": "Milk", "done": false},
             {"id": "6F9E2C1A-0000-4000-8000-0000000000A2", "text": "Eggs", "done": true}]},
  {"id": "6F9E2C1A-0000-4000-8000-000000000005", "text": "Closed", "isOpen": false},
  {"id": "6F9E2C1A-0000-4000-8000-000000000006", "text": "From a later version", "kind": "board"}
]
"""

/// JSON with sorted keys and no white space, to compare two encodings.
private func normalized(_ data: Data) throws -> String {
    let object = try JSONSerialization.jsonObject(with: data)
    let sorted = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: sorted, as: UTF8.self)
}

struct SavedFormatTests {
    @Test func notesSavedByEarlierBuildsLoad() {
        let test = TestDefaults()
        test.defaults.set(Data(savedFixture.utf8), forKey: "notes")
        let notes = UserDefaultsNoteRepository(defaults: test.defaults).load()

        #expect(notes.count == 6)
        #expect(notes[0].origin == "{100, 200}")
        #expect(notes[0].size == "{220, 150}")
        #expect(notes[0].isOpen == nil)
        #expect(notes[1].styles == [StyleRun(location: 0, length: 4, bold: true)])
        #expect(notes[2].tint == "#FFD60A")
        #expect(notes[3].isList)
        #expect(notes[3].title == "Groceries")
        #expect(notes[3].items?.map(\.text) == ["Milk", "Eggs"])
        #expect(notes[3].items?.map(\.done) == [false, true])
        #expect(notes[4].isOpen == false)
        #expect(notes[5].kind == "board")
        #expect(!notes[5].isList)
    }

    @Test func savingKeepsTheSameKeysAndValues() throws {
        let test = TestDefaults()
        test.defaults.set(Data(savedFixture.utf8), forKey: "notes")
        let repository = UserDefaultsNoteRepository(defaults: test.defaults)
        repository.save(repository.load())
        let saved = try #require(test.defaults.data(forKey: "notes"))
        #expect(try normalized(saved) == normalized(Data(savedFixture.utf8)))
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
