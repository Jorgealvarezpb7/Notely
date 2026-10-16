import Foundation
import NotelyCore

/// Keeps notes in the Notely SQLite database, one row per note or list. It
/// is what `NoteStore` saves through, on top of `NotesDatabase`.
///
/// The first time a database is set up, notes saved by earlier versions in
/// `UserDefaults` are copied in. That store is left as it is.
public final class SQLiteNoteRepository: NoteRepository {
    private let database: NotesDatabase
    private let log = Log("notes")

    public init(url: URL = NotesDatabase.defaultURL, legacy: UserDefaults = .standard) throws {
        database = try NotesDatabase(url: url) {
            UserDefaultsNoteRepository(defaults: legacy).savedNotes()
        }
    }

    public func load() -> [Note] {
        do {
            let notes = try database.all()
            log.info("loaded \(notes.count) notes")
            return notes
        } catch {
            log.error("could not load notes: \(error)")
            return []
        }
    }

    /// Replaces every stored note, all or nothing.
    public func save(_ notes: [Note]) {
        do {
            try database.replaceAll(notes)
            log.debug("saved \(notes.count) notes")
        } catch {
            log.error("could not save notes: \(error)")
        }
    }
}
