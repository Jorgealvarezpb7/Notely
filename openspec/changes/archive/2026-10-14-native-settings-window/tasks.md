# Tasks

How to verify:
- This change is UI only. Check it on the macOS host with `just run`, and open Settings with Cmd+,.
- `just test` must still pass after each group. No `NotelyCore` code changes.

## 1. Spike: scene bridging in an AppKit window

- [x] 1.1 In `SettingsWindowController.makeWindow()`, swap `NSHostingView` for an `NSHostingController` set as `contentViewController`, with `sceneBridgingOptions = [.title, .toolbars]`. Add `.fullSizeContentView` to the style mask and set `toolbarStyle = .unified`. Wrap the current `HStack` in a two-column `NavigationSplitView` with `.navigationTitle(selection.pane.title)` on the detail (design.md Decisions 1-2).
  - Verify with `just run`: the sidebar reaches up beside the window buttons, a sidebar toggle shows in the title bar, and the window title reads "General".
  - If the toggle does not show, add the hand-built `NSToolbar` fallback from design.md Risks and check again before going on.

## 2. Native layout

- [x] 2.1 Finish `SettingsView` on `NavigationSplitView`.
  - Sidebar: the existing `List` and its binding that ignores empty clicks, with `.navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)`.
  - Detail: the pane `switch`.
  - Delete the `Text(selection.pane.title)` heading and its padding, and the `HStack` and `Divider`.
  - Verify with `just run`:
    - Clicking "Integrations" highlights it, shows that pane, and changes the window title to "Integrations".
    - Clicking empty sidebar space keeps the current pane.
    - Neither pane shows its own name as a heading.
- [x] 2.2 Check that the rest of the window behavior is unchanged (spec: One Settings window, Settings window buttons). Verify with `just run`:
  - Gear and Cmd+, open Settings on General.
  - A second open brings the same window to the front.
  - Red closes the window and the app keeps running.
  - Yellow minimizes to the Dock.
  - No note, list, or menu window moves.
- [x] 2.3 Check the sidebar toggle (spec: Collapsible Settings sidebar). Verify with `just run`: hiding the sidebar lets the pane fill the window and keeps the title, and showing it again highlights the same entry.

## 3. Minimum size

- [x] 3.1 Set `hostingController.sizingOptions = [.minSize]` and remove `window.minSize` (design.md Decision 3). Give the detail one `.frame(minWidth: paneMinWidth, minHeight: 320)`. Measure `paneMinWidth`, starting at 420 (Decision 4):
  - Drag the window to its narrowest width on General, then on Integrations with "Connected as @login", "Reconnect…", and "Disconnect" all showing (connect a test account with an invalid token to see Reconnect).
  - Raise the value until nothing wraps mid-word.
  - Add a comment next to the constant naming the rows that set it.
  - Make long list titles and repository names in "Linked lists" truncate with an ellipsis.
  - Verify with `just run` against the spec scenarios "Drag to the narrowest width" and "Narrowest width on Integrations". Then hide the sidebar, drag to the narrowest width, and check that the pane still fits.
  - Also verify that switching panes never resizes or moves the window.
- [x] 3.2 After `setFrameAutosaveName`, call `layoutSubtreeIfNeeded()` on the content view, then grow the frame to at least `contentMinSize` when the restored frame is smaller (Decision 5).
  - Verify:
    - Run `defaults write com.alvarezjorge.Notely "NSWindow Frame NotelySettings" "100 100 290 500 0 0 1440 900"`.
    - `just run` and open Settings.
    - The window opens at no less than its minimum size (spec: Saved frame smaller than the minimum).
- [x] 3.3 With the sidebar hidden, shrink the window below the sidebar-shown minimum, then click the sidebar toggle. Verify the pane still shows every control in full (spec: Show the sidebar in a narrow window). If the pane squeezes, add the `onChange` window growth from design.md Risks, and verify again.

## Workflow follow-up

- Run `openspec validate native-settings-window --strict` before archiving.
- Archive the change once reviewed, so the `settings` spec gets the updated layout and the two new requirements.
