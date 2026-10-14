# Tasks

How to verify:
- `NotelyCore` work is checked with `just test`, and on Linux with `just test-linux`.
- Network and UI work is checked on the macOS host with `just run`, against a scratch repository you own, for example `<you>/notely-sync-test`.
- Watch the log while checking: `log stream --predicate 'subsystem == "com.alvarezjorge.Notely"' --level info`.
- Before starting:
  - Archive `add-github-integration`, then `sync-github-issues`. Tick their tasks first, against the code already on `main`.
  - Back up the notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Body model and sync rules (NotelyCore)

- [x] 1.1 Add `body`, `remoteBody`, and `heldBody` to `ListItem` with `nil` defaults, and `body` to `RemoteIssue` (design.md Decision 1). Add `IssueSync.normalizedBody(_:)`: `nil` reads as `""`, and `\r\n` becomes `\n`.
  - Add a `ModelTests` case showing that items saved by `sync-github-issues` decode with the three fields `nil`.
  - Add normalization tests for `nil`, CRLF, and lone CR.
  - Verify `just test` passes.
- [x] 1.2 Add `PendingChange.editBody`, derived in `IssueSync.pendingChanges(in:focused:editingBody:)`. Skip items with a held body and the item being edited. Add `NoteStore.setItemBody(_:item:for:)` and `NoteStore.resolveConflict(item:for:keepMine:)` (Decision 3).
  - Tests:
    - a body difference is a change
    - CRLF-only differences are not
    - held and edited items are skipped
    - "Keep mine" leaves a waiting change
    - "Use GitHub's" leaves none
  - Verify `just test` passes.
- [x] 1.3 Add `IssueSync.bodyDecision(item:github:)` returning `.send`, `.alreadyThere`, or `.hold` (Decision 2). Extend `IssueSync.applied` so a body response sets `remoteBody`.
  - Add a test for each decision.
  - Verify `just test` passes.
- [x] 1.4 Extend `IssueSync.merge` and `IssueSync.resolve` for bodies (Decision 4).
  - Tests:
    - GitHub's body replaces an idle item's body
    - it does not replace an item with a waiting body change, a held body, or the body being edited
    - a held body follows GitHub's latest body
    - a held body equal to the user's ends the conflict
    - a missing `remoteBody` is seeded without a change
  - Verify `just test` passes.
- [x] 1.5 Add `SyncResult` and `SyncStatus.visible(result:at:now:waiting:)` (Decision 7).
  - Tests: a check is shown before 60 s and hidden after; an x is shown while waiting at any age; an x with nothing waiting is hidden after 60 s.
  - Verify `just test` and `just test-linux` pass.

## 2. Markdown parser (NotelyCore)

- [x] 2.1 Add `MarkdownBlocks.parse(_:)` with the blocks of design.md Decision 5.
  - Tests:
    - headings 1–6, and `#x` with no space as a paragraph
    - bullets with `-`, `*`, and `+`, with nesting depth
    - numbered items with `.` and `)`
    - task items `[ ]`, `[x]`, and `[X]`
    - a fenced code block with a language
    - an unclosed fence
    - a table and an image kept as paragraph text
    - blank-line collapsing
  - Verify `just test` and `just test-linux` pass.

## 3. GitHub client (NotelyGitHub)

- [x] 3.1 Add `body` to `IssueService.create` and `update`, and update `FakeIssueService`. In `GitHubClient`, decode `body` (`null` reads as `""`, then normalized), send `body` on create when it isn't empty, and send it on update when given. Do not log bodies (Decision 9).
  - Verify `just test` passes.
  - Then verify in task 5.4, with `log stream`, that no description text appears.

## 4. Sync controller

- [x] 4.1 Add `editingBody` to `SyncController`, and pass it to `pendingChanges` and `merge`.
  - Send `.editBody` with the guarded `GET` then `PATCH` (Decision 2).
  - On `.hold`, set `heldBody` and log `Held description of #n` with no body text.
  - Send `body` on create.
  - Verify the issue-descriptions scenarios "Change sent", "Description with a new item", and "Edited on GitHub" against the scratch repo.
- [x] 4.2 Set `ListState.result` and `resultAt` at the end of every run, full or push, by the rules of Decision 7. On `markTokenRejected()`, set the token failure on every linked list.
  - Verify the sync-status scenarios "Refresh worked", "Change sent", "Partial success", "Offline" (turn Wi-Fi off), and "Token rejected".
  - For "Partial success", rename one item normally and one whose issue was deleted on GitHub.

## 5. Description UI

- [x] 5.1 Add the trailing description icon (`text.alignleft`) to linked rows in `ListView`. It always shows with a body, shows on hover without one, and is laid out at opacity 0 otherwise. It is a plain button that doesn't take focus.
  - Verify "Item with a description", "Item without a description", and "Unlinked list".
  - Verify that clicking the icon while editing another item keeps that item's text intact.
- [x] 5.2 Add `MarkdownView`, which renders `MarkdownBlock`s with inline `AttributedString(markdown:)` and falls back to plain text. Code blocks use a monospaced font, task boxes are not interactive, links open in the browser, and an empty body shows "No description".
  - Verify "Lists and headings", "Task list", and "Table stays raw" with a scratch issue that has each.
- [x] 5.3 Add `DescriptionControls` and `DescriptionPopover` with the view, edit, and held states (Decision 6):
  - "Edit" only when `isEditable`.
  - Edit mode sets and clears `editingBody`.
  - "Done" or closing the popover calls `itemsChanged`.
  - "Keep mine" and "Use GitHub's" call `resolveConflict`, then `itemsChanged`.
  - Verify:
    - "Edit and finish"
    - "Read-only issue", with the second GitHub account from `sync-github-issues` task 5.2
    - "Conflict found": edit on GitHub while the popover is in edit mode, then click "Done"
    - "Keep mine" and "Use GitHub's"
- [x] 5.4 Verify "Log without descriptions" and "Line breaks only". For the second, edit the scratch issue's body on github.com, refresh, then refresh again: the log shows no `PATCH`.

## 6. Status icon and shortcuts

- [x] 6.1 In `BottomBar`, delete the badge overlay. After the refresh button, add the result icon (`checkmark` / `xmark`) in a `TimelineView(.periodic(from: .now, by: 5))`, with `SyncStatus.visible`, a 0.3 s fade, and the reason as an AppKit tooltip (`NSImageView.toolTip`) on the x. Hide it while syncing.
  - Verify "Offline tooltip", "Check fades", "X stays while changes wait", "X clears after sending", "Refused change fades", and "After relaunch".
  - Verify the issue-sync scenarios "Check while offline" and "Revoked token".
  - Not tested: "Revoked token" (and with it the x on every linked list at launch while the token is rejected). It is checked in task 7.1 instead.
- [x] 6.2 Add the GitHub menu to `MainMenu` with Description (Cmd+D), Refresh Issues (Cmd+R), and Link to Repository… (Cmd+L). Route the items through the key window's `NoteWindow` to its `ListCommands`, with `validateMenuItem` (Decision 8).
  - Verify "Shortcut on a focused item", "Shortcut on the item under the pointer", "Refresh with the keyboard", "Link with the keyboard", "Shortcut on a linked list", "Shortcut closes the popover", "Shortcut closes what it opened", and "Note window in front".
  - Verify that Cmd+B/I/U in a note window still work.

## 7. Integration check

- [ ] 7.1 Do a full round while streaming the log:
  - link a list
  - add an item with a description
  - edit a description
  - force a conflict and resolve it both ways
  - check an item offline, watch the x stay, reconnect, and watch the check appear and fade
  - revoke and reconnect the token
- [ ] 7.2 Restore the backup from before group 1. Verify that every note and list opens unchanged, and that descriptions fill in at the first refresh without any `PATCH` in the log.
- [ ] 7.3 Run `openspec validate add-issue-descriptions-and-sync-status --strict`, `just test`, and `just test-linux`, and verify all pass.

## Workflow follow-up

- Archive this change after `sync-github-issues` is archived, so the `issue-sync` and `github-integration` deltas apply to existing specs.
