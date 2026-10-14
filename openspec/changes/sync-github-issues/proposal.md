# Proposal

## Why

`add-github-integration` built the GitHub controls but sends nothing to GitHub. The user can connect an account and link a list to a repository, but the list never shows the repository's issues, and checking an item does not close its issue. This change makes a linked list show and manage the issues, kept in step with GitHub in both directions. It also logs every GitHub request, so the user can see why a change did not reach GitHub.

This change builds on `add-github-integration`. That change must be archived first.

## What Changes

- **Token check**: Connect checks the token with GitHub before saving it. A token GitHub rejects is not saved, and the sheet says why. Once connected, Settings shows the account's login: "Connected as @login".
- **Picker search**: The repository picker lists the repositories the token can reach, filtered as the user types. A typed `owner/repo` that is not listed is checked with GitHub on Link. Link is refused when the repository can't be found or has issues turned off.
- **Which issues show**: A linked list shows the repository's open issues that are assigned to the user or to no one. Issues assigned only to others are hidden. Pull requests never show.
- **When the list refreshes**: every 10 minutes, on the refresh button, right after linking, and at launch. The refresh button spins while a refresh runs.
- **Issues changed elsewhere**:
  - Closed on GitHub: the item moves to the top of the checked items. A linked list keeps at most the 10 most recently checked items.
  - Deleted, or assigned only to others: the item is removed.
- **What the user's actions do on GitHub**:
  - A new item creates an issue when the item loses focus. The issue is assigned to the user when they have push access.
  - Items kept by "Create as issues" are created the same way.
  - Checking an item closes its issue, and unchecking reopens it.
  - Changing an item's text renames its issue when the item loses focus.
  - Clearing an item puts its title back, and sends nothing. Backspace never removes an item from a linked list.
- **Permissions**: Without triage access or authorship, an issue can't be closed, reopened, or renamed. Its circle shows dimmed and its text is read-only.
- **Offline and errors**:
  - Changes apply at once and are sent on the next refresh until GitHub accepts them. They survive quit.
  - While changes wait, the GitHub button shows a badge.
  - A change GitHub refuses for good is dropped, and the item takes GitHub's state.
  - A token GitHub no longer accepts pauses sync and offers "Reconnect…".
- **Logging**: Every GitHub request, its result, and every sync decision is written to the macOS unified log, under subsystem `com.alvarezjorge.Notely`, category `github`. The token and the `Authorization` header are never logged.

## Capabilities

### New Capabilities

- `issue-sync`: How a linked list and its repository's issues stay in step. That covers:
  - the token check
  - picker search and the repository check on Link
  - which issues show, and when the list refreshes
  - what the user's actions send to GitHub
  - permissions, offline changes, and errors
  - the log of GitHub activity

### Modified Capabilities

None. `issue-sync` adds to the behavior of `github-integration` and `checklists` without changing their requirements. Linked lists follow `issue-sync` where it says so.

## Impact

- `Sources/NotelyGitHub/`: a GitHub REST client on `URLSession`, and logging with `os.Logger`.
- `Sources/NotelyCore/`:
  - The sync rules, kept free of networking so they are tested on Linux.
  - `ListItem` gains the item's last known GitHub state.
  - `NoteStore` gains the operations sync needs.
- `Sources/NotelyUI/`:
  - a sync controller with the 10-minute timer
  - the refresh button's action and spinner
  - the GitHub button's badge and error entries
  - the dimmed circle and read-only text on linked lists
  - search in the picker, and the token check in the account sheet
- Network: `api.github.com` over HTTPS. The requests stay far under GitHub's 5,000 requests per hour.
- No third-party dependencies.
