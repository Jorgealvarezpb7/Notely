# Proposal

## Why

When a note's first paragraph has a web address, for example when the first thing the user types in a new note is a link, its preview card is placed above the top of the note and cannot be seen. TextKit does not apply the room the card asks for (`paragraphSpacingBefore`) to the first paragraph of the text, so the card is placed at a negative y, above the text view's bounds. Cards on any later paragraph show correctly, and lists are not affected because a list's name always sits above its first item.

## What Changes

- A note whose first paragraph has a link SHALL leave room for the card at the top of the note, so the card shows fully inside the note above that line, as it does for every other paragraph.
- The text below moves down by the card's height when the card appears and moves back up when the link is removed, as for other paragraphs.
- No change to the saved text, styles, undo, copy, link hit-testing, or lists.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `links`: the "Preview card above a paragraph with a link" requirement now states that a note's first paragraph gets its card too, fully visible, with scenarios for a link on the first line and for removing it.

## Impact

- `Sources/NotelyUI/Editor/NoteTextView.swift`: room for the first paragraph's card at the top of the text, and card placement and link hit-testing must agree with it.
- No changes to `NotelyCore`, storage, or lists (`Sources/NotelyUI/Lists`).
