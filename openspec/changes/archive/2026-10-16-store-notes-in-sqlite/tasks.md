# Tasks

Run `swift test` on macOS. App checks use `just run` on the host Mac. Before the first app run, back up notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. `NotelySQLite` module and connection layer

- [ ] 1.1 In `Package.swift` add the `NotelySQLite` target (depends on `NotelyCore`, path `Sources/NotelySQLite`), the `NotelySQLiteTests` target (depends on `NotelySQLite` and `NotelyCore`, path `Tests/NotelySQLiteTests`), and `NotelySQLite` in the `Notely` executable's dependencies; `NotelyCore` must not import `SQLite3` (design.md Decision 1); verify `swift build` succeeds
- [ ] 1.2 Move `Sources/NotelyCore/Persistence/NotelyRepository.swift` to `Sources/NotelySQLite/SQLiteConnection.swift` and reshape it into the internal `SQLiteConnection` (no subclassing): `init(url:)` that creates parent directories and opens with WAL/`synchronous=NORMAL`, `deinit` close, public `SQLiteError`, `execute`, `prepare` + `Statement` (bind/step/column readers, `SQLITE_TRANSIENT`), `transaction`, and `userVersion` (design.md Decision 2); verify `swift build` succeeds
- [ ] 1.3 Move the connection tests to `Tests/NotelySQLiteTests/SQLiteConnectionTests.swift` (`@testable import NotelySQLite`) using a temp directory per test: creates missing `db/` folders and the file; reopening keeps existing data; bind/read round-trips `String`, `Int`, `nil`; `transaction` commits on success and rolls back on throw; `userVersion` persists across reopen; opening a path whose parent is a regular file throws and does not delete it; verify `swift test` passes

## 2. Migrations and the `notes` table

- [ ] 2.1 Move style-run clamping into a shared `Note` helper in `NotelyCore` and add read-only `UserDefaultsNoteRepository.savedNotes()` that decodes `notes`, else builds a note from `noteText`/`panelOrigin`, else one empty note, without writing or removing keys (design.md Decision 6); verify existing `UserDefaultsRepositoryTests` still pass and a new test shows `savedNotes()` leaves every key unchanged
- [ ] 2.2 Add `Sources/NotelySQLite/Migrations.swift`: the ordered `migrations` list with migration 1 creating the `notes` table, and `Migrations.run(on:seed:)` that applies pending migrations, runs `seed` only for a new database, and sets `user_version`, all in one transaction (design.md Decision 3); verify `swift build` succeeds
- [ ] 2.3 Add `Sources/NotelySQLite/NotesTable.swift` with every `notes` query: create SQL, `selectAll`, `select(id:)`, `insert(_:position:)`, `update(_:)`, `delete(id:)`, `deleteAll`, `nextPosition`, and row decoding that skips unreadable rows and clamps style runs (design.md Decision 4); verify `swift build` succeeds
- [ ] 2.4 Add `Tests/NotelySQLiteTests/MigrationsTests.swift`: a new database ends at the latest `user_version` with the `notes` table; reopening does not rerun migrations; a failing migration or seed leaves `user_version` 0 and no table; the `seed` runs only for a new database; a database with a newer `user_version` opens untouched; verify `swift test` passes

## 3. CRUD abstraction and repository adapter

- [ ] 3.1 Add `Sources/NotelySQLite/NotesDatabase.swift`: public `NotesDatabase` with `defaultURL` (`~/.Notely/db/data.sqlite3`), `init(url:initialNotes:)` that opens and migrates, and `all`, `note(id:)`, `insert`, `update`, `delete(id:)`, `replaceAll`, each mutation in its own transaction (design.md Decision 5); verify `swift build` succeeds
- [ ] 3.2 Add `Tests/NotelySQLiteTests/NotesDatabaseTests.swift` (temp database): `defaultURL` ends in `.Notely/db/data.sqlite3` under the home folder; `insert` appends and a duplicate id throws; `note(id:)` returns the note or `nil`; `update` changes fields, keeps position, and throws for an unknown id; `delete` removes the row and ignores an unknown id; a note with styles and tint and a list with items, GitHub fields, repo, origin, size, `isOpen = false` round-trip with all fields and order; `replaceAll` fewer notes leaves only their rows, `replaceAll([])` then reopen loads `[]`, and a `replaceAll` that fails mid-way (duplicate ids) leaves the previous rows; a row with a bad `items` JSON or bad `id` is skipped while others load; verify `swift test` passes
- [ ] 3.3 Add `Sources/NotelySQLite/SQLiteNoteRepository.swift`: `SQLiteNoteRepository: NoteRepository` over `NotesDatabase` (`load` → `all`, `save` → `replaceAll`, errors to standard error) and `init(url:legacy:)` seeding from `UserDefaultsNoteRepository(defaults:).savedNotes()` (design.md Decision 6); verify `swift build` succeeds
- [ ] 3.4 Add `Tests/NotelySQLiteTests/SQLiteNoteRepositoryTests.swift` (temp database + `TestDefaults`): first open migrates `UserDefaults` notes and single-note keys, leaves `UserDefaults` unchanged, and a second open after deleting a note does not bring it back; fresh install yields one empty note and one row; `save` then `load` round-trips; verify `swift test` passes
- [ ] 3.5 Delete `Sources/NotelyCore/Persistence/NotesRepository.swift` and the old `NotelyRepositoryTests.swift` / `NotesRepositoryTests.swift` after their cases are covered by sections 1–3; verify `swift build` and `swift test` pass and `grep -rn SQLite3 Sources` matches only `Sources/NotelySQLite`

## 4. Wiring

- [ ] 4.1 In `Sources/Notely/main.swift`, build `SQLiteNoteRepository(legacy: .standard)` and fall back to `UserDefaultsNoteRepository(defaults: .standard)` on error, logging the error (design.md Decision 7); verify `just build` succeeds
- [x] 4.2 Update the doc comment on `NoteRepository` and `UserDefaultsNoteRepository` to describe their roles (protocol vs. legacy/fallback store); verify the comments name `SQLiteNoteRepository` and `~/.Notely/db/data.sqlite3`
- [x] 4.3 Update the `CLAUDE.md` architecture section: five library targets, with `NotelySQLite` described as the SQLite3 connection, migrations, `notes` queries, CRUD `NotesDatabase`, and `SQLiteNoteRepository`; verify the text matches `Package.swift`

## 5. Integration checks on the Mac

- [ ] 5.1 With existing notes in `UserDefaults` and no `~/.Notely`, run `just run`; verify every note and list opens as before, `sqlite3 ~/.Notely/db/data.sqlite3 'select count(*) from notes'` matches the note count, and `PRAGMA user_version` is 1 (note-storage "Upgrade keeps every note")
- [ ] 5.2 Type in a note, move and resize it, check a list item, delete a note, then quit and relaunch; verify everything is restored and the deleted note has no row (note-storage "Relaunch restores every field and the order", "Deleted note leaves no row")
- [ ] 5.3 Type in a note and `kill -9` the Notely process, then relaunch; verify the text is there (note-storage "Change survives a forced quit")
- [ ] 5.4 Quit, `chmod 000 ~/.Notely/db`, relaunch; verify the app opens with the `UserDefaults` notes and the database file is untouched; then `chmod 755 ~/.Notely/db` (note-storage "Database unavailable")
