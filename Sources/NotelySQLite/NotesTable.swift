import Foundation
import NotelyCore

/// Every query on the `notes` table, one row per note or list. Row order is
/// the `position` column. Callers run these inside a transaction when they
/// need several to succeed together.
enum NotesTable {
    private static let log = Log("sqlite")

    static let createSQL = """
        CREATE TABLE notes (
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

    private static let columns = "id, kind, text, title, origin, size, is_open, tint, github_repo, styles, items"

    /// Every readable note in order. A row that cannot be read is skipped.
    static func selectAll(_ connection: SQLiteConnection) throws -> [Note] {
        let statement = try connection.prepare("SELECT \(columns) FROM notes ORDER BY position")
        var notes: [Note] = []
        while try statement.step() {
            if let note = decode(statement) { notes.append(note) }
        }
        return notes
    }

    static func select(id: UUID, _ connection: SQLiteConnection) throws -> Note? {
        let statement = try connection.prepare("SELECT \(columns) FROM notes WHERE id = ?")
        statement.bind(id.uuidString, at: 1)
        guard try statement.step() else { return nil }
        return decode(statement)
    }

    /// The position after the last row.
    static func nextPosition(_ connection: SQLiteConnection) throws -> Int {
        let statement = try connection.prepare("SELECT COALESCE(MAX(position) + 1, 0) FROM notes")
        try statement.step()
        return statement.int(at: 0) ?? 0
    }

    /// Throws on a duplicate id.
    static func insert(_ note: Note, position: Int, _ connection: SQLiteConnection) throws {
        let statement = try connection.prepare("""
            INSERT INTO notes (id, position, kind, text, title, origin, size, is_open, tint, github_repo, styles, items)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
        statement.bind(note.id.uuidString, at: 1)
        statement.bind(position, at: 2)
        try bindFields(of: note, to: statement, from: 3)
        try statement.step()
    }

    /// Replaces every field but `id` and `position`; `false` when no row has
    /// that id.
    static func update(_ note: Note, _ connection: SQLiteConnection) throws -> Bool {
        let statement = try connection.prepare("""
            UPDATE notes SET kind = ?, text = ?, title = ?, origin = ?, size = ?, is_open = ?,
                             tint = ?, github_repo = ?, styles = ?, items = ?
            WHERE id = ?
            """)
        log.debug("updating note \(note.id)")
        try bindFields(of: note, to: statement, from: 1)
        statement.bind(note.id.uuidString, at: 11)
        try statement.step()
        return connection.changes > 0
    }

    static func delete(id: UUID, _ connection: SQLiteConnection) throws {
        let statement = try connection.prepare("DELETE FROM notes WHERE id = ?")
        statement.bind(id.uuidString, at: 1)
        try statement.step()
    }

    static func deleteAll(_ connection: SQLiteConnection) throws {
        try connection.execute("DELETE FROM notes")
    }

    /// kind, text, title, origin, size, is_open, tint, github_repo, styles,
    /// items: ten parameters from `index`.
    private static func bindFields(of note: Note, to statement: SQLiteConnection.Statement,
                                   from index: Int32) throws {
        let encoder = JSONEncoder()
        statement.bind(note.kind, at: index)
        statement.bind(note.text, at: index + 1)
        statement.bind(note.title, at: index + 2)
        statement.bind(note.origin, at: index + 3)
        statement.bind(note.size, at: index + 4)
        statement.bind(note.isOpen.map { $0 ? 1 : 0 }, at: index + 5)
        statement.bind(note.tint, at: index + 6)
        statement.bind(note.githubRepo, at: index + 7)
        statement.bind(try note.styles.map { try json($0, encoder) }, at: index + 8)
        statement.bind(try note.items.map { try json($0, encoder) }, at: index + 9)
    }

    private static func json<T: Encodable>(_ value: T, _ encoder: JSONEncoder) throws -> String {
        String(decoding: try encoder.encode(value), as: UTF8.self)
    }

    /// The note in the current row, or `nil` when its id or JSON is damaged.
    private static func decode(_ statement: SQLiteConnection.Statement) -> Note? {
        let decoder = JSONDecoder()
        guard let idText = statement.string(at: 0), let id = UUID(uuidString: idText),
              let text = statement.string(at: 2) else { return nil }
        var styles: [StyleRun]?
        if let json = statement.string(at: 9) {
            guard let decoded = try? decoder.decode([StyleRun].self, from: Data(json.utf8)) else { return nil }
            styles = decoded
        }
        var items: [ListItem]?
        if let json = statement.string(at: 10) {
            guard let decoded = try? decoder.decode([ListItem].self, from: Data(json.utf8)) else { return nil }
            items = decoded
        }
        return Note(id: id, text: text, origin: statement.string(at: 4), size: statement.string(at: 5),
                    isOpen: statement.int(at: 6).map { $0 != 0 }, kind: statement.string(at: 1),
                    title: statement.string(at: 3), items: items, styles: styles,
                    tint: statement.string(at: 7), githubRepo: statement.string(at: 8)).clampingStyles()
    }
}
