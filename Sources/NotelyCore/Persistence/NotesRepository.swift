import Foundation

/// Keeps notes in the `notes` table of the Notely database, one row per
/// note or list. It extends `NotelyRepository`, which owns the SQLite3
/// connection, and is what `NoteStore` saves through.
///
/// The first time a database is set up, notes saved by earlier versions
/// in `UserDefaults` are copied in. That store is left as it is.
public final class NotesRepository: NotelyRepository, NoteRepository {
    private static let schemaVersion = 1

    private static let createTable = """
        CREATE TABLE IF NOT EXISTS notes (
            id          TEXT PRIMARY KEY NOT NULL,
            position    INTEGER NOT NULL,
            kind        TEXT,
            text        TEXT NOT NULL,
            title       TEXT,
            origin      TEXT,
            size        TEXT,
            is_open     INTEGER,
            tint        TEXT,
            github_repo TEXT,
            styles      TEXT,
            items       TEXT
        )
        """

    private static let insert = """
        INSERT INTO notes (id, position, kind, text, title, origin, size, is_open, tint, github_repo, styles, items)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

    private static let select = """
        SELECT id, kind, text, title, origin, size, is_open, tint, github_repo, styles, items
        FROM notes ORDER BY position
        """

    /// Opens (creating when missing) the database and, on a new one,
    /// copies the notes saved in `legacy`.
    public init(databaseURL: URL = NotelyRepository.defaultDatabaseURL,
                legacy: UserDefaults = .standard) throws {
        try super.init(databaseURL: databaseURL)
        guard userVersion < Self.schemaVersion else { return }
        try transaction {
            try execute(Self.createTable)
            try write(UserDefaultsNoteRepository(defaults: legacy).savedNotes())
            try execute("PRAGMA user_version = \(Self.schemaVersion)")
        }
    }

    public func load() -> [Note] {
        guard let statement = try? prepare(Self.select) else { return [] }
        let decoder = JSONDecoder()
        var notes: [Note] = []
        // A row that cannot be read is skipped; the rest still open.
        while (try? statement.step()) == true {
            guard let idText = statement.string(at: 0), let id = UUID(uuidString: idText),
                  let text = statement.string(at: 2) else { continue }
            var styles: [StyleRun]?
            if let json = statement.string(at: 9) {
                guard let decoded = try? decoder.decode([StyleRun].self, from: Data(json.utf8)) else { continue }
                styles = decoded
            }
            var items: [ListItem]?
            if let json = statement.string(at: 10) {
                guard let decoded = try? decoder.decode([ListItem].self, from: Data(json.utf8)) else { continue }
                items = decoded
            }
            notes.append(Note(id: id, text: text, origin: statement.string(at: 4),
                              size: statement.string(at: 5),
                              isOpen: statement.int(at: 6).map { $0 != 0 },
                              kind: statement.string(at: 1), title: statement.string(at: 3),
                              items: items, styles: styles, tint: statement.string(at: 7),
                              githubRepo: statement.string(at: 8)).clampingStyles())
        }
        return notes
    }

    /// Replaces every stored note, all or nothing.
    public func save(_ notes: [Note]) {
        do {
            try transaction {
                try execute("DELETE FROM notes")
                try write(notes)
            }
        } catch {
            FileHandle.standardError.write(Data("Notely: could not save notes: \(error)\n".utf8))
        }
    }

    /// Inserts `notes` in order; call inside a transaction.
    private func write(_ notes: [Note]) throws {
        let statement = try prepare(Self.insert)
        let encoder = JSONEncoder()
        for (position, note) in notes.enumerated() {
            statement.reset()
            statement.bind(note.id.uuidString, at: 1)
            statement.bind(position, at: 2)
            statement.bind(note.kind, at: 3)
            statement.bind(note.text, at: 4)
            statement.bind(note.title, at: 5)
            statement.bind(note.origin, at: 6)
            statement.bind(note.size, at: 7)
            statement.bind(note.isOpen.map { $0 ? 1 : 0 }, at: 8)
            statement.bind(note.tint, at: 9)
            statement.bind(note.githubRepo, at: 10)
            statement.bind(try note.styles.map { try Self.json($0, encoder) }, at: 11)
            statement.bind(try note.items.map { try Self.json($0, encoder) }, at: 12)
            try statement.step()
        }
    }

    private static func json<T: Encodable>(_ value: T, _ encoder: JSONEncoder) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }
}
