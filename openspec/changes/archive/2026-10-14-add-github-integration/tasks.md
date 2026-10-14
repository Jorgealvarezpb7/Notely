# Tasks

How to verify:
- `NotelyCore` work is checked with `just test`. `just test-linux` also checks it on Linux.
- UI work is checked with `just run` on the macOS host, against the scenarios named in each task.
- Before starting, back up the notes: `defaults export com.alvarezjorge.Notely ~/notely-backup.plist`.

## 1. Data model and link rules (NotelyCore)

- [x] 1.1 Add `githubRepo: String?` to `Note` and `issueNumber: Int?` to `ListItem`, both optional with `nil` defaults in the initializers (design.md "Data model").
  - Add a `ModelTests` case: a list saved without the new fields decodes with both fields `nil`.
  - Verify `just test` passes.
- [x] 1.2 Add `NoteStore.link(_:repo:keep:)` and `NoteStore.unlink(_:)` (design.md "Data model").
  - `keep: true` keeps the unchecked items and drops the checked ones. `keep: false` drops every item. The title never changes.
  - `unlink` clears `githubRepo` and keeps items and `issueNumber`.
  - Add `NoteStoreTests` for each rule, including that the change is saved through the repository and that `text` (the plain-text copy) is refreshed.
  - Verify `just test` passes (github-integration "Link a list", "Unlink a list").
- [x] 1.3 Add a function that checks repository input against `^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$` after trimming spaces (design.md "Repository picker validation").
  - Add tests: "acme/website" is valid; "acme", "acme/web site", "a/b/c", and "/x" are rejected.
  - Verify `just test` passes.
- [x] 1.4 Add the `TokenStore` protocol (`read`, `save`, `delete`) and an in-memory implementation for tests (design.md "Account state").
  - Verify `just test` and `just test-linux` pass.

## 2. Keychain token store (NotelyGitHub)

- [x] 2.1 Add the macOS-only `NotelyGitHub` target to `Package.swift`, inside the `#if os(macOS)` block, depending on `NotelyCore`. Make `Notely` depend on it. `NotelyUI` needs only `NotelyCore`, where `GitHubAccount` lives.
  - Verify `swift build` succeeds on macOS and `just test-linux` still passes.
- [x] 2.2 Implement `KeychainTokenStore: TokenStore` with `SecItemAdd`, `SecItemCopyMatching`, `SecItemUpdate`, and `SecItemDelete` (generic password, service `com.notely.github`, account `token`). Trim the token before saving, and never log it.
  - Verify by hand on macOS: save shows the item in Keychain Access, relaunch reads it back, delete removes it (github-integration "Token kept in the Keychain").
- [x] 2.3 Add `GitHubAccount` to `NotelyCore`: an observable object with `isConnected`, `connect(token:)`, and `disconnect()`, backed by a `TokenStore`, with tests using the in-memory store.
  - Create it in `main.swift` and pass it through `NotelyApp.run` and `AppDelegate`, next to `TextAppearance`.
  - Verify `swift build` succeeds.

## 3. Settings window

- [x] 3.1 Add `Sources/NotelyUI/Settings/SettingsWindowController.swift`: one titled `NSWindow` with red, yellow, and green buttons, hosting a SwiftUI `NavigationSplitView` with the sidebar entries "General" and "Integrations" (design.md "Settings window").
  - `AppDelegate` owns one controller and exposes `openSettings()`. It selects General, brings the window to the front, and makes it key.
  - Red closes the window and does not quit. Set `setFrameAutosaveName` (design.md Open Questions).
  - Verify settings scenarios "Open Settings twice", "Opens on General", "Switch to Integrations", and "Close Settings".
- [x] 3.2 Add "Settings…" with Cmd+, to the app menu in `MainMenu.swift`, before "Quit Notely", targeting `AppDelegate.openSettings()`.
  - Verify settings scenarios "Cmd+, in a note" and "Settings item in the app menu", plus Cmd+, with a list window and with the menu window as key.
- [x] 3.3 Build the General pane: a "Font" pop-up and a "Text size" slider (10–20, step 1, with "N pt"), bound to the shared `TextAppearance`.
  - Verify text-appearance scenarios "Switch to the system font", "Font row shows the current font", "Make text smaller", "Limits", "Change applies to every window", "Menu font follows the choice", and "Relaunch keeps the setting".

## 4. Bottom bar

- [x] 4.1 Remove the font and text size buttons and `AppearanceControls` from `BottomBar.swift`. Add the gear button before the tint button, calling an `openSettings` closure passed from `NoteWindowController` (design.md "Bottom bar layout").
  - Verify settings scenarios "Gear in a note window", "Gear in a list window", "Click while another app is active", and "No gear in the menu window".
  - Verify note-tint "Button in a note window" and "Button in a list window", sticky-note "Bottom bar controls", and text-styles "Buttons in a note window".
- [x] 4.2 Check the minimum size with the new bars.
  - Verify text-appearance "Smallest window, largest text" for a note.
  - Verify "Smallest list window" after group 5 adds the GitHub and refresh buttons.

## 5. GitHub UI

- [x] 5.1 Build the GitHub section in the Integrations pane.
  - "Not connected" with "Setup Account", or "Connected" with "Disconnect", driven by `GitHubAccount`.
  - Below it, the "Linked lists" summary from `NoteStore`: the title or "Untitled list", plus `owner/repo`. Show "No linked lists" when none exist.
  - Verify github-integration "Not connected", "Connected", "Summary shows links", and "Summary follows a new link".
- [x] 5.2 Build the "GitHub Account" sheet: a `SecureField` "Personal Access Token", the note recommending a classic token with the "repo" scope, and "Cancel" and "Connect".
  - "Connect" is disabled while the field is blank. Esc cancels.
  - Verify github-integration "Connect", "Empty field", "Cancel", and "Relaunch keeps the account".
  - Verify that `defaults read com.alvarezjorge.Notely` does not contain the token ("Token not in app data").
- [x] 5.3 Wire "Disconnect" to `GitHubAccount.disconnect()`.
  - Verify github-integration "Disconnect" and "Reconnect keeps the link".
- [x] 5.4 Add the GitHub button at the leading edge of list bottom bars. It shows only when `GitHubAccount.isConnected`, and never on notes.
  - Verify github-integration "Button with an account", "No button without an account", and "No button on notes".
- [x] 5.5 Add the GitHub menu. Unlinked: "Link to Repository…". Linked: `owner/repo` with a check mark, "Open on GitHub", "Unlink".
  - "Open on GitHub" uses `NSWorkspace.shared.open` with `https://github.com/<owner>/<repo>/issues`.
  - "Unlink" calls `NoteStore.unlink`.
  - Verify github-integration "Menu on an unlinked list", "Menu on a linked list", "Open on GitHub", and "Unlink".
- [x] 5.6 Build the repository picker popover: search field, an empty results area, "Cancel" and "Link". "Link" is enabled by the validation function from 1.3, and Esc cancels.
  - Verify github-integration "Type a repository", "Not a repository", and "Cancel the picker".
- [x] 5.7 Build the link flow.
  - With no unchecked items, link at once with `keep: false`.
  - Otherwise show the sheet "Link "<title>" to <owner/repo>?" with the unchecked count, and "Cancel", "Discard", and "Create as issues" mapped to no change, `keep: false`, and `keep: true`.
  - Verify github-integration "Link an empty list", "Link a list with items", "Create as issues", "Discard", "Cancel linking", and "Relaunch keeps the link".
- [x] 5.8 Add the refresh button (`arrow.clockwise`) directly after the GitHub button. It shows only on linked lists while connected, and its action is a no-op until `sync-github-issues`.
  - Verify github-integration "Refresh button on a linked list" and "No refresh button on an unlinked list", then complete 4.2's "Smallest list window".

## 6. Integration check

- [x] 6.1 Restore the backup from before group 1 and launch.
  - Every note and list opens unchanged and unlinked (github-integration "Older lists stay unlinked").
  - Text appearance matches the saved font and size (text-appearance "First launch of this version").
- [x] 6.2 Run `openspec validate add-github-integration --strict`, `just test`, and `just test-linux`, and verify all pass.
