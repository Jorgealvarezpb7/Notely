# Tasks

## 1. Close by minimizing

- [x] 1.1 Remove the first attempt (`DockAnimation.swift`, `dockEdgePoint` and its tests, the overlay code in `NoteWindowController`). Verify `just test` passes and `just build` succeeds.
- [x] 1.2 Give note windows `.miniaturizable` with the button still hidden, and change `closeNote` to: detach → `setOpen(false)` → `miniaturize` → close on `didMiniaturize`, closing at once when Reduce Motion is on or the window is already in the Dock. Verify by hand: "−" plays the system minimize effect, then no Dock tile stays; with Reduce Motion on it closes instantly; typing, clicking "−" and quitting at once keeps the text, and the note stays closed after relaunch.

## 2. Reopen by restoring

- [x] 2.1 Add `show:` to `openWindow(for:)`, and change `open(_:)` for closed notes to: show at alpha 0 → `miniaturize` → alpha 1 → `deminiaturize` → make key, opening at once when Reduce Motion is on. Verify by hand: a closed row restores out of the Dock to its saved frame, without a click on the tile, and takes keystrokes.
- [x] 2.2 Check overlaps and skip cases. Verify by hand: double-clicking a closed row opens exactly one window with no tile left; clicking the row during the close animation opens the note once; an open row comes forward with no animation; with Reduce Motion on, reopening is instant; trash → "Delete" closes at once.

## 3. Settings switch

- [x] 3.1 Add `NoteAnimation` (key `animateNotes`, on when nothing is saved), and make close and reopen animate only while it is on and Reduce Motion is off. Verify `just test` passes and `just build` succeeds.
- [x] 3.2 Add the "Windows" section with the "Animate closing and opening notes" switch to `GeneralPane`, bound with `@AppStorage`. Verify by hand: the switch is on at first; turning it off makes "−" and reopening instant at once, also for notes that were already open; it stays off after relaunch; it shows on one line at the Settings window's minimum width.

## 4. Integration check

- [x] 4.1 Run `openspec validate animate-note-close-to-dock --strict` and `just test`, and go through every scenario in this change's `multiple-notes`, `notes-menu` and `settings` deltas on a macOS build. Verify all pass.
