import Foundation
import Observation

/// Holds every note and every rule for changing one. Each change is saved
/// through the repository at once, so text and position survive a quit.
@Observable
public final class NoteStore {
    public private(set) var notes: [Note]

    private let repository: any NoteRepository

    public init(repository: any NoteRepository) {
        self.repository = repository
        notes = repository.load()
    }

    public func note(_ id: UUID) -> Note? {
        notes.first(where: { $0.id == id })
    }

    /// Saves a note's text and its style runs together. Empty runs are
    /// saved as no styles.
    public func setText(_ text: String, styles: [StyleRun], for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].text = text
        notes[index].styles = styles.isEmpty ? nil : styles
        save()
    }

    public func setOrigin(_ origin: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].origin = origin
        save()
    }

    /// `nil` removes the tint.
    public func setTint(_ tint: String?, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }),
              notes[index].tint != tint else { return }
        notes[index].tint = tint
        save()
    }

    public func setOpen(_ isOpen: Bool, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isOpen = isOpen
        save()
    }

    public func setFrame(origin: String, size: String, for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].origin = origin
        notes[index].size = size
        save()
    }

    @discardableResult
    public func add(origin: String?, size: String?) -> Note {
        let note = Note(id: UUID(), text: "", origin: origin, size: size)
        notes.append(note)
        save()
        return note
    }

    @discardableResult
    public func addList(origin: String?, size: String?) -> Note {
        var note = Note(id: UUID(), text: "", origin: origin, size: size)
        note.kind = Note.listKind
        note.title = ""
        note.items = []
        notes.append(note)
        save()
        return note
    }

    public func remove(_ id: UUID) {
        notes.removeAll { $0.id == id }
        save()
    }

    /// Applies one change to a list, refreshes its plain-text copy, and
    /// saves.
    private func updateList(_ id: UUID, _ change: (inout Note) -> Void) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[index])
        notes[index].text = plainText(ofList: notes[index])
        save()
    }

    public func setTitle(_ title: String, for id: UUID) {
        updateList(id) { $0.title = title }
    }

    /// Adds an unchecked item at the end of the unchecked items.
    @discardableResult
    public func appendItem(_ text: String, for id: UUID) -> UUID {
        let item = ListItem(id: UUID(), text: text, done: false)
        updateList(id) { note in
            var items = note.items ?? []
            items.insert(item, at: items.firstIndex(where: \.done) ?? items.count)
            note.items = items
        }
        return item.id
    }

    /// Adds an empty unchecked item directly after the unchecked item
    /// `itemID`.
    @discardableResult
    public func insertItem(after itemID: UUID, for id: UUID) -> UUID {
        let item = ListItem(id: UUID(), text: "", done: false)
        updateList(id) { note in
            var items = note.items ?? []
            let index = items.firstIndex(where: { $0.id == itemID }).map { $0 + 1 } ?? items.count
            items.insert(item, at: index)
            note.items = items
        }
        return item.id
    }

    public func setItemText(_ text: String, item itemID: UUID, for id: UUID) {
        updateList(id) { note in
            guard let index = note.items?.firstIndex(where: { $0.id == itemID }) else { return }
            note.items?[index].text = text
        }
    }

    /// Saves an item's description as typed. An empty description is
    /// kept as empty, not removed: it may be a change to send.
    public func setItemBody(_ body: String, item itemID: UUID, for id: UUID) {
        updateList(id) { note in
            guard let index = note.items?.firstIndex(where: { $0.id == itemID }) else { return }
            note.items?[index].body = body
        }
    }

    /// Ends a held description conflict. `keepMine` takes GitHub's
    /// description as the one last seen, so the user's description is a
    /// waiting change again and is sent (and checked again) at the next
    /// push. Otherwise the item takes GitHub's description and nothing
    /// is left to send.
    public func resolveConflict(item itemID: UUID, for id: UUID, keepMine: Bool) {
        updateList(id) { note in
            guard let index = note.items?.firstIndex(where: { $0.id == itemID }),
                  let held = note.items?[index].heldBody else { return }
            if !keepMine {
                note.items?[index].body = held
            }
            note.items?[index].remoteBody = held
            note.items?[index].heldBody = nil
        }
    }

    public func removeItem(_ itemID: UUID, for id: UUID) {
        guard note(id)?.items?.contains(where: { $0.id == itemID }) == true else { return }
        updateList(id) { note in note.items?.removeAll { $0.id == itemID } }
    }

    /// Checks or unchecks an item and moves it to index "number of
    /// unchecked items": for a newly checked item that is the top of the
    /// checked items, for a newly unchecked one the end of the unchecked
    /// items.
    public func toggleItem(_ itemID: UUID, for id: UUID) {
        updateList(id) { note in
            var items = note.items ?? []
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
            var item = items.remove(at: index)
            item.done.toggle()
            items.insert(item, at: items.filter { !$0.done }.count)
            note.items = items
        }
    }

    /// Replaces a list's items, as issue sync computes them.
    public func setItems(_ items: [ListItem], for id: UUID) {
        guard note(id)?.items != items else { return }
        updateList(id) { $0.items = items }
    }

    /// Links a list to a GitHub repository, given as "owner/repo".
    /// `keep` keeps the unchecked items, to be created as issues;
    /// otherwise every item goes. Checked items always go. The title
    /// never changes.
    public func link(_ id: UUID, repo: String, keep: Bool) {
        updateList(id) { note in
            note.githubRepo = repo
            note.items = keep ? (note.items ?? []).filter { !$0.done } : []
        }
    }

    /// Unlinks a list. Its items stay, as local items.
    public func unlink(_ id: UUID) {
        guard note(id)?.githubRepo != nil else { return }
        updateList(id) { $0.githubRepo = nil }
    }

    private func save() {
        repository.save(notes)
    }
}
