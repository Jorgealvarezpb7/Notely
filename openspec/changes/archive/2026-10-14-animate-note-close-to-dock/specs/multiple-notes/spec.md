# Spec Delta

## ADDED Requirements

### Requirement: Close animation into the Dock
Clicking "−" SHALL play the system's minimize animation for the note's window, as set in System Settings, into the place macOS shows minimized windows in the Dock. When the animation ends, the note MUST close, and no Dock tile MUST stay for it. The app MUST NOT ask for any permission for this animation. The note MUST be saved and closed when the animation starts. The animation MUST NOT play while note animations are off in Settings or the system "Reduce motion" setting is on.

#### Scenario: Click "−"
- **WHEN** the user clicks "−" on a note
- **THEN** the note window minimizes into the Dock with the system animation
- **AND** the Dock then shows no tile for the note, and the menu still lists the note

#### Scenario: Minimize into the app icon
- **WHEN** "Minimize windows into application icon" is on and the user clicks "−" on a note
- **THEN** the note window minimizes into the Notely Dock icon

#### Scenario: No permission prompt
- **WHEN** the user clicks "−" on a note
- **THEN** no permission dialog or System Settings window opens

#### Scenario: Quit during the animation
- **WHEN** the user types in a note, clicks "−", and quits before the animation ends
- **THEN** the next launch keeps the note's full text and does not open its window

#### Scenario: Reduce motion
- **WHEN** the system "Reduce motion" setting is on and the user clicks "−" on a note
- **THEN** the note window closes at once, with no animation

### Requirement: Delete closes without animation
Deleting a note with the trash button and "Delete" SHALL close its window at once, with no animation.

#### Scenario: Delete a note
- **WHEN** the user clicks the trash button on a note and clicks "Delete"
- **THEN** the note window disappears at once, with no animation into the Dock
