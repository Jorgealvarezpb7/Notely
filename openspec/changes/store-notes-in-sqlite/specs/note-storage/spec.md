# Spec Delta

## Purpose

Keeps every note and list between launches in a SQLite database in the user's Notely home directory, `~/.Notely`, and moves notes saved by earlier versions into it.

## ADDED Requirements

### Requirement: Notes database location
The app SHALL keep notes and lists in a SQLite database file at `~/.Notely/db/data.sqlite3`, where `~` is the current user's home directory. When `~/.Notely`, `~/.Notely/db`, or the database file does not exist, the app MUST create it at launch. Existing files in `~/.Notely` MUST NOT be removed or replaced.

#### Scenario: First launch creates the database
- **WHEN** `~/.Notely` does not exist and the user launches the app
- **THEN** the file `~/.Notely/db/data.sqlite3` exists
- **AND** it is a SQLite database with a table named `notes`

#### Scenario: Existing database is kept
- **WHEN** `~/.Notely/db/data.sqlite3` already holds notes and the user launches the app
- **THEN** the app opens those notes
- **AND** the file is not recreated

### Requirement: One row per note
The `notes` table SHALL hold one row per saved note or list, and no other rows. A row MUST keep everything the note had when saved: its id, kind, text, styles, title, items with their checked state and GitHub fields, tint, linked repository, position, size, and whether its window is open. The order of notes MUST survive a relaunch.

#### Scenario: Notes become rows
- **WHEN** the user has two notes and one list and quits the app
- **THEN** the `notes` table holds exactly three rows, one per note and list

#### Scenario: Relaunch restores every field and the order
- **WHEN** a list with a tint, checked and unchecked items, and a linked repository, and a note with bold text, are saved and the app is relaunched
- **THEN** both open with the same title, items, checked state, text, styles, tint, repository, position, and size
- **AND** the menu lists them in the same order as before

#### Scenario: Deleted note leaves no row
- **WHEN** the user deletes a note and quits the app
- **THEN** the `notes` table has no row with that note's id

### Requirement: Every change saved at once
Each change to a note or list SHALL be written to the database before the change returns, without an explicit save action. A save MUST replace the stored notes as a whole: a failure part-way through MUST leave the notes as they were before that save, never a mix.

#### Scenario: Change survives a forced quit
- **WHEN** the user types in a note and the app is then terminated without a normal quit
- **THEN** the next launch shows the typed text

#### Scenario: Interrupted save
- **WHEN** a save of three notes fails after writing one row
- **THEN** the database still holds the notes as of the previous save

### Requirement: Notes moved from earlier versions
On the first launch that finds no database, the app SHALL copy the notes saved by an earlier version into the new database, with all their fields and order. Notes saved by the single-note version MUST be moved as described for multiple notes. The earlier saved notes MUST be left in place and MUST NOT be written to again. Later launches MUST NOT copy them again.

#### Scenario: Upgrade keeps every note
- **WHEN** an earlier version saved three notes and one list, and the user launches this version for the first time
- **THEN** the same three notes and one list open, with their text, items, position, and size
- **AND** the database holds four rows

#### Scenario: No second copy
- **WHEN** notes were moved at an earlier launch and the user deleted one of them since
- **THEN** the next launch does not bring the deleted note back

#### Scenario: Fresh install
- **WHEN** no earlier version saved notes and the user launches the app for the first time
- **THEN** one empty note opens and the database holds one row

### Requirement: Damaged rows do not lose other notes
A row that cannot be read SHALL be skipped, and every other note MUST still open. Style ranges outside a note's text MUST be trimmed or dropped, as for notes saved before.

#### Scenario: One unreadable row
- **WHEN** the database holds three rows and one of them cannot be read
- **THEN** the other two notes open with their text

### Requirement: Database unavailable
When the database cannot be created or opened, the app SHALL still launch and SHALL keep notes in the storage earlier versions used, so no note or change is lost. The app MUST NOT delete or overwrite the database file it could not open.

#### Scenario: Home folder not writable
- **WHEN** `~/.Notely/db` cannot be created and the user launches the app
- **THEN** the notes saved by the earlier storage open
- **AND** changes made in this launch are there at the next launch
