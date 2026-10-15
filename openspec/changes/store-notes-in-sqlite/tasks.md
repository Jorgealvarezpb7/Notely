# Tasks

Run `swift test` on macOS and `just test-linux` for Linux. App checks use `just run` on the host Mac. Before the first app run, back up notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. SQLite3 on both platforms

- [ ] 1.1 Add `Sources/CSQLite/module.modulemap` (`header "shim.h"`, `link "sqlite3"`) and `Sources/CSQLite/shim.h` (`#include <sqlite3.h>`), and in `Package.swift` add the `CSQLite` system-library target with `providers: [.apt(["libsqlite3-dev"])]` and the `NotelyCore` dependency on it inside `#if os(Linux)` only (design.md Decision 1); verify `swift build` succeeds on macOS and in the dkc container
- [ ] 1.2 Make `just test-linux` install `libsqlite3-dev` before `swift test` (e.g. `bash -c "apt-get update -qq && apt-get install -y -qq libsqlite3-dev && swift test --scratch-path .build/linux"`); verify `just test-linux` runs the existing tests green

## 2. `NotelyRepository` (SQLite3 layer)

- [ ] 2.1 Add `Sources/NotelyCore/Persistence/NotelyRepository.swift` with `open class NotelyRepository`: `homeDirectory`, `defaultDatabaseURL` (`~/.Notely/db/data.sqlite3`), throwing `init(databaseURL:)` that creates parent directories and opens with WAL/`synchronous=NORMAL`, `deinit` close, `SQLiteError`, `execute`, `prepare` + `Statement` (bind/step/column readers, `SQLITE_TRANSIENT`), `transaction`, and `userVersion` (design.md Decision 2); verify `swift build` succeeds
- [ ] 2.2 Add `Tests/NotelyCoreTests/NotelyRepositoryTests.swift` using a temp directory per test: creates missing `db/` folders and the file; reopening keeps existing data; `defaultDatabaseURL` ends in `.Notely/db/data.sqlite3` under the home folder; bind/read round-trips `String`, `Int`, `nil`; `transaction` commits on success and rolls back on throw; `userVersion` persists across reopen; opening a path whose parent is a regular file throws and does not delete it; verify `swift test` passes on macOS and Linux

## 3. `NotesRepository` and the `notes` table

- [ ] 3.1 Move style-run clamping into a shared `Note` helper and add read-only `UserDefaultsNoteRepository.savedNotes()` that decodes `notes`, else builds a note from `noteText`/`panelOrigin`, else one empty note, without writing or removing keys (design.md Decision 4); verify existing `UserDefaultsRepositoryTests` still pass and a new test shows `savedNotes()` leaves every key unchanged
- [ ] 3.2 Add `Sources/NotelyCore/Persistence/NotesRepository.swift`: `final class NotesRepository: NotelyRepository, NoteRepository`, `init(databaseURL:legacy:)` that, when `user_version == 0`, creates the `notes` table, inserts `legacy.savedNotes()`, and sets `user_version = 1` in one transaction; `load()` ordered by `position`, skipping unreadable rows, clamping styles; `save(_:)` as one delete-and-insert transaction, logging errors to standard error (design.md Decisions 3–4); verify `swift build` succeeds
- [ ] 3.3 Add `Tests/NotelyCoreTests/NotesRepositoryTests.swift` (temp database + `TestDefaults`): a note with styles and tint and a list with items, GitHub fields, repo, origin, size, `isOpen = false` round-trip with all fields and order; saving fewer notes leaves only their rows; saving `[]` then reopening loads `[]`; first open migrates `UserDefaults` notes and single-note keys, leaves `UserDefaults` unchanged, and a second open after deleting a note does not bring it back; fresh install yields one empty note and one row; a row with a bad `items` JSON or bad `id` is skipped while others load; a save that fails mid-way (e.g. duplicate ids) leaves the previous rows; verify `swift test` passes on macOS and Linux

## 4. Wiring

- [ ] 4.1 In `Sources/Notely/main.swift`, build `NotesRepository(legacy: .standard)` and fall back to `UserDefaultsNoteRepository(defaults: .standard)` on error, logging the error (design.md Decision 5); verify `just build` succeeds
- [ ] 4.2 Update the doc comment on `NoteRepository` and `UserDefaultsNoteRepository` to describe their roles (protocol vs. legacy/fallback store); verify the comments name `NotesRepository` and `~/.Notely/db/data.sqlite3`

## 5. Integration checks on the Mac

- [ ] 5.1 With existing notes in `UserDefaults` and no `~/.Notely`, run `just run`; verify every note and list opens as before, `sqlite3 ~/.Notely/db/data.sqlite3 'select count(*) from notes'` matches the note count, and `PRAGMA user_version` is 1 (note-storage "Upgrade keeps every note")
- [ ] 5.2 Type in a note, move and resize it, check a list item, delete a note, then quit and relaunch; verify everything is restored and the deleted note has no row (note-storage "Relaunch restores every field and the order", "Deleted note leaves no row")
- [ ] 5.3 Type in a note and `kill -9` the Notely process, then relaunch; verify the text is there (note-storage "Change survives a forced quit")
- [ ] 5.4 Quit, `chmod 000 ~/.Notely/db`, relaunch; verify the app opens with the `UserDefaults` notes and the database file is untouched; then `chmod 755 ~/.Notely/db` (note-storage "Database unavailable")
