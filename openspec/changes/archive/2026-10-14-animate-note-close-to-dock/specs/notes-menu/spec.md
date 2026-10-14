# Spec Delta

## ADDED Requirements

### Requirement: Reopen animation from the Dock
Clicking the row of a closed note SHALL play the system's restore animation for the note's window, out of the Dock to the note's saved position and size, without the user clicking the Dock. The app MUST NOT ask for any permission. When the animation ends, the note window MUST show in front and be the key window. The animation MUST NOT play while note animations are off in Settings or the system "Reduce motion" setting is on.

#### Scenario: Reopen a closed note
- **WHEN** a note is closed and the user clicks its row
- **THEN** the note window restores out of the Dock with the system animation, to its saved position and size
- **AND** the note window then shows in front with its text unchanged and receives keystrokes

#### Scenario: Double-click the row
- **WHEN** a note is closed and the user double-clicks its row
- **THEN** exactly one window opens for the note, and no tile for it stays in the Dock

#### Scenario: Row of an open note
- **WHEN** a note window is open and the user clicks its row
- **THEN** the note window comes to the front with no animation

#### Scenario: Reduce motion
- **WHEN** the system "Reduce motion" setting is on, a note is closed, and the user clicks its row
- **THEN** the note window opens at once, with no animation

#### Scenario: Launch and new notes
- **WHEN** the app launches with open notes, or the user clicks "+ New"
- **THEN** those note windows open with no animation
