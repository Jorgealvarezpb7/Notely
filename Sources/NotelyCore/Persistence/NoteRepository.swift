import Foundation

/// Where notes are kept between launches. `NoteStore` loads once at start
/// and saves the whole list after every change. `NotesRepository` is the
/// store the app uses, a SQLite database at `~/.Notely/db/data.sqlite3`.
public protocol NoteRepository {
    /// Every saved note, with damaged data repaired or replaced.
    func load() -> [Note]
    func save(_ notes: [Note])
}

/// Keeps notes as one JSON array in `UserDefaults`. It is the store of
/// earlier versions: `NotesRepository` copies notes from it once, and the
/// app falls back to it when the database cannot be opened.
public struct UserDefaultsNoteRepository: NoteRepository {
    private static let notesKey = "notes"
    private static let legacyTextKey = "noteText"
    private static let legacyOriginKey = "panelOrigin"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private static func decode(_ data: Data) -> [Note]? {
        guard let decoded = try? JSONDecoder().decode([Note].self, from: data) else { return nil }
        return decoded.map { $0.clampingStyles() }
    }

    /// The notes saved here, or the single-note keys as one note, or one
    /// empty note. Unlike `load()`, it never writes or removes a key.
    public func savedNotes() -> [Note] {
        if let data = defaults.data(forKey: Self.notesKey) {
            return Self.decode(data) ?? [Note(id: UUID(), text: "")]
        }
        return [Note(id: UUID(), text: defaults.string(forKey: Self.legacyTextKey) ?? "",
                     origin: defaults.string(forKey: Self.legacyOriginKey))]
    }

    public func load() -> [Note] {
        if let data = defaults.data(forKey: Self.notesKey) {
            // An empty list (every note was deleted) stays empty, so the
            // menu shows only "+ New". Undecodable data falls back to one
            // empty note.
            if let decoded = Self.decode(data) {
                return decoded
            }
            let notes = [Note(id: UUID(), text: "", origin: nil, size: nil)]
            save(notes)
            return notes
        }
        // First launch of this version: migrate the single-note keys into
        // one note, then remove them.
        let text = defaults.string(forKey: Self.legacyTextKey) ?? ""
        let origin = defaults.string(forKey: Self.legacyOriginKey)
        let notes = [Note(id: UUID(), text: text, origin: origin, size: nil)]
        defaults.removeObject(forKey: Self.legacyTextKey)
        defaults.removeObject(forKey: Self.legacyOriginKey)
        save(notes)
        return notes
    }

    public func save(_ notes: [Note]) {
        guard let data = try? JSONEncoder().encode(notes) else { return }
        defaults.set(data, forKey: Self.notesKey)
    }
}

extension Note {
    /// The note with style runs trimmed to its text, and runs outside it
    /// dropped. Runs outside a note's text come from damaged data.
    func clampingStyles() -> Note {
        guard let styles else { return self }
        let length = text.utf16.count
        var note = self
        note.styles = styles.compactMap { $0.clamped(toLength: length) }
        return note
    }
}
