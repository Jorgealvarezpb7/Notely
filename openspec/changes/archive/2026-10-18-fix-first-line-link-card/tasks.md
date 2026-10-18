# Tasks

## 1. Room for the first paragraph's card

- [x] 1.1 In `Sources/NotelyUI/Editor/NoteTextView.swift`, add a `topRoom` value: the card room of the paragraph at location 0 plus `LinkCardLayout.gap`, or 0 when it has no card
- [x] 1.2 Override `textContainerOrigin` to return `super`'s origin moved down by `topRoom`
- [x] 1.3 In `textContentStorage(_:textParagraphWith:)`, return `nil` (no `paragraphSpacingBefore`) for the paragraph at location 0
- [x] 1.4 Update `topRoom` in `relayoutCards()` and reset it with `cardRooms` in `didChangeText()`. When it changes, mark layout and display as needed and re-size the frame, so the text moves at once

## 2. Verify on the macOS host (`just dev`)

- [x] 2.1 New note: type "apple.com" as the first thing. The card shows fully at the top, with "apple.com" directly below it
- [x] 2.2 Delete the link on line 1. The card disappears and the line moves back to the top
- [x] 2.3 Note with "apple.com" on line 1 and "crunchyroll.com" on line 3: both cards show, each above its line
- [x] 2.4 Long note that starts with a link and is taller than its window: scroll to the end. The last line is not cut off. (`setFrameSize` already grows the frame by `topRoom`; if still cut off, fall back to `textContainerInset` per design.md Risks)
- [x] 2.5 Click, select, type, and Cmd+click the link on line 1: the caret, selection, and link open at the right place
- [x] 2.6 Resize the note: the first card keeps its room and width
- [x] 2.7 Run `just test` (no regressions)
