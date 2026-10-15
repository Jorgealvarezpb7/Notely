# Design

## Context

- `NoteStore` (`Sources/NotelyCore/Store/NoteStore.swift`) loads once through the `NoteRepository` protocol and calls `save(_:)` with the whole list after every change, on the main thread. That contract stays.
- `UserDefaultsNoteRepository` (`Sources/NotelyCore/Persistence/NoteRepository.swift`) stores `[Note]` as one JSON blob under `notes`, migrates the single-note keys `noteText`/`panelOrigin`, clamps damaged style runs, and replaces undecodable data with one empty note.
- `NotelyCore` is Foundation-only so it builds and tests on Linux (dkc container, `just test-linux` with `swift:6.0`). Apple platforms ship a `SQLite3` Clang module in the SDK; Linux has no such module, only `libsqlite3` + `sqlite3.h` from `libsqlite3-dev`.
- `Note` has scalar fields plus two nested arrays (`styles: [StyleRun]?`, `items: [ListItem]?`), all `Codable`.
- Behavior requirements: `specs/note-storage/spec.md`.

## Goals / Non-Goals

**Goals:**
- Two layers: `NotelyRepository` (generic SQLite3 access, no note knowledge) and `NotesRepository` (subclass, owns the `notes` table, conforms to `NoteRepository`).
- No third-party package; only the system SQLite3 C API.
- `NoteStore`, the UI, and every existing spec behave exactly as today.
- Both layers unit-tested on macOS and Linux against a temporary database file.

**Non-Goals:**
- Normalizing list items or style runs into their own tables.
- Moving other `UserDefaults` keys (text appearance, menu frame, animations) or the Keychain token.
- Incremental per-note writes; the store still saves the whole list.
- Concurrent access from several processes or threads.

## Decisions

### 1. Importing SQLite3 on both platforms
In `NotelyRepository.swift`:
```swift
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif
```
`Package.swift` adds, inside an `#if os(Linux)` block, `.systemLibrary(name: "CSQLite", path: "Sources/CSQLite", providers: [.apt(["libsqlite3-dev"])])` with a `module.modulemap` (`header "shim.h"`, `link "sqlite3"`) and `shim.h` including `<sqlite3.h>`, and makes `NotelyCore` depend on it there only.
- *Alternative*: a system-library target on both platforms. Works, but on macOS the SDK module is already the "native" route the request asks for; keeping the shim Linux-only means the shipped app has no extra target.
- *Alternative*: vendoring the SQLite amalgamation. Rejected: large, and not the system library.

### 2. `NotelyRepository` — the SQLite3 layer
`open class NotelyRepository` in `Sources/NotelyCore/Persistence/NotelyRepository.swift`:
- `public static var homeDirectory: URL` = `FileManager.default.homeDirectoryForCurrentUser/.Notely`; `public static var defaultDatabaseURL` = `homeDirectory/db/data.sqlite3`.
- `public init(databaseURL: URL = defaultDatabaseURL) throws`: creates the parent directory with intermediates (never removes anything), `sqlite3_open_v2(READWRITE | CREATE)`, then `PRAGMA journal_mode=WAL`, `PRAGMA synchronous=NORMAL`, `PRAGMA foreign_keys=ON`. Throws `SQLiteError` (code + `sqlite3_errmsg`) on any failure, closing the handle first.
- `deinit` calls `sqlite3_close_v2`.
- Helpers for subclasses: `execute(_ sql: String)` (via `sqlite3_exec`), `prepare(_ sql:) -> Statement`, `transaction(_ body: () throws -> T) rethrows -> T` (`BEGIN IMMEDIATE` / `COMMIT`, `ROLLBACK` on throw), and `userVersion` get/set over `PRAGMA user_version`.
- `Statement` (final class, finalizes in `deinit`): `bind(_: String?/Int?/Bool?, at:)` using `SQLITE_TRANSIENT` (`unsafeBitCast(-1, to: sqlite3_destructor_type.self)`), `step() -> Bool` (row / done, throws otherwise), `string(at:)`, `int(at:)`, `isNull(at:)`.
- *Why a class hierarchy*: requested by the user, and it lets later tables (e.g. a future `settings` table) reuse the connection code by subclassing. *Alternative*: composition (`NotesRepository` holding a `Database`). Cleaner to mock, but not what was asked; tests use a real temp file instead of mocks.

### 3. `notes` table and `NotesRepository`
`public final class NotesRepository: NotelyRepository, NoteRepository` in `Sources/NotelyCore/Persistence/NotesRepository.swift`:
```sql
CREATE TABLE IF NOT EXISTS notes (
    id          TEXT PRIMARY KEY NOT NULL,  -- UUID string
    position    INTEGER NOT NULL,           -- index in NoteStore.notes
    kind        TEXT,
    text        TEXT NOT NULL,
    title       TEXT,
    origin      TEXT,                       -- NSStringFromPoint form
    size        TEXT,                       -- NSStringFromSize form
    is_open     INTEGER,                    -- NULL = open (matches Note.isOpen nil)
    tint        TEXT,
    github_repo TEXT,
    styles      TEXT,                       -- JSON [StyleRun] or NULL
    items       TEXT                        -- JSON [ListItem] or NULL
)
```
- Scalars get real columns so the file is inspectable with `sqlite3`; the nested arrays are JSON text reusing the existing `Codable` types, so a new `ListItem` field needs no schema change.
- *Alternative*: one `data` JSON column per row. Simpler but barely better than `UserDefaults`. *Alternative*: `list_items`/`style_runs` tables. Faithful but needs joins and reordering logic for no current benefit.
- `load()`: `SELECT … ORDER BY position`; a row whose `id` is not a UUID or whose JSON fails to decode is skipped (spec: damaged rows). Style runs are clamped with the same logic as today, moved into a shared `Note` helper so both repositories use it. An empty table returns `[]` (keeps "delete last note → no notes at next launch").
- `save(_:)`: one `transaction { DELETE FROM notes; INSERT … for each (index, note) }`. Whole-list replace matches `NoteStore`'s contract and is atomic. Errors are written to standard error; `save` stays non-throwing to keep the protocol.

### 4. Schema version and one-time migration
`NotesRepository.init(databaseURL:legacy:)` takes the `UserDefaults` to migrate from. Inside one transaction: if `user_version == 0`, create the table, insert `legacy` notes, set `user_version = 1`. A failure rolls everything back, so the next launch retries; once `user_version` is 1 the migration never runs again (spec: no second copy). Later schema changes bump `user_version` with their own steps.

Migration reads `UserDefaults` without writing: a new read-only `UserDefaultsNoteRepository.savedNotes() -> [Note]` returns the decoded `notes` array (clamped), else one note built from `noteText`/`panelOrigin`, else one empty note — and never removes or sets keys. The existing `load()`/`save()` stay unchanged for the fallback.

### 5. Wiring and fallback
`Sources/Notely/main.swift`:
```swift
let repository: any NoteRepository
do { repository = try NotesRepository(legacy: .standard) }
catch { /* log */ repository = UserDefaultsNoteRepository(defaults: .standard) }
```
The database file is never deleted or recreated on error.

## Risks / Trade-offs

- [Linux toolchain lacks `sqlite3.h`] → `providers: [.apt(["libsqlite3-dev"])]` hints the fix; `just test-linux` installs `libsqlite3-dev` before `swift test`; verify the dkc image has it.
- [Fallback launch writes to `UserDefaults`, which a later database launch ignores] → changes made only during a fallback launch are not visible once the database works again. Rare (home folder unwritable); logged to standard error. Accepted for this change.
- [Whole-list rewrite on every keystroke] → a few dozen rows in one WAL transaction is sub-millisecond; revisit with per-note upserts only if profiling shows it.
- [WAL adds `data.sqlite3-wal`/`-shm` next to the file] → expected SQLite behavior; a backup should copy the `db` folder, or the app checkpoints on close via `sqlite3_close_v2`.
- [`synchronous=NORMAL` can lose the last transaction on power loss, not on app crash] → same or better durability than `UserDefaults`.
- [Name similarity: protocol `NoteRepository` vs class `NotesRepository`] → kept as requested; doc comments explain the roles.

## Migration Plan

1. Ship: first launch creates `~/.Notely/db/data.sqlite3`, copies notes, sets `user_version = 1`.
2. `UserDefaults` `notes` stays as a frozen backup.
3. Rollback: installing the previous build reads `UserDefaults` again and shows notes as of the upgrade; changes made after the upgrade live only in the database.
