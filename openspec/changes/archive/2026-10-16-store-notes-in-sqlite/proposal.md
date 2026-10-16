# Proposal

## Why

Notes are kept as one JSON blob under the `notes` key in `UserDefaults`. That store is opaque to the user, hard to back up or inspect, rewrites every note on each keystroke, and leaves no room for growing the data model (queries, more tables). Moving notes into a SQLite database in a Notely home directory, `~/.Notely`, gives a durable, inspectable, per-user store built only on the system `SQLite3` library, with no third-party dependency.

## What Changes

- Notes are stored in a SQLite database at `~/.Notely/db/data.sqlite3`, in a table named `notes`. The app creates `~/.Notely/db/` and the database on first use.
- Add a new module, `NotelySQLite`, that owns everything SQLite: the connection, the schema migrations, the `notes` table, and every SQL query. No SQL and no `import SQLite3` appears outside it.
- `NotelySQLite` migrations are self-contained: the module holds an ordered list of versioned migrations (the first one creates the `notes` table) and applies the pending ones when it opens the database. Callers never run or know about schema steps.
- `NotelySQLite` exposes a higher-level abstraction with regular CRUD operations on notes (`all`, `note(id:)`, `insert`, `update`, `delete`, plus an atomic `replaceAll`). Consumers do not see SQL, statements, or the connection.
- `NotelySQLite` also provides `SQLiteNoteRepository`, which conforms to the existing `NoteRepository` protocol on top of that CRUD layer, so `NoteStore` is unchanged.
- On the first launch with the database, notes saved in `UserDefaults` (including the legacy single-note keys) are copied into the database once, in the same transaction that creates the schema. The `UserDefaults` `notes` data is left in place as a backup and is no longer written.
- If the database cannot be opened or created, the app falls back to the current `UserDefaults` storage for that launch so no note is lost.
- `Sources/Notely/main.swift` wires `SQLiteNoteRepository` instead of `UserDefaultsNoteRepository`.
- Non-goals: moving other preferences (text appearance, menu frame, animation settings, GitHub token) out of `UserDefaults`/Keychain; sync between machines; a user-chosen database location. The app is macOS only; there is no Linux support (see `CLAUDE.md`).

## Capabilities

### New Capabilities
- `note-storage`: where and how notes are persisted between launches — the `~/.Notely/db/data.sqlite3` database, its versioned `notes` table, migration from `UserDefaults`, and behavior when the database cannot be used.

### Modified Capabilities
<!-- None: launch restore, list persistence, and upgrade requirements in multiple-notes, checklists, and note-resize stay as written; only the storage behind them changes. -->

## Impact

- `Sources/NotelySQLite/` (new target): connection and statement wrapper, migrations, `notes` table queries, CRUD type, and `SQLiteNoteRepository`. Depends on `NotelyCore` for `Note` and the `NoteRepository` protocol.
- `Sources/NotelyCore/Persistence/`: keeps `NoteRepository` and `UserDefaultsNoteRepository` (migration source and fallback). The earlier `NotelyRepository.swift` and `NotesRepository.swift` move into `NotelySQLite` and are reshaped.
- `Package.swift`: new `NotelySQLite` target (depends on `NotelyCore`), new `NotelySQLiteTests` target, and `Notely` depends on `NotelySQLite`. `NotelyCore` no longer imports `SQLite3`. The system `SQLite3` module comes with the macOS SDK; no shim or extra target.
- `Sources/Notely/main.swift`: composition root picks the new repository.
- `Tests/`: SQLite tests move to `NotelySQLiteTests`, run against a temporary database path.
- `CLAUDE.md`: architecture section lists the new `NotelySQLite` target.
- User data: a new `~/.Notely` directory in the home folder.
