# Spec Delta

## ADDED Requirements

### Requirement: Font choice in Settings
Settings > General SHALL show a "Font" row with a pop-up menu of two entries: "American Typewriter" and "System". The pop-up MUST show the current font. Choosing an entry MUST make it the current font. Choosing the current entry MUST change nothing.

#### Scenario: Switch to the system font
- **WHEN** the current font is American Typewriter and the user chooses "System" in Settings > General
- **THEN** note and list text show in the macOS system font
- **AND** the Font pop-up shows "System"

#### Scenario: Font row shows the current font
- **WHEN** the current font is American Typewriter and the user opens Settings > General
- **THEN** the Font pop-up shows "American Typewriter"

### Requirement: Text size in Settings
Settings > General SHALL show a "Text size" row with a slider from 10 to 20 points in steps of 1, set to the current size, and the current size as a number of points. Moving the slider MUST change the text size while the user drags, and the shown number MUST follow.

#### Scenario: Make text smaller
- **WHEN** the size is 15 points and the user drags the slider to 12
- **THEN** note and list text show at 12 points while the slider is at 12
- **AND** the row shows "12 pt"

#### Scenario: Limits
- **WHEN** the user drags the slider fully to either end
- **THEN** the size stops at 10 points at the lower end and at 20 points at the upper end

## MODIFIED Requirements

### Requirement: Global text appearance setting
The app SHALL keep one font choice and one text size for all notes and lists. A change made in Settings MUST apply at once to every open note window and every open list window, and to every note or list opened later. Changing the font or the size MUST NOT change any note's text, list title, list items, checked state, window position, or window size.

#### Scenario: Change applies to every window
- **WHEN** a note window and a list window are open and the user chooses "System" in Settings > General
- **THEN** the note text and the list's title and items both show in the system font

#### Scenario: Closed note opens with the setting
- **WHEN** the user sets the size to 18 and then opens a closed note from the menu
- **THEN** that note's text shows at 18 points

#### Scenario: Content unchanged
- **WHEN** the user changes the font or the size
- **THEN** every note keeps its text and every list keeps its title, items, and checked items

### Requirement: Text appearance persists
The font choice and the text size SHALL persist across app quit and relaunch without an explicit save action. With no saved setting, the font MUST be American Typewriter and the size MUST be 15 points. A saved size outside 10 to 20 points MUST be brought to the nearest of those limits, and an unknown saved font MUST be treated as American Typewriter. Notes and lists saved by earlier versions MUST open unchanged, using the setting.

#### Scenario: Relaunch keeps the setting
- **WHEN** the user chooses "System" and size 12, quits the app, and launches it again
- **THEN** every note and list shows its text in the system font at 12 points

#### Scenario: First launch of this version
- **WHEN** the app launches with notes saved by a version without the bottom bar
- **THEN** every note and list shows in American Typewriter at 15 points
- **AND** the Font pop-up in Settings > General shows "American Typewriter"

### Requirement: Menu rows follow the font
Rows in the menu window, "+ New", note rows, list rows, "+ New Note", and "+ New List" included, SHALL show in the current font choice. Menu rows MUST stay at 15 points whatever the text size setting is.

#### Scenario: Menu font follows the choice
- **WHEN** the user chooses "System" in Settings > General
- **THEN** the menu window's rows show in the system font

#### Scenario: Menu size stays fixed
- **WHEN** the user sets the text size to 20 points
- **THEN** note text shows at 20 points
- **AND** the menu window's rows stay at 15 points

### Requirement: Buttons usable at minimum window size
At the minimum note window size, a note window SHALL show the Bold, Italic, Underline, gear, and tint buttons and the drag area's "−" and trash buttons fully inside the window, without overlap, and at least one full line of text at the largest text size. A list window at the minimum size MUST show the GitHub and refresh buttons when they show, the gear and tint buttons, "−", and trash fully inside the window, and at least one full line of text at the largest text size.

#### Scenario: Smallest window, largest text
- **WHEN** a note window is at its minimum size and the text size is 20 points
- **THEN** the window shows Bold, Italic, Underline, the gear button, the tint button, "−", and trash, none of them overlapping
- **AND** at least one full line of note text shows

#### Scenario: Smallest list window
- **WHEN** a linked list window is at its minimum size and the text size is 20 points
- **THEN** the window shows the GitHub button, the refresh button, the gear button, the tint button, "−", and trash, none of them overlapping
- **AND** at least one full line of list text shows

## REMOVED Requirements

### Requirement: Font and size buttons in the bottom bar
**Reason**: Font and text size move to Settings > General, so the bottom bar has room for the gear and GitHub buttons.
**Migration**: Use the gear button or Notely > Settings… (Cmd+,), then Settings > General. The saved font and size carry over unchanged.

### Requirement: Font menu
**Reason**: Replaced by the Font pop-up in Settings > General ("Font choice in Settings").
**Migration**: Choose the font in Settings > General.

### Requirement: Text size popover
**Reason**: Replaced by the Text size slider in Settings > General ("Text size in Settings").
**Migration**: Set the size in Settings > General.
