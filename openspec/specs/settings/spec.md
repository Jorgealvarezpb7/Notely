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
The Settings window SHALL show a sidebar at its leading edge with two entries, in this order: "General" and "Integrations". The selected entry MUST show highlighted, and the area beside the sidebar MUST show that entry's pane, with the pane's name as its heading. Clicking an entry MUST show its pane.

#### Scenario: Switch to Integrations
- **WHEN** the Settings window shows General and the user clicks "Integrations" in the sidebar
- **THEN** "Integrations" shows highlighted and the window shows the Integrations pane

### Requirement: Settings window buttons
The Settings window SHALL show the standard red, yellow, and green window buttons. Clicking red MUST close the Settings window and MUST NOT quit the app. Clicking yellow MUST minimize the Settings window to the Dock. Opening or closing the Settings window MUST NOT move, resize, open, or close any note, list, or menu window.

#### Scenario: Close Settings
- **WHEN** the Settings window is open and the user clicks its red button
- **THEN** the Settings window closes
- **AND** the app keeps running and every note window stays open
