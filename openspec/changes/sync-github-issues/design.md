# Design

## Context

See proposal.md for the motivation. The requirements are in `specs/issue-sync/spec.md`.

What `add-github-integration` left in place:
- `GitHubAccount` and `TokenStore` in `NotelyCore`.
- `KeychainTokenStore` in the macOS-only `NotelyGitHub` target.
- `Note.githubRepo`, and `ListItem.issueNumber`, where `nil` means the issue is still to be created.
- `NoteStore.link` and `NoteStore.unlink`.
- The GitHub and refresh buttons and the GitHub menu, in `GitHubControls` and `BottomBar`.
- The refresh button's action is an empty closure.

Constraints:
- `NotelyCore` is Foundation-only and tested on Linux.
- `NoteStore` is `@Observable` and is changed on the main thread.
- Every change to it is saved to `UserDefaults` at once.
- List rows already report focus loss through `ListField.onEndEditing`.

## Goals / Non-Goals

**Goals:**
- Keep the sync rules (what to send, how to merge what comes back) in `NotelyCore`, as pure functions tested on Linux without a network.
- Keep waiting changes in the saved notes, so they survive quit without a separate queue file.
- Make every request and decision visible in Console.app.

**Non-Goals:**
- Issue bodies, labels, comments, milestones, or assignee editing.
- Webhooks or push updates. Polling only.
- More than one account, or GitHub Enterprise hosts.

## Decisions

### 1. Three layers

```
 NotelyCore      IssueSync (pure rules), IssueService protocol,
                 RemoteIssue / RepoAccess values, NoteStore ops
 NotelyGitHub    GitHubClient: IssueService (URLSession, ETags, logging)
 NotelyUI        SyncController (@MainActor): timer, per-list refresh,
                 spinner, badges, errors; UI rules for linked lists
```

`main.swift` builds `GitHubClient(tokens: KeychainTokenStore())` and passes it to `NotelyApp.run` as `any IssueService`. Because of the logger (Decision 8), `NotelyUI` now depends on `NotelyGitHub`.

*Alternative: put the client in `NotelyCore`.* Rejected: `URLSession` on Linux needs `FoundationNetworking`, and its behavior differs there. Tests use a fake `IssueService` instead.

### 2. State-based sync, not an operation queue

Each `ListItem` keeps the last state seen on GitHub. All new fields are optional, so older data decodes unchanged:
- `remoteTitle: String?`
- `remoteClosed: Bool?`
- `issueAuthor: String?`, the author's login, used for the rights check.

A waiting change is any difference between the item and its last known GitHub state:
- `issueNumber == nil` with non-empty text: create.
- `text != remoteTitle`: rename.
- `done != remoteClosed`: close or reopen.

Because the items are saved on every change, waiting changes survive quit for free. The badge count is the number of items with a difference. The local state wins: a waiting change is sent even if GitHub changed meanwhile.

*Alternative: a persisted queue of operations.* Rejected. It needs its own storage, ordering, and squashing (check, then uncheck), and it can disagree with what the list shows.

### 3. Refresh algorithm, per linked list

`IssueSync` computes each step from values, and `SyncController` runs the requests:

1. **Read access.** `GET /repos/{o}/{r}` gives `permissions` and `has_issues`. A 404 or 403 here stops the refresh, and the menu shows an error.
2. **Push waiting changes.**
   - Create: `POST /repos/{o}/{r}/issues` with `{title, assignees: [login] if push}`.
   - Rename: `PATCH .../issues/{n}` with `{title}`.
   - Close or reopen: `PATCH .../issues/{n}` with `{state}`.
   - After each success, the item's remote fields are set from the response.
   - 403, 404, 410, or 422: the change is dropped for good. For a create, the item is removed. Otherwise the item's text and done are reset to its remote fields, and step 4 corrects them.
   - Network errors and 5xx keep the change for the next refresh.
3. **Fetch the shown set.** `GET .../issues?state=open&assignee={login}&per_page=100` and `...&assignee=none`, following `Link: rel="next"`, with pull requests dropped. The two results are merged by issue number.
4. **Merge** (`IssueSync.merge`, pure):
   - An issue in the set with an item: update `remoteTitle`, `remoteClosed = false`, and `issueAuthor`. Set the item's text to the title, unless the item has focus or a waiting rename. Uncheck it if it was checked by GitHub's state (reopened elsewhere) and has no waiting close.
   - An issue in the set without an item: append an unchecked item at the end of the unchecked items, in ascending issue number.
   - An unchecked item whose issue is not in the set: it goes on the "ask" list.
5. **Ask.** `GET .../issues/{n}` for each item on the ask list:
   - `state == closed`: the item becomes checked and moves to the top of the checked items.
   - 404, 410, or a 301 (transferred): the item is removed.
   - Open but assigned only to others: the item is removed.
6. **Prune** the checked items to the first 10. List order is already newest checked first.

The focused item is passed in, and steps 2 and 4 skip it for creates and renames.

### 4. Pushing right away

A refresh every 10 minutes is too slow for the user's own changes. `SyncController.push(listID)` runs step 2 alone, 0.5 seconds after the last change. It is called:
- when an item loses focus on a linked list
- on check and uncheck
- after "Create as issues"

A full refresh runs right after linking, at launch, every 600 seconds from one `Timer`, and on the refresh button. Only one sync runs per list at a time. A request made while one runs is queued once.

### 5. Login and token check

`IssueService.currentUser(token:)` calls `GET /user`.
- `GitHubAccount.connect` becomes `async` and returns a `ConnectResult` (`connected`, `rejected`, `offline`, `saveFailed`, `failed`): it checks the token first and saves it only on 200. The account sheet maps each result to its message.
- The account gains `login: String?`, kept in memory and fetched at launch.
- A 401 on any request sets `GitHubAccount.tokenRejected = true`. That pauses `SyncController` and drives "Reconnect…".
- A successful connect clears it.

### 6. Rights

`RepoAccess { canTriage: Bool, canPush: Bool }` comes from `permissions` (`triage || push || maintain || admin`, and `push || maintain || admin`). It is kept in memory per repository and refreshed in step 1.
- An item is editable when `canTriage || issueAuthor == login || issueNumber == nil`.
- Until the access is known after launch, items are editable. A refused change is dropped by the rules of Decision 2.

### 7. Linked-list rules in `ListView`

`ListView` reads `note.githubRepo`, the access, and the login. On a linked list:
- `removeIfEmpty` restores `remoteTitle` instead of removing, when the item has an issue.
- `.deleteEmpty` returns `true` without removing, when the item has an issue.
- `CheckCircle` gets `isEnabled` and `help("You can't close this issue")`, and Cmd+Return is ignored for it.
- `ListField` gains `isEditable`.
- Checking calls `NoteStore.toggleItem`, then prunes to 10 and pushes.

### 8. Logging

`NotelyGitHub` exports `Logger.github = Logger(subsystem: "com.alvarezjorge.Notely", category: "github")`.

`GitHubClient` logs one line per request at `.info`:

```
GET /repos/%{private}s/issues?state=open&assignee=none -> 200 in 182 ms (rate 4973/5000)
```

Failures log at `.error` with GitHub's `message` field. `SyncController` logs each decision at `.info`: added #n, closed #n, removed #n, sent create, retrying n changes, dropped change for #n (status).

What is never logged:
- The `Authorization` header, the token, and request or response bodies. The client builds its log lines from method, path, status, and timing only.
- Repository names and issue titles are interpolated with `privacy: .private`.

*Alternative: a log file in Application Support.* Rejected: the unified log already has levels, privacy, and Console.app filtering, at no cost.

### 9. ETags

`GitHubClient` keeps an in-memory `[URL: (etag, body)]` cache and sends `If-None-Match`. A 304 returns the cached body. GitHub does not count a 304 against the rate limit.

### 10. Picker search

When the picker opens, `IssueService.repositories()` is called: `GET /user/repos?affiliation=owner,collaborator,organization_member&sort=pushed&per_page=100`, following `next` up to 5 pages. The result is filtered locally as the user types. Link calls step 1 for the typed name before `NoteStore.link`.

## Risks / Trade-offs

- **Local wins.** An edit made in Notely overwrites a concurrent edit on GitHub. → Acceptable for titles and open state. The log shows what was sent.
- **Many lists.** Each linked list costs about 3 requests per refresh, plus 1 per issue that left the open set. With ETags, 20 lists stay near 360 requests per hour, far under 5,000. → The remaining rate is logged. If it falls under 100, sync pauses until the reset time.
- **A dropped create removes the user's text.** A 403 or 422 on create removes the item. → The menu shows the reason, and the log keeps the title (private).
- **The 0.5 s debounce while offline** fires requests that fail. → They fail fast, the badge shows, and the next refresh retries.
- **A huge repository** with hundreds of unassigned issues fills the list. → Accepted by the user's filter choice; pagination keeps it correct.

## Migration Plan

- The new optional fields on `ListItem` decode as `nil`. An item with an issue but no `remoteTitle` counts as in step: `remoteTitle` is seeded from its text on first merge, and no rename is sent.
- Lists linked under `add-github-integration` start syncing at the first launch of this version. Their kept items have `issueNumber == nil`, so they are created.
- Rollback: earlier builds ignore the new fields. Changes not yet sent stay unsent.

## Open Questions

- Whether to show the issue number (`#12`) next to item text. This doesn't change the sync rules, and can be added later as a display option.
