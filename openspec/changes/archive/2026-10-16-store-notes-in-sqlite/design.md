# Design

## Context

- `NoteStore` (`Sources/NotelyCore/Store/NoteStore.swift`) loads once through the `NoteRepository` protocol and calls `save(_:)` with the whole list after every change, on the main thread. That contract stays.
- `UserDefaultsNoteRepository` (`Sources/NotelyCore/Persistence/NoteRepository.swift`) stores `[Note]` as one JSON blob under `notes`, migrates the single-note keys `noteText`/`panelOrigin`, clamps damaged style runs, and replaces undecodable data with one empty note.
- Repo rule: protocols and pure logic live in `NotelyCore`; platform APIs live in the other targets. `SQLite3` is a platform API, so it gets its own target, `NotelySQLite`, instead of living in `NotelyCore`. Apple SDKs ship the `SQLite3` module, so it is imported directly; the app is macOS only.
- `Note` has scalar fields plus two nested arrays (`styles: [StyleRun]?`, `items: [ListItem]?`), all `Codable`.
- Behavior requirements: `specs/note-storage/spec.md`.

## Goals / Non-Goals

**Goals:**
- A `NotelySQLite` module that is the only place with SQLite3 calls, SQL text, and schema knowledge.
- Self-contained migrations: opening the database brings the schema to the latest version, with no setup by callers.
- A CRUD abstraction over notes that hides the connection and statements, plus a `NoteRepository` adapter.
- No third-party package; only the system SQLite3 C API.
- `NoteStore`, the UI, and every existing spec behave exactly as today.
- Unit tests for the module on macOS against a temporary database file.

**Non-Goals:**
- Normalizing list items or style runs into their own tables.
- Moving other `UserDefaults` keys (text appearance, menu frame, animations) or the Keychain token.
- Incremental per-note writes from `NoteStore`; the store still saves the whole list (the CRUD calls exist for later use).
- Concurrent access from several processes or threads.

## Decisions

### 1. Module layout
New target `NotelySQLite` (`Sources/NotelySQLite/`), depends on `NotelyCore` (for `Note`, `StyleRun`, `ListItem`, `NoteRepository`). `NotelyCore` does not depend on it. `Package.swift` adds:
```swift
.target(name: "NotelySQLite", dependencies: ["NotelyCore"], path: "Sources/NotelySQLite"),
.testTarget(name: "NotelySQLiteTests", dependencies: ["NotelySQLite", "NotelyCore"], path: "Tests/NotelySQLiteTests"),
```
and adds `"NotelySQLite"` to the `Notely` executable's dependencies. Files:
- `SQLiteConnection.swift` (internal): the C API wrapper.
- `Migrations.swift` (internal): versioned schema steps and the runner.
- `NotesTable.swift` (internal): every query on `notes`.
- `NotesDatabase.swift` (public): the CRUD surface.
- `SQLiteNoteRepository.swift` (public): the `NoteRepository` adapter.

Only `NotesDatabase`, `SQLiteNoteRepository`, `SQLiteError`, and `NotesDatabase.defaultURL` are `public`. Everything that touches `OpaquePointer` or SQL text is `internal`.
- *Alternative*: keep the layer inside `NotelyCore`. Rejected: breaks the repo rule and makes `NotelyCore` import a platform library.
- *Alternative*: subclass hierarchy (`NotelyRepository` → `NotesRepository`). Dropped in favor of composition: `NotesDatabase` owns a `SQLiteConnection`, tables are internal types over it. Tests use a real temp file instead of mocks.

### 2. `SQLiteConnection` — the SQLite3 layer (internal)
`final class SQLiteConnection` in `SQLiteConnection.swift`, `import SQLite3`:
- `init(url: URL) throws`: creates the parent directory with intermediates (never removes anything), `sqlite3_open_v2(READWRITE | CREATE)`, then `PRAGMA journal_mode=WAL`, `PRAGMA synchronous=NORMAL`, `PRAGMA foreign_keys=ON`. Throws `SQLiteError` (code + `sqlite3_errmsg`) on any failure, closing the handle first.
- `deinit` calls `sqlite3_close_v2`.
- `execute(_ sql: String)` (via `sqlite3_exec`), `prepare(_ sql:) -> Statement`, `transaction(_ body: () throws -> T) rethrows -> T` (`BEGIN IMMEDIATE` / `COMMIT`, `ROLLBACK` on throw), and `userVersion` get/set over `PRAGMA user_version`.
- `Statement` (final class, finalizes in `deinit`): `bind(_: String?/Int?/Bool?, at:)` using `SQLITE_TRANSIENT` (`unsafeBitCast(-1, to: sqlite3_destructor_type.self)`), `step() -> Bool` (row / done, throws otherwise), `string(at:)`, `int(at:)`, `isNull(at:)`.
- `public struct SQLiteError: Error, CustomStringConvertible` (`code`, `message`).

### 3. Self-contained migrations
`Migrations.swift` holds an ordered, append-only list:
```swift
struct Migration { let version: Int; let apply: (SQLiteConnection) throws -> Void }
let migrations: [Migration] = [
    Migration(version: 1) { try $0.execute(NotesTable.createSQL) },
]
```
`Migrations.run(on:seed:)` runs inside one `transaction`: read `user_version`; apply, in order, every migration whose version is greater; set `user_version` to the last applied version. If `user_version` was 0 (a new database) and a `seed` closure is given, it runs after the migrations and before the commit, so schema and imported notes are committed together or not at all. Any failure rolls everything back, so the next launch retries. A database whose `user_version` is higher than the app knows is opened as is, without changes. Future schema changes append a `Migration` with the next version; nothing outside this file changes.
- *Why in this module*: the schema, the queries, and the migrations change together; keeping them in one place means no caller can see a half-migrated database.

### 4. `notes` table and queries (internal)
`NotesTable` (an `enum` of static functions taking a `SQLiteConnection`) owns the SQL:
```sql
CREATE TABLE notes (
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
- Functions: `selectAll`, `select(id:)`, `insert(_:position:)`, `update(_:)`, `delete(id:)`, `deleteAll`, `nextPosition`. Row decoding is here; a row whose `id` is not a UUID or whose JSON fails to decode yields no note (skipped). Style runs are clamped with the shared `Note` helper that also serves `UserDefaultsNoteRepository`.
- *Alternative*: one `data` JSON column per row. Simpler but barely better than `UserDefaults`. *Alternative*: `list_items`/`style_runs` tables. Faithful but needs joins and reordering logic for no current benefit.

### 5. `NotesDatabase` — the CRUD abstraction (public)
```swift
public final class NotesDatabase {
    public static var defaultURL: URL   // ~/.Notely/db/data.sqlite3
    public init(url: URL = defaultURL, initialNotes: (() -> [Note])? = nil) throws

    public func all() throws -> [Note]                 // ordered by position, unreadable rows skipped
    public func note(id: UUID) throws -> Note?
    public func insert(_ note: Note) throws            // appended after the last position; duplicate id throws
    public func update(_ note: Note) throws            // replaces fields by id, keeps position; unknown id throws
    public func delete(id: UUID) throws                // unknown id is a no-op
    public func replaceAll(_ notes: [Note]) throws     // one transaction, positions follow array order
}
```
`init` opens the connection and calls `Migrations.run(on:seed:)`; `seed` inserts `initialNotes()` only for a new database. Every mutating call runs in its own transaction. `NotesDatabase` is the only type outside the module that touches notes storage; SQL, statements, and the connection never cross its boundary.

### 6. `SQLiteNoteRepository` and legacy import
`public final class SQLiteNoteRepository: NoteRepository` wraps a `NotesDatabase`:
- `load()` returns `database.all()`; an empty table returns `[]` (keeps "delete last note → no notes at next launch"). A read error is written to standard error and `load()` returns `[]`; opening failures never reach `load()` because they throw from `init` and trigger the fallback in Decision 7.
- `save(_:)` calls `database.replaceAll(_:)`. Errors go to standard error; `save` stays non-throwing to keep the protocol.
- `init(url:legacy:)` takes the `UserDefaults` to migrate from and builds `NotesDatabase(url:, initialNotes: { UserDefaultsNoteRepository(defaults: legacy).savedNotes() })`.

The read-only `UserDefaultsNoteRepository.savedNotes() -> [Note]` stays in `NotelyCore`: it returns the decoded `notes` array (clamped), else one note built from `noteText`/`panelOrigin`, else one empty note — and never removes or sets keys. The existing `load()`/`save()` stay unchanged for the fallback.

### 7. Wiring and fallback
`Sources/Notely/main.swift`:
```swift
let repository: any NoteRepository
do { repository = try SQLiteNoteRepository(legacy: .standard) }
catch { /* log */ repository = UserDefaultsNoteRepository(defaults: .standard) }
```
The database file is never deleted or recreated on error.

## Risks / Trade-offs

- [Fallback launch writes to `UserDefaults`, which a later database launch ignores] → changes made only during a fallback launch are not visible once the database works again. Rare (home folder unwritable); logged to standard error. Accepted for this change.
- [Whole-list rewrite on every keystroke] → a few dozen rows in one WAL transaction is sub-millisecond; revisit with per-note `update` calls (already in `NotesDatabase`) only if profiling shows it.
- [WAL adds `data.sqlite3-wal`/`-shm` next to the file] → expected SQLite behavior; a backup should copy the `db` folder, or the app checkpoints on close via `sqlite3_close_v2`.
- [`synchronous=NORMAL` can lose the last transaction on power loss, not on app crash] → same or better durability than `UserDefaults`.
- [Migrations are append-only] → editing a shipped migration would desync existing databases; a new version must be added instead. A test checks a fresh database and a version-0 database reach the same schema.
- [Name similarity: protocol `NoteRepository` vs class `SQLiteNoteRepository`] → doc comments explain the roles.

## Migration Plan

1. Ship: first launch creates `~/.Notely/db/data.sqlite3`, runs migration 1, copies notes, sets `user_version = 1`, in one transaction.
2. `UserDefaults` `notes` stays as a frozen backup.
3. Rollback: installing the previous build reads `UserDefaults` again and shows notes as of the upgrade; changes made after the upgrade live only in the database.
