import Foundation
import NotelyCore

/// A folder of its own per test, removed when the test ends.
final class TempFolder {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("NotelyTests-\(UUID().uuidString)", isDirectory: true)

    /// `<folder>/db/data.sqlite3`: the `db` folder does not exist yet.
    var databaseURL: URL {
        url.appendingPathComponent("db", isDirectory: true).appendingPathComponent("data.sqlite3")
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
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

func fullNotes() -> [Note] {
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
