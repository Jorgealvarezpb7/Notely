# Tasks

How to verify:
- `NotelyCore` work is checked with `just test`, and on Linux with `just test-linux`.
- Network and UI work is checked on the macOS host with `just run`, against a scratch repository you own, for example `<you>/notely-sync-test`.
- Watch the log while checking: `log stream --predicate 'subsystem == "com.alvarezjorge.Notely"' --level info`.
- Before starting:
  - Archive `add-github-integration` once its checks pass.
  - Back up the notes with `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Sync model and rules (NotelyCore)

- [x] 1.1 Add `remoteTitle: String?`, `remoteClosed: Bool?`, and `issueAuthor: String?` to `ListItem`, with `nil` defaults (design.md Decision 2).
  - Add a `ModelTests` case showing that items saved by `add-github-integration` decode with the three fields `nil`.
  - Verify `just test` passes.
- [x] 1.2 Add the values `RemoteIssue` (number, title, closed, author, assignees, isPullRequest), `RepoAccess` (canTriage, canPush, hasIssues), and `PendingChange` (create, rename, close, reopen), plus `IssueSync.pendingChanges(in:focused:)`. It derives changes from the item fields and skips the focused item for create and rename.
  - Add tests for each kind of change, for an item with no change, and for the focused item.
  - Verify `just test` passes.
- [x] 1.3 Add `IssueSync.merge(items:shown:focused:)` (design.md Decision 3, step 4). It returns the new items and the issue numbers to ask about.
  - Tests:
    - a new issue is appended
    - a title changed on GitHub updates the item, but not the focused item or one with a waiting rename
    - an issue reopened elsewhere unchecks its item
    - unchecked items missing from the set are asked about
    - a missing `remoteTitle` is seeded without a rename
  - Verify `just test` passes.
- [x] 1.4 Add `IssueSync.resolve(items:answers:)` (step 5), `IssueSync.prune(items:keepingChecked: 10)` (step 6), and `IssueSync.drop(change:in:)` (Decision 2: refused changes).
  - Tests: closed moves to the top of the checked items, gone or reassigned is removed, an 11th checked item drops the oldest, a dropped create removes its item, and a dropped rename resets the text.
  - Verify `just test` passes.
- [x] 1.5 Add `IssueSync.isEditable(item:access:login:)` (Decision 6) with tests for triage, author, a new item, and unknown access. Add `NoteStore.setItems(_:for:)`, which saves and refreshes the plain-text copy, with a test.
  - Verify `just test` and `just test-linux` pass.
- [x] 1.6 Add the `IssueService` protocol (`currentUser`, `repositories`, `repository`, `openIssues`, `issue`, `create`, `update`) and its error type (`unauthorized`, `forbidden`, `notFound`, `gone`, `invalid`, `offline`, `server`, `moved`).
  - Add a `FakeIssueService` in the tests.
  - Verify `just test` passes.

## 2. GitHub client and logging (NotelyGitHub)

- [x] 2.1 Add `Logger.github` (subsystem `com.alvarezjorge.Notely`, category `github`) and `GitHubClient: IssueService` on `URLSession` against `https://api.github.com`. Send the headers `Accept: application/vnd.github+json` and `X-GitHub-Api-Version: 2022-11-28`, and read the token from `TokenStore` on each request.
  - Log one `.info` line per request: method, path with the repository `.private`, status, milliseconds, and `X-RateLimit-Remaining`/`Limit`. On failure, log `.error` with GitHub's `message`.
  - Never log the token, headers, or bodies (design.md Decision 8).
  - Verify with `log stream` while running task 3.1: no token appears in the output.
- [x] 2.2 Map HTTP results to the `IssueService` errors: 401 unauthorized, 403 forbidden, 404 not found, 410 gone, 422 invalid, 301 moved, 5xx server, and `URLError` offline. Follow `Link: rel="next"` for list calls, and drop items with a `pull_request` key.
  - Verify in task 4.1 against the scratch repository.
- [x] 2.3 Add the in-memory ETag cache with `If-None-Match` (Decision 9).
  - Verify in the log that a second refresh with no changes on GitHub shows `-> 304` and that the rate count does not drop.

## 3. Account and picker

- [x] 3.1 Make `GitHubAccount.connect(token:)` async. It checks the token with `IssueService.currentUser` before saving and sets `login`. Add `tokenRejected`, and fetch `login` at launch when a token is saved. Update `GitHubAccountTests` to use `FakeIssueService`, including rejected and offline cases.
  - Verify `just test` passes.
- [x] 3.2 Update `AccountSheet`: progress on "Connect", "GitHub didn't accept this token.", and the offline message. Show "Connected as @<login>" in Integrations.
  - Verify issue-sync scenarios "Valid token", "Rejected token", "Offline", and "Login after relaunch".
- [x] 3.3 Add search to `RepositoryPicker`: load `repositories()` on open with progress, filter as the user types, fill the field on a click, and show the failure message.
  - Verify "Pick from the list" and "List fails".
- [x] 3.4 Check the repository on Link with `repository()`, showing "Repository not found, or this token can't reach it." or "Issues are turned off for <owner/repo>.".
  - Verify "Unknown repository" and "Issues turned off". Turn issues off in the scratch repo's settings for the second one.

## 4. Sync controller

- [x] 4.1 Add `SyncController` (`@MainActor`) in `NotelyUI/GitHub/`. It runs refresh steps 1–6 for one list with `IssueSync` and `IssueService`, logs each decision, and keeps per-list state: running, last error, and access. Only one sync runs per list at a time.
  - Wire it through `AppDelegate`.
  - Verify "Assigned and unassigned issues" and "Shared assignment" by creating issues #1–#3 and a pull request in the scratch repo.
- [x] 4.2 Trigger refreshes: at launch, after linking, every 600 s from one `Timer`, and from the refresh button. The button spins while running, and nothing runs while disconnected or `tokenRejected`.
  - Verify "Refresh on demand" and "Refresh by timer".
  - For the timer check, temporarily set the interval to 60 s, then restore it to 600.
- [x] 4.3 Add `push(listID)` with the 0.5 s debounce (Decision 4). It is called on focus loss on a linked list, on check and uncheck, and after "Create as issues".
  - Verify "New item", "Items kept on link", "Close from the list", and "Rename from the list".
- [x] 4.4 Handle issues changed on GitHub and the checked-item limit.
  - Verify "Closed elsewhere", "Deleted elsewhere", "Reassigned elsewhere", and "Eleventh checked item".
  - Delete an issue from the scratch repo's issue page as admin.

## 5. Linked-list rules and status UI

- [x] 5.1 Apply the linked-list rules in `ListView` (Decision 7): restore the title on empty focus loss, ignore Backspace removal for items with an issue, and push on focus loss.
  - Verify "Clear an item" and "Backspace in a cleared item".
  - Verify an unlinked list still removes empty items, per checklists "Empty item removed".
- [x] 5.2 Add the rights rules: `CheckCircle` `isEnabled` with the dimmed look and the tooltip "You can't close this issue", `ListField.isEditable`, and Cmd+Return ignored for read-only items.
  - Verify "Read-only repository" and "Own issue in a read-only repository" with a second GitHub account given read access to the scratch repo.
- [x] 5.3 Add the badge on the GitHub button for waiting changes or `tokenRejected`. In the GitHub menu, add "<n> changes not sent yet", the last refusal reason, and "GitHub token no longer works" with "Reconnect…", which opens Settings on Integrations.
  - Verify "Check while offline" (turn Wi-Fi off), "Quit with waiting changes", "Refused for good", and "Revoked token".

## 6. Integration check

- [x] 6.1 Run issue-sync "Read the log", "Failed request logged", and "Token absent" while doing a full round:
  - connect
  - link with "Create as issues"
  - check, rename, uncheck
  - an offline change
  - a revoke and reconnect
- [x] 6.2 Restore the backup from before group 1. Verify that every note and list opens unchanged, and that unlinked lists send nothing (the log shows no requests for them).
- [x] 6.3 Run `openspec validate sync-github-issues --strict`, `just test`, and `just test-linux`, and verify all pass.
