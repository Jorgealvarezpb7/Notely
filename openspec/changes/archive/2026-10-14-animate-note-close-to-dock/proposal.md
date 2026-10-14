# Proposal

## Why

Clicking "−" on a note makes its window vanish at once, and reopening it from the menu makes it pop back with no transition. The user cannot see where the note went or where it came from. Playing the system's own minimize animation into the Dock, as native apps do, shows that the note is put away, not lost.

## What Changes

- Clicking "−" on a note minimizes its window into the Dock with the system's own animation (Genie or Scale, as set in System Settings), then closes the note as today. The note's Dock tile disappears at once.
- The note lands where macOS puts minimized windows: next to the Trash, or in the Notely Dock icon when the user has "Minimize windows into application icon" on. The app needs no permission.
- Clicking a closed note's row in the menu plays the system's restore animation out of the Dock to the note's saved frame, then makes the note the key window.
- With the system "Reduce motion" setting on, closing and reopening stay instant.
- Settings → General gets a "Windows" section with an "Animate closing and opening notes" switch, on by default, to turn both animations off from inside the app.
- Not animated: deleting a note (trash → "Delete"), notes opened at launch, new notes from "+ New", and rows of notes that are already open.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `multiple-notes`: adds a requirement that closing a note with "−" plays the system minimize animation, and that deleting stays instant.
- `notes-menu`: adds a requirement that opening a closed note from its row plays the system restore animation.
- `settings`: adds the "Animate closing and opening notes" switch to the General pane.

## Impact

- `Sources/NotelyUI/App/NoteWindowController.swift`: note windows get the minimize style (their buttons stay hidden). `closeNote` minimizes, then closes; `open` restores a closed note out of the Dock. `removeNote`, `openSavedWindows` and `add` are unchanged.
- `Sources/NotelyUI/Settings/GeneralPane.swift`: the new "Windows" section and switch, saved in `UserDefaults` under its own key, apart from `notes`.
- No new dependencies, no change to the saved notes, and no permission prompt.
