# Design

## Context

See proposal.md for the motivation. The requirements are in `specs/issue-descriptions`, `specs/sync-status`, `specs/issue-sync`, and `specs/github-integration`.

What `sync-github-issues` left in place:
- `ListItem` keeps the last GitHub state (`remoteTitle`, `remoteClosed`, `issueAuthor`). A waiting change is any difference from it (`IssueSync.pendingChanges`).
- `SyncController` runs the steps `IssueSync` computes, per list, with `ListState { isRunning, message }`.
- `BottomBar` shows the GitHub button with the orange badge, and the refresh button, which a spinner replaces while a sync runs.
- `RepositoryPicker` is a SwiftUI view in an `NSPopover` owned by `GitHubControls`.
- `IssueService.update(_:number:title:closed:)` and `create(_:title:assignees:)`.

Constraints are unchanged:
- `NotelyCore` is Foundation-only and tested on Linux.
- `NoteStore` is changed on the main thread and saved at once.
- No third-party dependencies.

## Goals / Non-Goals

**Goals:**
- Fit descriptions into the existing state-diff sync, with no operation queue.
- Keep the Markdown parser and the conflict rules in `NotelyCore`, tested without UI or network.
- Derive the result icon from state `SyncController` already has, plus one result per list.

**Non-Goals:**
- Clicking task-list boxes to change the description.
- Tables, images, blockquotes, HTML, nested emphasis edge cases, or full CommonMark conformance.
- A live preview while editing.
- Descriptions on unlinked lists, or in the list's plain-text copy.

## Decisions

### 1. Three body fields on `ListItem`

Every new field is optional, so saved notes decode unchanged:
- `body: String?`: the description as the user sees it.
- `remoteBody: String?`: the description as last seen on GitHub.
- `heldBody: String?`: GitHub's description while a conflict is held, `nil` otherwise.

Compare bodies with `nil` read as `""`, and line endings normalized to `\n`. GitHub stores bodies edited on the web with `\r\n`. `IssueSync.normalizedBody(_:)` is applied when decoding a `RemoteIssue` and when the user's text is saved.

A body change is waiting when `body != remoteBody`, `heldBody == nil`, and the body is not being edited. That is a new `PendingChange.editBody(item, number, body)`.

*Alternative: one `descriptionDirty` flag.* Rejected: it breaks the "a waiting change is a difference" rule, and a flag can go stale.

### 2. Guarded body send

The send step in `SyncController.push` handles `.editBody` in two requests:

```
 GET /issues/{n}  -> github = normalized body
   github == remoteBody   -> PATCH {body} -> remoteBody = response body
   github == body         -> remoteBody = github  (already there, nothing sent)
   otherwise              -> heldBody = github    (conflict, nothing sent)
```

`IssueSync.bodyDecision(item:github:)` returns `.send`, `.alreadyThere`, or `.hold`, and is unit tested. A 403, 404, or 410 on the `GET` drops the change, as for titles.

The window between `GET` and `PATCH` is tens of milliseconds. A GitHub edit inside it is lost. That is accepted (see Risks).

A create sends `body` with the title: `create(_:title:body:assignees:)`. Creates are not guarded, because no one else has seen the issue yet.

### 3. Conflict resolution

`NoteStore` gains `resolveConflict(item:for:keepMine:)`:
- **Keep mine**: `remoteBody = heldBody`, then `heldBody = nil`. The difference is now a normal waiting change, and `SyncController.itemsChanged` sends it. The guard runs again, so a third edit on GitHub meanwhile is held again instead of overwritten.
- **Use GitHub's**: `body = heldBody`, `remoteBody = heldBody`, then `heldBody = nil`.

In merge (refresh step 4), an item with `heldBody != nil` gets `heldBody` updated to the latest GitHub body. When that equals `body`, the conflict ends by itself: `remoteBody = body`, `heldBody = nil`.

### 4. Merge rules for bodies

`IssueSync.merge` takes each shown issue's body by these rules (`IssueSync.mergeBody`):
- Being edited: `body` is untouched, and `remoteBody` is only seeded when it is `nil`. The send step's `GET` does the check.
- Held: `heldBody` follows GitHub's latest. When that equals `body`, the conflict ends.
- Waiting:
  - When GitHub's body equals `body`, it is in step: `remoteBody` takes it.
  - When it equals `remoteBody`, the change stays waiting.
  - Otherwise both sides changed, and it is held.
- Otherwise: `body` and `remoteBody` take GitHub's.

`remoteBody` must not move to GitHub's while a change waits. Otherwise the guard in Decision 2 would see GitHub "unchanged" and overwrite an edit made there. For the same reason, `IssueSync.applied` moves `remoteBody` only after a create or a body change, never after a rename, close, or reopen response.

"Being edited" is a second focus, `SyncController.editingBody: [UUID: UUID]`, list to item, passed to `merge` and `pendingChanges` next to `focused`. The issue list endpoints already return `body`, so no requests are added. The ask step (step 5) takes the body from its `GET` the same way.

### 5. Markdown: a block parser in `NotelyCore`, inline styles from Foundation

`MarkdownBlocks.parse(_ text: String) -> [MarkdownBlock]` is a line-based parser:

```
 heading(level, text)            "#".."######" + space
 bullet(depth, text)             "-", "*", "+" + space, depth by indent / 2
 numbered(depth, number, text)   digits + "." or ")" + space
 task(depth, checked, text)      bullet + "[ ]" / "[x]" / "[X]"
 code(language?, text)           ``` fence to ``` fence, or to the end
 paragraph(text)                 consecutive other lines, joined by \n
 blank                           collapses
```

Anything else, including tables, images, quotes, and HTML, is a paragraph shown as written. The UI renders each block's `text` with `AttributedString(markdown:options: .inlineOnlyPreservingWhitespace)` for bold, italic, inline code, and links. When that throws, it falls back to plain text. Code blocks skip inline parsing and use a monospaced font.

*Alternative: a Markdown package (swift-markdown, Down).* Rejected: no third-party dependencies, and the agreed subset is small. *Alternative: Foundation's full-Markdown option.* Rejected: on macOS it parses blocks but leaves layout to the caller as presentation intents, which is the same work with less control.

### 6. Popover

`DescriptionControls` (class, `@MainActor`) is per list window, like `GitHubControls`, and owns one `NSPopover` with `.transient` behavior. It hosts `DescriptionPopover` (SwiftUI) with three states:

```
 view    rendered blocks, "Edit" (when editable)
 edit    TextEditor, raw text, monospaced off, "Done"
 held    "Description changed on GitHub", GitHub's rendered body,
         "Keep mine" / "Use GitHub's"  (shown above view/edit)
```

- **Edit**: entering edit mode sets `editingBody` and copies `body` into a draft, `DescriptionControls.draft`, which the `TextEditor` binds to. Typing changes only the draft: nothing is saved and the list does not re-render. Editing ends with "Done", the popover closing, or another item's popover opening. When it ends, `NoteStore.setItemBody(draft)` runs first, then `editingBody` is cleared and `SyncController.itemsChanged` starts the 0.5 s push debounce. The draft lives in the controller, not in view `@State`, so `closed()` can store it.
- **Conflict while editing**: "Use GitHub's" also replaces the draft, so the next "Done" does not overwrite the choice.
- **Opening**: opening a second item's popover closes the first, which ends its editing.
- **Anchor**: the row's description icon is laid out on every linked row, at opacity 0 when hidden, so Cmd+D and the hover state have an anchor. It is a plain button, like `CheckCircle`, so clicking it does not take focus from the item.
- **Rights**: rights come from `SyncController.isEditable`, unchanged.

### 7. Sync result

`ListState` gains:

```swift
enum SyncResult { case ok, failed(String) }
var result: SyncResult?
var resultAt: Date?
```

`run(_:full:)` sets the result once at its end, for full refreshes and pushes alike:
- `.failed(reason)` when:
  - the run threw
  - any change was dropped
  - a body was held
  - the token is rejected
- `.ok` otherwise, when `pendingCount == 0` and no item is held.
- `.failed("<n> changes not sent yet")` when changes are still waiting after an otherwise clean run, for example a change made during the sync.

The reason is the same string the menu shows: `IssueServiceError.reason`, the dropped-change message, or "Description changed on GitHub".

Visibility is a pure function in `NotelyCore`, `SyncStatus.visible(result:at:now:waiting:)`:
- `.ok`: shown while `now < at + 60`.
- `.failed`: shown while `waiting > 0`, or while `now < at + 60`.
- `waiting` counts pending plus held changes.

`BottomBar` wraps the icon in `TimelineView(.periodic(from: .now, by: 5))`. The fade is a 0.3 s opacity transition, and visibility is re-read every 5 s, so the icon leaves within 5 s of its minute. The x is an AppKit `NSImageView` with `toolTip = reason`: SwiftUI's `.help` showed no tooltip inside the timeline in the bar's overlay.

When `markTokenRejected()` runs, `SyncController` sets `.failed("GitHub token no longer works")` on every linked list. Lists that never synced this launch show nothing until their next sync, which is paused while the token is rejected, so this step is what covers them.

The badge overlay in `BottomBar.gitHubButtons` is deleted.

*Alternative: a `Task.sleep(60)` per list that clears the result.* Rejected: the "stays while waiting" rule depends on live state, which a timeline reads for free.

### 8. Menu-bar GitHub menu

`MainMenu` adds a "GitHub" menu with Description (Cmd+D), Refresh Issues (Cmd+R), and Link to Repository… (Cmd+L). The items have no target, so the responder chain sends them to the key window. `NoteWindow` answers them through its weak `listCommands`, a `ListCommands` object that each list window's `ListView` creates and installs with `ListCommandsInstaller`. `ListView` and `BottomBar` fill in its closures from the window's `SyncController`, `DescriptionControls`, and `GitHubControls`. `NoteWindow.validateMenuItem` applies the enable rules from the spec. Note windows have no `listCommands`, so the items are disabled there. Link opens the picker through `GitHubControls.showPicker` at the window's GitHub button. `GitHubControls` keeps that button as a weak reference, set when `StripButton` makes it, so Cmd+L works before the button is ever clicked. On a linked list, Cmd+L opens the button's menu ("Open on GitHub", "Unlink") there instead of the picker, so a linked list is never relinked in place.

Cmd+D targets the focused item, or else the row under the pointer. `DescriptionControls.hoveredItem` tracks that row; it also drives the icon's hover state.

*Alternative: route the items through `AppDelegate`.* Rejected: the key window already sits in the responder chain, so `AppDelegate` would only look up the same window's controls again.

None of D, R, or L is used in `MainMenu` today. A focused `NSTextView`/`NSTextField` has no default Cmd+D, Cmd+R, or Cmd+L binding, and menu key equivalents are matched first.

### 9. Client changes

`GitHubClient`:
- Decodes `body` (`null` reads as `""`) into `RemoteIssue.body`.
- `create` sends `body` when it isn't empty.
- `update` gains `body: String?`.
- Log lines keep the method, path, status, and timing only. Bodies are never interpolated, not even as private values.

## Risks / Trade-offs

- **[Race between GET and PATCH]** A GitHub edit in that window is overwritten. → Accepted. The window is milliseconds, and `remoteBody` is set from the `PATCH` response, so the next refresh shows what GitHub holds.
- **[Large bodies in `UserDefaults`]** GitHub allows 65,536 characters per body. 50 linked items with long descriptions add a few MB to the notes plist, written on every change. → Accepted for now. A 422 on a body over the limit drops the change, with "Not accepted: …" in the menu.
- **[Partial Markdown]** Users who write tables or nested quotes see raw text. → Shown as written, which stays readable. "Edit" always shows the exact source.
- **[x stays offline for a long time]** An offline Mac with a waiting change shows the x until it reconnects. → Intended: the change is not on GitHub.
- **[Cmd+D in the editor]** If a future text feature wants Cmd+D (duplicate line, for example), it collides. → The shortcut is defined in one place, `MainMenu`.

## Migration Plan

- `body`, `remoteBody`, and `heldBody` decode as `nil`. The first merge seeds `remoteBody` and `body` from GitHub, and no change is sent.
- Rollback: earlier builds ignore the three fields, and drop them the next time they save the notes. Description edits not yet sent, and held conflicts, are lost. Descriptions already on GitHub come back at the first refresh after updating again.
