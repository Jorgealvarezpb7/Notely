# Proposal

## Why

Notes are kept as one JSON blob under the `notes` key in `UserDefaults`. That store is opaque to the user, hard to back up or inspect, rewrites every note on each keystroke, and leaves no room for growing the data model (queries, more tables). Moving notes into a SQLite database in a Notely home directory, `~/.Notely`, gives a durable, inspectable, per-user store built only on the system `SQLite3` library, with no third-party dependency.

## What Changes

- Notes are stored in a SQLite database at `~/.Notely/db/data.sqlite3`, in a table named `notes`. The app creates `~/.Notely/db/` and the database on first use.
- Add a data-persistence layer, `NotelyRepository`, that owns the SQLite3 connection: opening/creating the database file, creating directories, running statements, binding values, transactions, and closing. It knows nothing about notes.
- Add `NotesRepository`, a subclass of `NotelyRepository`, that creates the `notes` table and loads and saves `[Note]`. It conforms to the existing `NoteRepository` protocol, so `NoteStore` is unchanged.
- On the first launch with the database, notes saved in `UserDefaults` (including the legacy single-note keys) are copied into the database once. The `UserDefaults` `notes` data is left in place as a backup and is no longer written.
- If the database cannot be opened or created, the app falls back to the current `UserDefaults` storage for that launch so no note is lost.
- `Sources/Notely/main.swift` wires `NotesRepository` instead of `UserDefaultsNoteRepository`.
- Non-goals: moving other preferences (text appearance, menu frame, animation settings, GitHub token) out of `UserDefaults`/Keychain; sync between machines; a user-chosen database location.

## Capabilities

### New Capabilities
- `note-storage`: where and how notes are persisted between launches — the `~/.Notely/db/data.sqlite3` database, its `notes` table, migration from `UserDefaults`, and behavior when the database cannot be used.

### Modified Capabilities
<!-- None: launch restore, list persistence, and upgrade requirements in multiple-notes, checklists, and note-resize stay as written; only the storage behind them changes. -->

## Impact

- `Sources/NotelyCore/Persistence/`: new `NotelyRepository.swift` (SQLite3 layer) and `NotesRepository.swift`; `UserDefaultsNoteRepository` stays for migration and fallback.
- `Package.swift`: a system-library shim target so `NotelyCore` can link `sqlite3` on Linux (the dkc container and `just test-linux`); macOS uses the SDK's `SQLite3` module.
- `Sources/Notely/main.swift`: composition root picks the new repository.
- `Tests/NotelyCoreTests/`: new tests for both layers against a temporary database path.
- `justfile`: `test-linux` may need `libsqlite3-dev` in the container.
- User data: a new `~/.Notely` directory in the home folder.
