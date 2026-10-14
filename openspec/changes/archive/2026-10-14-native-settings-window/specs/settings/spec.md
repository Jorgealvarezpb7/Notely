# Spec Delta

## MODIFIED Requirements

### Requirement: Settings window layout
The Settings window SHALL show a sidebar at its leading edge with two entries, in this order: "General" and "Integrations". The selected entry MUST show highlighted, and the area beside the sidebar MUST show that entry's pane. The window title in the title bar MUST be the selected pane's name, and the pane MUST NOT repeat the name as a heading. Clicking an entry MUST show its pane and change the window title. The sidebar MUST reach up under the title bar, beside the window buttons.

#### Scenario: Switch to Integrations
- **WHEN** the Settings window shows General and the user clicks "Integrations" in the sidebar
- **THEN** "Integrations" shows highlighted and the window shows the Integrations pane
- **AND** the window title reads "Integrations"

#### Scenario: Pane name in the title bar
- **WHEN** the Settings window opens
- **THEN** the window title reads "General"
- **AND** the General pane shows no "General" heading of its own

## ADDED Requirements

### Requirement: Settings window minimum size
While the sidebar shows, the Settings window SHALL NOT shrink below the size at which every pane fits beside the sidebar. While the sidebar is hidden, the window SHALL NOT shrink below the size at which every pane fits alone. At either minimum, no pane label, value, or window title MUST wrap mid-word, and no control MUST be cut off or hidden. The minimum MUST hold for every window edge and corner.

#### Scenario: Drag to the narrowest width
- **WHEN** the user drags the Settings window's edge inward as far as it goes while General shows
- **THEN** the window stops at its minimum width
- **AND** "Font", "Text size", the text size slider, and the "15 pt" value all show on one line each

#### Scenario: Narrowest width on Integrations
- **WHEN** the Settings window is at its minimum width and the user clicks "Integrations"
- **THEN** every Integrations control shows in full without wrapping mid-word

#### Scenario: Saved frame smaller than the minimum
- **WHEN** the Settings window was last closed at a size smaller than its minimum and the user opens Settings
- **THEN** the window opens at no less than its minimum size

### Requirement: Collapsible Settings sidebar
The Settings window SHALL show the standard sidebar toggle button in its title bar. Clicking it MUST hide the sidebar and let the selected pane fill the window, and clicking it again MUST show the sidebar. Hiding the sidebar MUST NOT change the selected pane.

#### Scenario: Hide the sidebar
- **WHEN** the Settings window shows General and the user clicks the sidebar toggle button
- **THEN** the sidebar hides and the General pane fills the window
- **AND** the window title still reads "General"

#### Scenario: Show the sidebar again
- **WHEN** the sidebar is hidden and the user clicks the sidebar toggle button
- **THEN** the sidebar shows with "General" highlighted

#### Scenario: Show the sidebar in a narrow window
- **WHEN** the sidebar is hidden, the window is narrower than its minimum with the sidebar shown, and the user clicks the sidebar toggle button
- **THEN** the sidebar shows and the pane still shows every control in full without wrapping mid-word
