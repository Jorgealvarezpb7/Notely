# Proposal

## Why

The user tracks work for their projects as GitHub issues, and keeps quick to-dos in Notely lists. Linking a Notely list to one GitHub repository lets the user see and close their issues from a sticky list. This change builds the UI for that: a Settings window, the GitHub account setup, and the controls that link a list to a repository. Talking to GitHub (fetching, creating, closing, and refreshing issues) comes in a follow-up change, `sync-github-issues`. The decisions for that change are recorded in design.md so they are not lost.

## What Changes

- New Settings window, opened by a new gear button in every note and list bottom bar, and by Notely > Settings… (Cmd+,). It has a sidebar with two panes: General and Integrations.
- **BREAKING (UI)**: The font button and the text size button leave the bottom bar. Font and text size are set in Settings > General instead. The setting stays global and persisted as today.
- The bottom bar's trailing edge becomes the gear button, then the tint button, in both note and list windows.
- Settings > Integrations has a GitHub section:
  - "Setup Account" opens a sheet with a field for a GitHub personal access token. Connect saves the token in the macOS Keychain, never in the notes data or in `UserDefaults`.
  - Once connected, the section has "Disconnect", which removes the token from the Keychain.
  - A read-only "Linked lists" summary shows each linked list and its repository.
- While a token is saved, list windows show a GitHub button at the leading edge of the bottom bar. When no token is saved, no list window shows it.
- The GitHub button opens a menu:
  - On an unlinked list: "Link to Repository…".
  - On a linked list: the repository name, "Open on GitHub", and "Unlink".
- "Link to Repository…" opens a picker popover. The user types `owner/repo` in a search field. Search results from GitHub come in the follow-up change.
- Linking a list that has unchecked items first asks: "Create as issues", "Discard", or "Cancel". Checked items are never kept.
- Linked lists show a refresh button after the GitHub button. What it does is defined by the follow-up change.
- Each list stores its linked repository, and the link persists across relaunch. Disconnecting keeps the links, and they show again on reconnect.

## Capabilities

### New Capabilities

- `settings`: The Settings window, how it opens (the gear button and Cmd+,), its sidebar and panes, and where global preferences live.
- `github-integration`: The GitHub account setup and token storage, the GitHub and refresh buttons on list windows, linking and unlinking a list to a repository, and the linked lists summary. The follow-up change extends this capability with issue sync.

### Modified Capabilities

- `text-appearance`: Font and text size controls move from the bottom bar to Settings > General. The global setting, its defaults, and persistence are unchanged.
- `note-tint`: The tint button follows the gear button instead of the text size button.
- `sticky-note`: "Panel stays movable" lists the gear button instead of the font and text size buttons.
- `text-styles`: "Style buttons in the note bottom bar" no longer refers to the font and text size buttons.

## Impact

- `Sources/NotelyUI/Chrome/BottomBar.swift`: The font and size buttons go. The gear button is added, along with the GitHub and refresh buttons for lists. `AppearanceControls` font menu and size popover code moves to the Settings pane or is removed.
- New `Sources/NotelyUI/Settings/`: the Settings window controller and the General and Integrations panes.
- `Sources/NotelyUI/Menu/MainMenu.swift`: The app menu gets "Settings…" with Cmd+,.
- `Sources/NotelyCore/Model/Note.swift`: `Note` gains an optional linked repository field, and `ListItem` gains an optional issue number. Earlier versions ignore both.
- A new macOS-only `NotelyGitHub` target holds the Keychain token store, using the Security framework.
- No new third-party dependencies. No network calls in this change.
