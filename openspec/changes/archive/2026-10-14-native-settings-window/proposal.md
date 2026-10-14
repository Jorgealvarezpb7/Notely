# Proposal

## Why

The user can shrink the Settings window to about 290 points wide. The window then breaks: the pane heading wraps ("Gene-ral"), form labels wrap ("Fo/nt"), and the text size slider no longer fits. The window sets `minSize` to 520×320, but the SwiftUI hosting view lowers `contentMinSize` to its own fitting size, so the limit does not hold. The window also builds its own sidebar from an `HStack` and draws its own pane heading. A native macOS settings window (like System Settings) gets these from the system.

## What Changes

- Build the Settings window content with `NavigationSplitView`: the sidebar with "General" and "Integrations" in one column, the selected pane in the detail column.
- Show the selected pane's name as the window title in the toolbar, not as a large heading inside the pane.
- Run the sidebar up under the title bar (full-size content view), with the system sidebar material and the system sidebar toggle button.
- Let the SwiftUI layout set the window's minimum size from the column minimum widths. Remove the hard-coded `minSize` that does not hold.
- Make sure the user cannot shrink the window until labels wrap or controls are cut off. The user can collapse the sidebar with the system toggle. The pane then gets the whole window, and the window can shrink to the pane's own minimum.
- Bring a saved frame that is smaller than the new minimum (from before this fix) back up to the minimum when the window opens.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `settings`: "Settings window layout" changes. The pane's name now shows as the window title, not as a heading in the pane, and the sidebar can be collapsed. A new requirement covers the window's minimum size and resizing.

## Impact

- `Sources/NotelyUI/Settings/SettingsWindowController.swift`: window style mask and toolbar, `NSHostingController` as content view controller, `SettingsView` rebuilt on `NavigationSplitView`.
- `Sources/NotelyUI/Settings/GeneralPane.swift` and `IntegrationsPane.swift`: expected to stay the same. Their widest content sets the detail column minimum width.
- No change to note, list, or menu windows. No new dependencies. The deployment target stays macOS 14.
