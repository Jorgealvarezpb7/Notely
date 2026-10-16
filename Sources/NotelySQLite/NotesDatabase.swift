import Foundation
import NotelyCore

public enum NotesDatabaseError: Error, Equatable {
    case noteNotFound(UUID)
}

/// The notes database, at `~/.Notely/db/data.sqlite3` unless a test names
/// another file: create, read, update, and delete notes without any SQL.
/// Opening it creates the file and brings the schema up to date.
public final class NotesDatabase {
    /// `~/.Notely`.
    public static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Notely", isDirectory: true)
    }

    /// `~/.Notely/db/data.sqlite3`.
    public static var defaultURL: URL {
        homeDirectory
            .appendingPathComponent("db", isDirectory: true)
            .appendingPathComponent("data.sqlite3")
    }

    private let connection: SQLiteConnection

    /// Opens (creating when missing) the database and runs pending
    /// migrations. `initialNotes` is called only when the database is new,
    /// and its notes are stored in the same transaction as the schema.
    public convenience init(url: URL = NotesDatabase.defaultURL,
                            initialNotes: (() -> [Note])? = nil) throws {
        try self.init(url: url, migrations: Migrations.all, initialNotes: initialNotes)
    }

    init(url: URL, migrations: [Migration], initialNotes: (() -> [Note])? = nil) throws {
        connection = try SQLiteConnection(url: url)
        try Migrations.run(on: connection, migrations: migrations, seed: initialNotes.map { notes in
            { connection in
                for (position, note) in notes().enumerated() {
                    try NotesTable.insert(note, position: position, connection)
                }
            }
        })
    }

    /// Every readable note in order.
    public func all() throws -> [Note] {
        try NotesTable.selectAll(connection)
    }

    public func note(id: UUID) throws -> Note? {
        try NotesTable.select(id: id, connection)
    }

    /// Adds `note` after the last one. Throws when the id is already stored.
    public func insert(_ note: Note) throws {
        try connection.transaction {
            try NotesTable.insert(note, position: try NotesTable.nextPosition(connection), connection)
        }
    }

    /// Replaces the stored fields of the note with the same id, keeping its
    /// place. Throws `noteNotFound` when no note has that id.
    public func update(_ note: Note) throws {
        try connection.transaction {
            guard try NotesTable.update(note, connection) else {
                throw NotesDatabaseError.noteNotFound(note.id)
            }
        }
    }

    /// Removes the note; does nothing when no note has that id.
    public func delete(id: UUID) throws {
        try connection.transaction {
            try NotesTable.delete(id: id, connection)
        }
    }

    /// Replaces every stored note, in the order given, all or nothing.
    public func replaceAll(_ notes: [Note]) throws {
        try connection.transaction {
            try NotesTable.deleteAll(connection)
            for (position, note) in notes.enumerated() {
                try NotesTable.insert(note, position: position, connection)
            }
        }
    }
}
