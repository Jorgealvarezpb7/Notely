# Proposal

## Why

A linked list shows each issue's title, but not its description, so the user has to open GitHub to read or write what an issue is about. And after a change, nothing in the list window says whether it reached GitHub. The spinner stops the same way whether the sync worked or failed. This change finishes the GitHub integration: issue descriptions in Markdown, and a clear sign of whether the last sync worked.

This change builds on `sync-github-issues`, which builds on `add-github-integration`. Both must be archived first.

## What Changes

- **Descriptions**: On a linked list, every item has a description: its issue's body.
  - A trailing description icon opens it in a popover. The icon always shows when the item has a description, and shows on hover when it has none.
  - Cmd+D opens the popover for the focused item, or else the item under the pointer.
  - The popover shows the description rendered as Markdown:
    - headings, bullet and numbered lists, and code blocks
    - task lists, shown but not clickable
    - bold, italic, inline code, and links
    - tables and images stay as raw text
  - "Edit" switches to the raw Markdown text. An issue the user can't change opens without "Edit".
  - A new item's description is sent when its issue is created.
  - A changed description is sent like a title change.
  - Unlinked lists have no descriptions.
- **Description conflicts**: Before a changed description is sent, the app checks GitHub's description.
  - When someone changed it on GitHub since the last sync, the edit is held and not sent.
  - The popover offers "Keep mine" or "Use GitHub's".
- **Sync result**: A check mark or an x shows beside the refresh button after each sync, the full refresh and the push of the user's changes alike.
  - Check: everything was sent and the refresh worked.
  - x: something failed, including when some changes were sent and others refused, when GitHub can't be reached, and when a description edit is held. Its tooltip says why.
  - A check fades after a minute. An x stays while changes wait to be sent, and fades a minute after it stops being current.
- **BREAKING (UI)**: The orange badge on the GitHub button is removed. The x replaces it.
- **Shortcuts**: A GitHub menu in the menu bar acts on the front list window:
  - Description (Cmd+D)
  - Refresh Issues (Cmd+R)
  - Link to Repository… (Cmd+L)

## Capabilities

### New Capabilities

- `issue-descriptions`: How a linked list item's description is shown, edited, rendered as Markdown, sent to GitHub, and how a conflicting edit on GitHub is resolved.
- `sync-status`: The check mark or x beside a linked list's refresh button, and when it shows and fades.

### Modified Capabilities

- `issue-sync` (from `sync-github-issues`): "Changes wait until sent" and "Token no longer accepted" drop the GitHub button's badge, in favor of the `sync-status` x.
- `github-integration` (from `add-github-integration`): adds the GitHub menu-bar menu with Refresh Issues (Cmd+R) and Link to Repository… (Cmd+L).

## Impact

- `Sources/NotelyCore/`:
  - `ListItem` gains the description, its last known GitHub value, and a held GitHub value for conflicts.
  - `RemoteIssue` gains `body`.
  - `IssueSync` gains description changes and conflict rules.
  - A Markdown block parser, free of UI, tested on Linux.
- `Sources/NotelyGitHub/`: `GitHubClient` reads `body`, and sends it on create and update. Descriptions are never logged.
- `Sources/NotelyUI/`:
  - the description icon and popover on list rows
  - the Markdown view
  - the sync result icon in `BottomBar`, which replaces the badge
  - the GitHub menu in `MainMenu`
- Network: one extra `GET` per description edit sent. Bodies come with the issue lists already fetched.
- Storage: descriptions are saved with the notes in `UserDefaults`.
- No third-party dependencies.
