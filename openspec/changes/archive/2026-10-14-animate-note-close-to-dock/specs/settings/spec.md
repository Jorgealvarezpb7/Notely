# Spec Delta

## ADDED Requirements

### Requirement: Note animation setting
The General pane SHALL show a "Windows" section, after the "Text" section, with an "Animate closing and opening notes" switch. The switch MUST be on when nothing is saved, and its state MUST be kept across launches. While it is off, closing a note with "−" and opening a closed note from the menu MUST happen at once, with no animation. The note animations MUST play only while the switch is on and the system "Reduce motion" setting is off.

#### Scenario: Default on
- **WHEN** the user opens Settings for the first time
- **THEN** the General pane shows "Animate closing and opening notes" switched on

#### Scenario: Turn animations off
- **WHEN** the user switches "Animate closing and opening notes" off, clicks "−" on a note, and then clicks its row in the menu
- **THEN** the note closes at once and opens at once, with no animation
- **AND** the change applies without relaunching the app, also to notes that were already open

#### Scenario: Kept across launches
- **WHEN** the user switches the setting off, quits the app, and launches it again
- **THEN** the switch is still off, and notes close and open with no animation

#### Scenario: System Reduce motion wins
- **WHEN** the switch is on and the system "Reduce motion" setting is on
- **THEN** notes close and open at once, with no animation

#### Scenario: Fits at the minimum width
- **WHEN** the Settings window is at its minimum width and shows General
- **THEN** "Animate closing and opening notes" and its switch show on one line
