# multiple-notes Specification

## Purpose

Lets the user keep several separate notes on screen, each in its own window, and close or delete a note from buttons on its window.

## Requirements

### Requirement: Independent note panels
Each note SHALL have its own panel, its own text, and its own position. Typing in one note MUST NOT change the text of another note. Moving one panel MUST NOT move another panel.

#### Scenario: Type in one of two notes
- **WHEN** two notes are open and the user types text in the first note
- **THEN** the text appears only in the first note
- **AND** the second note's text is unchanged

#### Scenario: Move one of two notes
- **WHEN** two notes are open and the user drags the first panel's drag area
- **THEN** only the first panel moves

### Requirement: Panel buttons do not move the panel
Clicking "−" or the trash button MUST NOT start a panel drag. Dragging a part of the drag area that is not a button MUST still move the panel. The drag area MUST show no buttons other than "−" and the trash button. The trash button MUST sit at least 16 points from the "−" button, so the user does not click one for the other.

#### Scenario: Click a panel button
- **WHEN** the user presses and drags from the "−" or trash button
- **THEN** the panel does not move

#### Scenario: Drag area buttons
- **WHEN** a note panel is open
- **THEN** its drag area shows a "−" button and a trash button, and no other buttons
- **AND** the gap between the two buttons is at least 16 points

### Requirement: All notes restored on launch
On launch, the app SHALL open one panel for every note whose window was open when the app last quit, each with its saved text and its saved position. Notes whose window was closed MUST NOT open a panel. Notes saved by a version without closing MUST open a panel.

#### Scenario: Relaunch with three notes
- **WHEN** three notes with different text are open at different positions, the user quits the app, and launches it again
- **THEN** three panels open, each with the same text at the same position as before

#### Scenario: Relaunch with one closed note
- **WHEN** two notes are open, the user closes one with "−", quits the app, and launches it again
- **THEN** only the other note's panel opens
- **AND** the menu lists both notes

#### Scenario: Notes saved by an earlier version
- **WHEN** the app launches with notes saved by a version without the menu
- **THEN** every one of those notes opens a panel with its text and position

### Requirement: Existing note kept on upgrade
The first launch of a version with multiple notes SHALL open the note that the single-note version saved, with its text and its position.

#### Scenario: Upgrade from single note
- **WHEN** the single-note version saved note text and a panel position, and the user launches the multiple-note version for the first time
- **THEN** one panel opens with the same text at the same position

### Requirement: Close a note from its panel
Every panel's drag area SHALL show a "−" button. Clicking "−" MUST close that note's window and MUST keep the note's text, position, and size. The note MUST stay listed in the menu and MUST open again from its row. Other notes MUST stay open and unchanged. A closed note MUST NOT open at the next launch until the user opens it from the menu.

#### Scenario: Click "−"
- **WHEN** two notes are open and the user clicks "−" on the first panel
- **THEN** the first panel closes
- **AND** the menu still lists the first note
- **AND** the second panel stays open with its text unchanged

#### Scenario: Closed note stays closed after relaunch
- **WHEN** the user clicks "−" on a note, quits the app, and launches it again
- **THEN** that note's window does not open
- **AND** the menu lists that note, and clicking its row opens it with its text unchanged

#### Scenario: Close the only open note
- **WHEN** one note window is open and the user clicks "−" on it
- **THEN** the note window closes and the app keeps running with the menu open

#### Scenario: Click "−" while another app is frontmost
- **WHEN** another application is frontmost and the user clicks "−" once
- **THEN** the panel closes on that click

### Requirement: Delete a note from its panel
Every panel's drag area SHALL show a trash button. Clicking the trash button MUST show a confirmation sheet on that panel that names the note and offers "Cancel" and "Delete". "Cancel" MUST be the default button, so Return and Esc cancel. Only clicking "Delete" MUST close that panel and delete the note. Cancelling MUST keep the note and its panel unchanged. After a delete, the menu MUST stop listing that note at once, other notes MUST stay open and unchanged, and the deleted note MUST NOT return on the next launch.

#### Scenario: Click trash with two notes open
- **WHEN** two notes are open, the user clicks the trash button on the first panel, and clicks "Delete"
- **THEN** the first panel closes and the menu no longer lists the first note
- **AND** the second panel stays open with its text unchanged

#### Scenario: Cancel a delete
- **WHEN** the user clicks the trash button on a note and then clicks "Cancel", or presses Return or Esc
- **THEN** the sheet closes, and the note stays open with its text unchanged

#### Scenario: Removed note stays removed
- **WHEN** the user deletes a note with the trash button and "Delete", quits the app, and launches it again
- **THEN** the removed note does not open and the menu does not list it

#### Scenario: Click trash while another app is frontmost
- **WHEN** another application is frontmost and the user clicks the trash button once
- **THEN** the confirmation sheet shows on that click

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
