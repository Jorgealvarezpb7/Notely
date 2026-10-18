# Design

## Context

`NoteTextView` (TextKit 2, `textContainerInset = .zero`) makes room for a card by returning, from `textContentStorage(_:textParagraphWith:)`, a paragraph whose `paragraphSpacingBefore` is the card height plus `LinkCardLayout.gap`. `placeCards()` then puts the card at `textContainerOrigin.y + lineTop - gap - height`. AppKit's text layout does not apply space-before to the first paragraph of the text, so paragraph 0 gets no room: `lineTop` is 0 and the card's y is negative, above the view's bounds. See proposal.md - Why.

Link hit-testing (`Links.swift`, `characterIndexForInsertion`, `firstRect(forCharacterRange:)`) and the placeholder (`draw(_:)`) already go through `textContainerOrigin`, so they follow any change to it.

## Goals / Non-Goals

**Goals:**
- The first paragraph's card gets its room from the text view, not from paragraph spacing, so the result does not depend on how TextKit treats the first paragraph.
- Card placement, caret, selection, and link clicks stay in step with the shifted text.

**Non-Goals:**
- Lists (`ListField`, list rows): the list name always sits above the first item, so they are not affected.
- Any change to the saved text, styles, or undo.

## Decisions

**1. Top room through an overridden `textContainerOrigin`.** `NoteTextView` keeps a `topRoom` value: the card room of the paragraph at location 0 (`cardRooms[0]` plus `LinkCardLayout.gap`), or 0 when that paragraph has no card. `textContainerOrigin` returns `super`'s origin moved down by `topRoom`. `placeCards()` needs no new math: with the origin moved, the first card's y becomes `topRoom - gap - height = 0`.
- Alternative: set `textContainerInset.height` to the room. Rejected as first choice: the inset applies to top and bottom alike, so the note would get the same empty space below its last line.
- Alternative: a custom `NSTextLayoutFragment` that reports extra top space. Rejected: much more code for one paragraph.

**2. No `paragraphSpacingBefore` for the paragraph at location 0.** The delegate method leaves the first paragraph's style as stored, so if a future macOS starts applying space-before to the first paragraph, the room is not added twice. Other paragraphs keep the current mechanism.

**3. `topRoom` is updated in `relayoutCards()`.** It is computed there with `cardRooms`, after a page arrives, after an edit, and after a width change. When it changes, the view invalidates its layout and size (`needsLayout`, `needsDisplay`, and re-sizing the frame to the text), so the text moves at once without waiting for another event. `didChangeText()` already resets `cardRooms`, and `topRoom` is reset with it. So a removed link moves the first line back up.

## Risks / Trade-offs

- [NSTextView's vertical sizing may not count the overridden origin, so the last line of a note taller than its window could be cut off by `topRoom`.] → Check on the Mac with a long note that starts with a link. If it is cut off, add `topRoom` to the height in the existing `setFrameSize(_:)` override while the view is vertically resizable. If that is fragile, fall back to the `textContainerInset` alternative and accept the extra bottom space.
- [Caret, selection, or Cmd+click on the first line could be off by `topRoom` if some AppKit path ignores the override.] → These APIs all read `textContainerOrigin`. Check each one on the Mac: click, select, Cmd+click the link, and type on line 1.
- [There is no NotelyUI test target, so the fix cannot be unit tested.] → Verify by hand on the macOS host with `just dev`.
