# note-tint Specification

## Purpose

Lets the user give each note and list window its own color tint. The tint shows over the window's translucent background and keeps the native translucent look.

## Requirements

### Requirement: Tint button in the bottom bar
The bottom bar of every note window and every list window SHALL show a tint button at its trailing edge, after the gear button.
- The tint button MUST use the same borderless icon style and size as the other bottom bar buttons.
- When the note has a tint, the button MUST show a filled circle in the note's tint color, at full strength.
- When the note has no tint, the button MUST show a circle outline in the same color as the other bottom bar icons.
- The button MUST work on the first click, also while another application is active.
- Clicking the button MUST open the tint menu and MUST NOT move the window.
- The menu window MUST NOT show a tint button.

#### Scenario: Button in a note window
- **WHEN** a note window is open
- **THEN** its bottom bar shows the tint button after the gear button, at the trailing edge

#### Scenario: Button in a list window
- **WHEN** a list window is open and its items are taller than the window
- **THEN** its bottom bar shows the tint button after the gear button
- **AND** clicking the tint button opens the tint menu, not a list row

#### Scenario: Button shows the tint
- **WHEN** a note's tint is blue
- **THEN** that note's tint button shows a filled blue circle

#### Scenario: Button with no tint
- **WHEN** a note has no tint
- **THEN** that note's tint button shows a circle outline in the color of the other bottom bar icons

#### Scenario: Click while another app is active
- **WHEN** another application is active and the user clicks the tint button of a note window
- **THEN** the tint menu opens with that one click

#### Scenario: No tint button in the menu window
- **WHEN** the menu window is open
- **THEN** it shows no tint button

### Requirement: Tint menu
Clicking the tint button SHALL open a menu at the button. The menu MUST show these entries, in this order:
1. "Default".
2. A separator.
3. One entry per preset color: "Yellow", "Orange", "Pink", "Purple", "Blue", "Green", and "Gray". Each entry MUST show a filled circle in its color.
4. A separator.
5. "Other Colors…".

The entry that matches the note's current tint MUST show a check mark. "Default" MUST show the check mark when the note has no tint. No entry MUST show the check mark when the note has a custom color that matches no preset. Choosing "Default" MUST remove the note's tint. Choosing a preset color MUST set the note's tint to that color. Choosing either MUST close the menu. Pressing Esc or clicking outside the menu MUST close it without a change.

#### Scenario: Choose a preset color
- **WHEN** a note has no tint and the user chooses "Green" from its tint menu
- **THEN** the note shows a green tint
- **AND** the next time the tint menu opens, "Green" shows the check mark

#### Scenario: Back to default
- **WHEN** a note has a tint and the user chooses "Default" from its tint menu
- **THEN** the note looks as it did with no tint
- **AND** the tint button shows a circle outline

#### Scenario: Custom color shows no check mark
- **WHEN** a note has a custom color that matches no preset and the user opens its tint menu
- **THEN** no entry shows a check mark

#### Scenario: Dismiss the menu
- **WHEN** the tint menu is open and the user presses Esc
- **THEN** the menu closes and the note's tint is unchanged

### Requirement: Custom tint color
Choosing "Other Colors…" SHALL open the macOS color panel, set to the note's current tint, or to white when the note has no tint.
- The color panel MUST let the user choose any color.
- The color panel MUST NOT show an opacity control.
- While the user changes the color in the panel, the note's tint MUST follow at once.
- The color panel MUST change only the tint of the window from which the user last chose "Other Colors…".
- After the user chooses "Other Colors…" in a second window, changes in the color panel MUST apply to that second window only.
- Closing the color panel MUST keep the tint last set.
- When the window that the color panel changes closes, through "−" or a delete, the color panel MUST close too. When the window of another note closes, the color panel MUST stay open.
- Clicking the trash button of any note or list MUST close the color panel before the delete confirmation sheet shows, so the panel never covers the sheet. The tint last set MUST be kept, also when the user then clicks "Cancel".
- A color that reaches the note with an opacity below full, for example from the eyedropper, MUST be used as the same color at full opacity.

#### Scenario: Pick any color
- **WHEN** the user chooses "Other Colors…" and picks a teal color in the color panel
- **THEN** the note shows a teal tint while the user picks

#### Scenario: Panel changes one note
- **WHEN** two notes are open, the user opens the color panel from the first note and picks red
- **THEN** only the first note shows a red tint
- **AND** the second note's tint is unchanged

#### Scenario: Panel follows the last note
- **WHEN** the color panel is open for the first note and the user chooses "Other Colors…" in the second note, then picks orange
- **THEN** the second note shows an orange tint
- **AND** the first note keeps its earlier tint

#### Scenario: Close the note that owns the panel
- **WHEN** the color panel is open for a note and the user closes that note with "−"
- **THEN** the color panel closes
- **AND** the note keeps the tint last set in the panel

#### Scenario: Delete the note that owns the panel
- **WHEN** the color panel is open for a note and the user deletes that note with trash and "Delete"
- **THEN** the color panel closes

#### Scenario: Trash closes the panel
- **WHEN** the color panel is open and the user clicks the trash button of any note
- **THEN** the color panel closes and the confirmation sheet shows uncovered
- **AND** after "Cancel", the note keeps the tint last set in the panel

#### Scenario: Close another note
- **WHEN** the color panel is open for the first note and the user closes the second note with "−"
- **THEN** the color panel stays open and still changes the first note

#### Scenario: No opacity control
- **WHEN** the color panel is open from a tint menu
- **THEN** the panel shows no opacity slider

### Requirement: Tint keeps the window translucent
A note's tint SHALL show as a wash of its color over the window's translucent background.
- The translucent background, its blur, and the desktop and windows behind it showing through MUST stay as they are without a tint.
- Every tint color MUST show at the same fixed strength. That strength MUST let the content behind the window show through, so a tinted window is never opaque.
- The tint MUST fill the whole window, the drag area and the bottom bar included. The bars MUST keep their shaded fill over the tint.
- A tint MUST NOT change the window's light or dark appearance. A tint MUST NOT change the color of the note text, list text, placeholders, links, check circles, buttons, or the logo. All of these MUST keep following the system appearance, as without a tint.

#### Scenario: Background shows through a tint
- **WHEN** a note has a tint and the user moves the window over a picture on the desktop
- **THEN** the picture shows blurred through the note, tinted by the note's color

#### Scenario: Black tint is not opaque
- **WHEN** the user chooses pure black in the color panel
- **THEN** the note shows darker, and the content behind it still shows through

#### Scenario: Text color unchanged by a tint
- **WHEN** the system appearance is dark and a note has a yellow tint
- **THEN** the note text shows white, as in a note with no tint

#### Scenario: Bars over a tint
- **WHEN** a note has a tint
- **THEN** the drag area and the bottom bar show their shaded fill over the tint, from the left edge to the right edge of the window

### Requirement: Each note has its own tint
Each note and each list SHALL have its own tint. Changing the tint of one window MUST NOT change the tint of any other note or list. Changing a tint MUST NOT change the note's text, styles, list title, list items, checked state, window position, or window size.

#### Scenario: Tint one of two notes
- **WHEN** two notes are open and the user chooses "Blue" in the first note's tint menu
- **THEN** only the first note shows a blue tint
- **AND** the second note looks as before

#### Scenario: Tint a list
- **WHEN** a note and a list are open and the user chooses "Pink" in the list's tint menu
- **THEN** only the list window shows a pink tint

#### Scenario: Content unchanged
- **WHEN** the user changes a note's tint
- **THEN** the note keeps its text, styles, position, and size

### Requirement: Tint persists
Each note's tint SHALL persist across app quit and relaunch, without an explicit save action. Each note's tint MUST also persist when the note is closed with "−" and opened again from the menu. A note with no saved tint MUST show with no tint. This includes every note saved by an earlier version. A saved tint that the app cannot read MUST be treated as no tint, and the note MUST still open with its text unchanged.

#### Scenario: Relaunch keeps the tint
- **WHEN** the user sets a note's tint to purple, quits the app, and launches it again
- **THEN** that note opens with a purple tint

#### Scenario: Reopen a closed note
- **WHEN** the user sets a note's tint to orange, closes the note with "−", and opens it again from the menu
- **THEN** the note opens with an orange tint

#### Scenario: Notes from an earlier version
- **WHEN** the app launches with notes saved by a version without tints
- **THEN** every note opens with no tint and looks as it did before

#### Scenario: Unreadable saved tint
- **WHEN** a note's saved tint cannot be read as a color
- **THEN** the note opens with no tint and its text unchanged
