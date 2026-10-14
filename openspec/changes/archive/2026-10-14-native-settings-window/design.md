# Design

## Context

`SettingsWindowController` creates a plain `NSWindow` and sets an `NSHostingView` as its `contentView`. `SettingsView` is an `HStack` holding a `List` fixed at 180 points, a `Divider`, and a pane with a `Text` heading. The hosting view keeps its default `sizingOptions`, so it writes SwiftUI's fitting size into `contentMinSize`. That beats the `minSize` of 520×320 set on the window (see proposal.md, Why).

The note windows hit the same AppKit rule. They opted out with `sizingOptions = []` and a `windowWillResize` clamp, because there the window owns its size (`NoteWindowController.swift`, comment on `windowWillResize`). For Settings, the content should own its size, so this design goes the other way.

The deployment target is macOS 14 (`Package.swift`). `NavigationSplitView`, `navigationSplitViewColumnWidth`, and `NSHostingController.sceneBridgingOptions` are all available.

## Goals / Non-Goals

**Goals:**
- The window looks and resizes like a system settings window. The system draws the sidebar, the toolbar, and the sidebar toggle.
- The SwiftUI layout sets the minimum size, in one place, so a new or wider pane raises it on its own.

**Non-Goals:**
- No change to `GeneralPane` or `IntegrationsPane` content, the account sheet, or what any setting does.
- No move to a SwiftUI `Settings` scene. The app runs from `main.swift` with an AppKit `AppDelegate`, and the controller must keep its `show(pane:)` entry point.
- No search field in the sidebar.

## Decisions

### 1. `NavigationSplitView` for the content

`SettingsView` becomes a two-column `NavigationSplitView`:
- The sidebar holds the existing `List(SettingsPane.allCases, selection:)`, with the same binding that ignores clicks on empty sidebar space. It gets `.navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)`.
- The detail shows the selected pane's `switch`, with `.navigationTitle(selection.pane.title)` and a minimum width (decision 4).

**Alternatives:** keep the `HStack` and only fix the minimum size (smallest diff, but no sidebar material, no toggle, and the heading stays custom). An AppKit `NSSplitViewController` with hosted panes (native, but two hosting controllers and more glue code for the same result).

### 2. `NSHostingController` as content view controller, with scene bridging

`makeWindow()` sets `window.contentViewController` to an `NSHostingController(rootView: SettingsView(...))` with `sceneBridgingOptions = [.title, .toolbars]`. `.navigationTitle` then becomes the window title, and `NavigationSplitView` puts its sidebar toggle in the window toolbar.

The window gains `.fullSizeContentView` in its style mask and `toolbarStyle = .unified`, so the sidebar reaches up beside the window buttons. `window.title = "Settings"` stays as the title until SwiftUI sets its own.

**Alternative:** keep `NSHostingView` and set `window.title` from an `onChange(of: selection.pane)`. This works for the title, but the toolbar and toggle would need a hand-built `NSToolbar` (see Risks for when that is still needed).

### 3. Only `.minSize` flows from SwiftUI to the window

Set `hostingController.sizingOptions = [.minSize]`. The window's `contentMinSize` then tracks the SwiftUI minimum: sidebar minimum plus detail minimum while the sidebar shows, and the detail minimum alone while it is hidden. This matches the spec. Leave out `.preferredContentSize` and `.intrinsicContentSize`, so switching panes never resizes or moves the window.

Remove `window.minSize`. It does nothing once the hosting controller sets `contentMinSize`, and a second number would only drift.

**Alternative:** a `windowWillResize` clamp like the note windows. That needs a hand-kept constant and does not know whether the sidebar shows.

### 4. One detail minimum width for every pane

Both panes sit in the same detail column, so the detail gets a single `.frame(minWidth: Self.paneMinWidth, minHeight: ...)`, set by the wider pane. Set it by measuring, not by guessing:
- General: the "Text size" row (label, `A`, 160-point slider, `A`, 40-point value) inside the grouped form insets.
- Integrations: the "Account" row at its widest ("Connected as @login" with "Reconnect…" and "Disconnect").

Start the measurement at 420 points. Keep the window's current minimum height of 320 points, as the detail `minHeight`.

User data, like long list titles or repository names in "Linked lists", is not a control. It truncates with an ellipsis instead of raising the minimum width.

### 5. Clamp a restored frame once

`setFrameAutosaveName` can restore a frame saved before this fix, narrower than the new minimum. After restoring, call `layoutSubtreeIfNeeded()` on the content view so the hosting controller publishes `contentMinSize`. Then, if the frame is smaller, grow it with `setContentSize` to at least `contentMinSize`.

## Risks / Trade-offs

- [Scene bridging does not add the sidebar toggle to a window that SwiftUI did not create] → Install an `NSToolbar` by hand, with `.toggleSidebar` and `.sidebarTrackingSeparator` items. Keep `.title` bridging, or fall back to setting `window.title` on selection change. Check this first, before the rest of the work.
- [The window title is now "General" or "Integrations", not "Settings", in the Window menu and Mission Control] → This is the System Settings convention. Accepted.
- [Showing the sidebar again in a narrow window can overlap or squeeze the pane] → Expect `NavigationSplitView` with `contentMinSize` to widen the window. Check by hand. If it squeezes the pane instead, grow the window in an `onChange` of the column visibility.
- [`List` selection inside `NavigationSplitView` can push an empty selection when the user clicks empty sidebar space] → Keep the existing binding that ignores `nil`.
- [Measured minimum goes stale when a pane grows] → The detail `minWidth` is the one place to update. Add a comment next to it naming the rows that set it.

## Migration Plan

No data migration. The autosaved frame under "NotelySettings" stays, and decision 5 fixes undersized ones. To roll back, revert the commit.
