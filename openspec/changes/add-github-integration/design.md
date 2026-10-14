# Design

## Context

See proposal.md for the motivation and the scope of this change.

Current state:
- The app runs from `NotelyApp.run`, which builds an `AppDelegate`. The delegate owns `MenuWindowController` and one `NoteWindowController` per open note or list.
- Windows host SwiftUI views through AppKit controllers.
- `BottomBar` is shared by `NoteView` and `ListView`. It takes `store`, `appearance`, `id`, and, for notes only, `editorState`.
- `TextAppearance` is one shared `ObservableObject` saved in `UserDefaults`.
- `NotelyCore` is Foundation-only and tested on Linux. AppKit and Security code must stay out of it.
- There is no Settings window, and the app menu has only "Quit Notely".

The work is split into two changes:
- **This change: UI.** No network calls.
- **Follow-up change, `sync-github-issues`.** It talks to GitHub. Its decisions are already made with the user and are recorded below in "Follow-up: issue sync", so that change can start from them.

## Goals / Non-Goals

**Goals:**
- Build every control the user sees for the GitHub integration, with local state behind it: the token in the Keychain, the link on the list.
- Leave the data model ready for sync, so the follow-up change adds behavior without reshaping saved data.

**Non-Goals:**
- Any GitHub API call. That rules out several things in this change:
  - checking the token
  - listing repos in the picker
  - creating, closing, reopening, or renaming issues
  - running the refresh button's action
- OAuth or GitHub App sign-in. A personal access token is the only method.
- More than one GitHub account.

## Decisions

### Settings window: AppKit controller hosting SwiftUI
A `SettingsWindowController` follows the `MenuWindowController` pattern: an `NSWindow` hosting a SwiftUI `NavigationSplitView` with a sidebar holding General and Integrations. `AppDelegate` owns one instance, which keeps the window single and lets it come to the front when opened again.
- *Alternative: a SwiftUI `Settings` scene.* Rejected because the app has no SwiftUI `App` lifecycle; it runs `NSApplication` by hand.
- Opening Settings always selects General, as the spec requires. The pane selection is not saved.

### Opening Settings from the bottom bar
`BottomBar` gets an `openSettings` closure, passed in from the window controllers, which get it from `AppDelegate`. The app menu's "Settings…" item calls the same `AppDelegate` action. One entry point, two triggers.

### Font and size controls move into Settings > General
The font pop-up and the size slider bind to the same shared `TextAppearance` object. Saving, defaults, and limits do not change. `AppearanceControls` (the font menu and the size popover in `BottomBar.swift`) is deleted.

### Bottom bar layout

```
note:  [B][I][U]        ...        [gear][tint]
list:  [GH][refresh]    ...        [gear][tint]
       ^ GH only with token; refresh only when also linked
```

The existing 190 by 120 point minimum size stays. The note bar loses one button, and the list bar has at most four buttons.

SF Symbols has no GitHub mark, so the GitHub button uses `arrow.triangle.branch`. The refresh button uses `arrow.clockwise`, and the gear uses `gearshape`.

### Account state: `GitHubAccount` observable
`GitHubAccount` is an `ObservableObject` that publishes `isConnected`. It is injected wherever `TextAppearance` is: `BottomBar`, the Settings panes, and the window controllers. When the account connects or disconnects, every open list's bar updates at once.

`GitHubAccount` and the `TokenStore` protocol it reads and writes the token through both live in `NotelyCore`, so tests can cover them on Linux with an in-memory fake. `NotelyUI` therefore needs only `NotelyCore`.
- The Keychain implementation, `KeychainTokenStore`, lives in a new macOS-only target, `NotelyGitHub`. It uses `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete` with `kSecClassGenericPassword`, service `com.notely.github`, and account `token`.
- Only the `Notely` executable depends on `NotelyGitHub`. It builds the account in `main.swift`.
- The follow-up change puts the API client in `NotelyGitHub` too.

Rejected alternatives:
- *Keychain code in `NotelyUI`.* Rejected because the sync code needs the token too, so both belong in one GitHub module.
- *Token in `UserDefaults`.* Rejected: the token would be stored in plain text.

### Data model
`Note` gains one optional field, `githubRepo: String?`, holding `"owner/repo"`. `ListItem` gains one optional field, `issueNumber: Int?`. Both are optional, so data saved by earlier versions decodes unchanged, and earlier builds ignore the new fields.

How the fields are used:
- On a linked list, an item whose `issueNumber` is `nil` is an item still to be created on GitHub. "Create as issues" keeps the unchecked items in that state, and the follow-up change's sync creates them.
- "Unlink" clears `githubRepo` and keeps `issueNumber` on the items. Linking again later is a follow-up concern.
- Disconnect leaves `githubRepo` alone, as the spec requires.

`NoteStore` gets `link(_ id:, repo:, keep:)` and `unlink(_ id:)`, so the tests in `NotelyCoreTests` can cover the item rules for "Create as issues" and "Discard".

### Repository picker validation
The picker accepts `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$`. The results area stays empty in this change. The follow-up change fills it from `GET /user/repos` and also checks a typed repository on Link.

### "Open on GitHub"
"Open on GitHub" opens `https://github.com/<owner>/<repo>/issues` with `NSWorkspace.shared.open`. This needs no API call.

## Risks / Trade-offs

- **Discoverability.** Moving font and size out of the bottom bar adds a step for users who change them often. → The gear sits in every window, and Cmd+, works everywhere.
- **Buttons that do nothing yet.** The refresh button shows but does nothing until `sync-github-issues` lands, and the picker shows no repos to search. → Ship both changes before a release, or hide refresh behind the same build until the sync change lands.
- **Unchecked token.** A wrong token is saved as "Connected", because checking it needs the network. → The follow-up change checks the token with `GET /user` on Connect and shows the login name.
- **Keychain prompts.** Unsigned or re-signed development builds may ask for Keychain access after each rebuild. → The packaging target signs consistently. In development this is expected.

## Migration Plan

- Saved data: the two new optional fields need no migration.
- Font and size settings keep their `UserDefaults` keys, so the user's choice carries over.
- Rollback: an earlier build ignores `githubRepo` and `issueNumber`. The token stays in the Keychain, unused.

## Follow-up: issue sync (`sync-github-issues`)

These decisions were made with the user. They are not part of this change.

**Which issues show**
- A linked list shows open issues **assigned to me, or assigned to no one**. Issues assigned only to others are hidden. Pull requests are excluded. There is no filter choice, neither per link nor global.
- Each refresh fetches `GET /repos/{o}/{r}/issues?state=open&assignee={me}` and `...&assignee=none`, then merges the results by issue number. It uses ETag conditional requests: a 304 response does not count against the rate limit.

**When the list refreshes**
- Every 10 minutes.
- When the user clicks the refresh button. The button spins while refreshing and is disabled meanwhile.
- When a list is linked.
- When the app launches.

**Issue missing from the open results**
The client fetches `GET /repos/{o}/{r}/issues/{n}`:
- closed: the item moves to checked (top). The checked section keeps the last 10 items.
- 404 or 410: the item is removed.
- open but assigned only to others: the item is removed.

**What the user's actions do on GitHub**
- **Check and uncheck** close and reopen the issue. That needs triage+ access or being the issue's author.
- **Rename**: changing an item's text renames the issue with a PATCH, sent when the item loses focus. That needs triage+ access or being the issue's author.
- **No rights**: without triage+ access or authorship, the circle shows dimmed with the tooltip "You can't close this issue", and the item's text is read-only.
- **Clearing an item** restores its title. Nothing is sent: GitHub rejects empty titles and REST can't delete issues. Backspace never deletes an item on a linked list.
- **New items** are created with `assignees: [me]` when the user has push access, and unassigned otherwise. Either way the item still matches the filter.

**Permissions**
- Permissions are read from `GET /repos/{o}/{r}` (`permissions`) on link and on each refresh.
- If the repository has issues turned off, Link is refused with the message "Issues are turned off for owner/repo".

**Errors and offline**
- Changes apply locally at once and wait in a queue that survives quit. Each refresh sends them again.
- While changes wait, the GitHub button shows "!".
- On a permanent failure (403, 404, or 410), the client drops the change, takes GitHub's state, and the GitHub menu says why.
- On a 401, the GitHub button shows "!" on every linked list, and the menu offers "GitHub token no longer works" with "Reconnect…", which opens Settings > Integrations. Refreshes pause until a new token is saved.

**Token types**
- A classic token with the `repo` scope reaches every repository the user can reach.
- A fine-grained token is bound to one resource owner. It can't reach another user's repository where the user is a collaborator, and it can't write to public repositories the user doesn't belong to.
- The account sheet recommends classic for mixed use and accepts both kinds.

**Picker**
- Search lists repositories from `GET /user/repos?affiliation=owner,collaborator,organization_member`.
- A typed `owner/repo` is checked on Link, which covers public repositories the user isn't a member of.

## Open Questions

- Should the Settings window remember its position across launches? This doesn't affect the specs. Default: let AppKit autosave the frame (`setFrameAutosaveName`).
