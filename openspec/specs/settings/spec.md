# settings Specification

## Purpose
Gives the app one Settings window for global preferences and integrations, opened from every note and list window and from the app menu.

## Requirements

### Requirement: Gear button in the bottom bar
The bottom bar of every note window and every list window SHALL show a gear button at its trailing edge, before the tint button. The gear button MUST use the same borderless icon style and size as the other bottom bar buttons, and MUST work on the first click, also while another application is active. Clicking it MUST open the Settings window and MUST NOT move the note or list window. The menu window MUST NOT show a gear button.

#### Scenario: Gear in a note window
- **WHEN** a note window is open
- **THEN** its bottom bar shows the gear button and then the tint button at the trailing edge

#### Scenario: Gear in a list window
- **WHEN** a list window is open and its items are taller than the window
- **THEN** its bottom bar shows the gear button before the tint button
- **AND** clicking the gear button opens the Settings window, not a list row

#### Scenario: Click while another app is active
- **WHEN** another application is active and the user clicks the gear button of a note window
- **THEN** the Settings window opens with that one click

#### Scenario: No gear in the menu window
- **WHEN** the menu window is open
- **THEN** it shows no gear button

### Requirement: Settings from the app menu
The app menu SHALL contain a "Settings…" item with the shortcut Cmd+, that opens the Settings window. Cmd+, MUST work while any note window, list window, or the menu window is the key window.

#### Scenario: Cmd+, in a note
- **WHEN** a note area has keyboard focus and the user presses Cmd+,
- **THEN** the Settings window opens

#### Scenario: Settings item in the app menu
- **WHEN** the app is active and the user chooses "Settings…" from the app menu
- **THEN** the Settings window opens

### Requirement: One Settings window
Only one Settings window SHALL exist while the app runs. Opening Settings while the window is open MUST bring it to the front and make it the key window, and MUST NOT open a second window. The Settings window MUST open on the General pane. The Settings window MUST stack with other applications' windows as a normal window.

#### Scenario: Open Settings twice
- **WHEN** the Settings window is open behind a note window and the user clicks that note's gear button
- **THEN** the Settings window comes to the front
- **AND** no second Settings window opens

#### Scenario: Opens on General
- **WHEN** the Settings window is closed and the user clicks a gear button
- **THEN** the Settings window opens showing the General pane

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

### Requirement: Settings window buttons
The Settings window SHALL show the standard red, yellow, and green window buttons. Clicking red MUST close the Settings window and MUST NOT quit the app. Clicking yellow MUST minimize the Settings window to the Dock. Opening or closing the Settings window MUST NOT move, resize, open, or close any note, list, or menu window.

#### Scenario: Close Settings
- **WHEN** the Settings window is open and the user clicks its red button
- **THEN** the Settings window closes
- **AND** the app keeps running and every note window stays open

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
