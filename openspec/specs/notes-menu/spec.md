# notes-menu Specification

## Purpose

Gives the user one window that lists every saved note, opens notes, and creates new notes, with the standard macOS traffic lights to quit the app, minimize the menu, and zoom it.

## Requirements

### Requirement: Menu window
The app SHALL show one menu window. The menu window MUST open at every launch. Only one menu window MUST exist while the app runs. The menu window MUST stack with other applications' windows as a normal window, and clicking it MUST bring it to the front and make the app the active application.

#### Scenario: Launch shows the menu
- **WHEN** the app launches
- **THEN** the menu window opens

#### Scenario: First launch
- **WHEN** the app launches with no saved note
- **THEN** the menu window opens
- **AND** one empty note window opens, and the menu lists that note

#### Scenario: Click the menu behind another app
- **WHEN** the menu window is partly behind a window of another application and the user clicks the visible part of the menu window
- **THEN** the menu window comes to the front
- **AND** the menu bar shows the app's menus

### Requirement: Menu traffic lights
The menu window SHALL show the standard red, yellow, and green window buttons at its top-left corner. Clicking red MUST quit the app. Clicking yellow MUST minimize the menu window to the Dock. Clicking green, and pressing and holding green, MUST give the standard macOS zoom and full-screen behavior for the menu window. Note windows MUST NOT show red, yellow, or green window buttons. The zoom, full-screen, and tiling options MUST apply only to the menu window: they MUST NOT move, resize, or tile a note window, and a note window MUST NOT be offered as a tile.

#### Scenario: Click red
- **WHEN** the user clicks the menu window's red button
- **THEN** the app quits
- **AND** every note window, the menu window, and the Dock icon disappear

#### Scenario: Click yellow
- **WHEN** the user clicks the menu window's yellow button
- **THEN** the menu window minimizes to the Dock
- **AND** every open note window stays open

#### Scenario: Click green
- **WHEN** the user clicks the menu window's green button
- **THEN** the menu window enters full screen
- **AND** clicking green again in full screen returns the menu window to its previous frame

#### Scenario: Hold green
- **WHEN** the user presses and holds the menu window's green button
- **THEN** the standard macOS window-tiling and full-screen options show

#### Scenario: Tile the menu
- **WHEN** a note window is open and the user chooses a tiling option from the menu window's green button
- **THEN** only the menu window moves and resizes
- **AND** no note window is offered to fill the other tile, and every note window keeps its position and size

#### Scenario: Note windows have no traffic lights
- **WHEN** a note window is open
- **THEN** it shows no red, yellow, or green button

### Requirement: Note list
The menu window SHALL show a "+ New" row first, followed by one row for every saved note and list, whether its window is open or closed. Rows MUST be ordered newest first, with notes and lists mixed. A note row's title MUST be the first line of the note's text that is not empty after trimming spaces, or "Untitled note" when the note has no such line. A list row's title MUST be the list's title after trimming spaces, or "Untitled list" when that is empty, and a list row MUST show a checklist icon at its trailing edge. A row's title MUST update while the user types in that note or list title. When the list is longer than the menu window, the menu MUST scroll vertically. While the pointer is over an enabled row or the chooser's "<--" control, that control MUST show a lighter background; disabled rows MUST NOT change.

#### Scenario: Rows for open and closed notes
- **WHEN** one note window is open and one note is closed
- **THEN** the menu shows "+ New" and then one row for each of the two notes

#### Scenario: Newest first
- **WHEN** the user creates note A and then note B
- **THEN** note B's row is above note A's row

#### Scenario: Row title from text
- **WHEN** a note's text is "\n  Groceries\nmilk"
- **THEN** that note's row shows "Groceries"

#### Scenario: Empty note title
- **WHEN** a note's text is empty or only spaces and line breaks
- **THEN** that note's row shows "Untitled note"

#### Scenario: Hover a row
- **WHEN** the pointer moves over a note row
- **THEN** that row shows a lighter background
- **AND** the background returns to normal when the pointer leaves the row

#### Scenario: Title follows typing
- **WHEN** the user changes the first line of an open note
- **THEN** that note's row shows the new first line without the user doing anything else

#### Scenario: List row
- **WHEN** a list's title is "Groceries"
- **THEN** its row shows "Groceries" and a checklist icon at the trailing edge
- **AND** when the title is empty, the row shows "Untitled list"

#### Scenario: Notes and lists mixed
- **WHEN** the user creates note A, then list B, then note C
- **THEN** the rows show C, B, and A, in that order

### Requirement: Open a note from the menu
Clicking a note's row SHALL show that note's window in front of other windows and make it the key window. When the note window is closed, it MUST open with the note's saved text, position, and size. When the note window is already open, it MUST NOT move or change size, and no second window MUST open for that note.

#### Scenario: Open a closed note
- **WHEN** the user closes a note with "−" and then clicks its row in the menu
- **THEN** the note window opens at the position and size it had when closed, with its text unchanged

#### Scenario: Click the row of an open note
- **WHEN** a note window is open behind other windows and the user clicks its row
- **THEN** that note window comes to the front at the same position and size
- **AND** no other window opens for that note

### Requirement: Create a note from the menu
Clicking "+ New Note" SHALL create one new, empty note and open its window with placeholder text, at 220 by 150 points. The new window's top edge MUST line up with the menu window's top edge, 12 points to the right of the menu window. When that frame is not fully inside the visible area of the menu window's screen, the window MUST open 12 points to the left of the menu window instead. When neither frame is fully inside that visible area, the window MUST move the shortest distance from the right-hand frame to be fully inside it. The new note's text area MUST receive keyboard focus. The menu window MUST then show the note list with the new note's row first.

#### Scenario: Click "+ New Note"
- **WHEN** the menu has room on its right and the user clicks "+ New Note"
- **THEN** a new 220 by 150 point note window opens 12 points to the right of the menu, top edges aligned
- **AND** the new note area is empty, shows placeholder text, and receives keystrokes
- **AND** the menu shows the note list with "Untitled note" as the first note row

#### Scenario: Menu at the right screen edge
- **WHEN** the menu window touches the right edge of its screen's visible area and the user clicks "+ New Note"
- **THEN** the new note window opens 12 points to the left of the menu, top edges aligned

#### Scenario: No room on either side
- **WHEN** the menu window fills its screen's visible area and the user clicks "+ New Note"
- **THEN** the new note window opens fully inside that visible area

### Requirement: Menu frame persists
The menu window SHALL open at the position and size it had when the app last quit. With no saved frame, it MUST open at 260 by 360 points, 20 points from the top and left edges of the main screen's visible area. The menu window MUST NOT become smaller than 200 by 200 points, and MUST always open fully inside one screen's visible area.

#### Scenario: Relaunch keeps menu frame
- **WHEN** the user moves and resizes the menu window, quits the app, and launches it again
- **THEN** the menu window opens at the same position and size

#### Scenario: First launch menu frame
- **WHEN** the app launches with no saved menu frame
- **THEN** the menu window opens at 260 by 360 points, 20 points from the top and left edges of the main screen's visible area

#### Scenario: Shrink the menu
- **WHEN** the user drags a menu window corner inward past 200 by 200 points
- **THEN** the menu window stops at 200 by 200 points

### Requirement: App keeps running with no notes
Deleting the last note SHALL NOT quit the app. The menu window MUST stay open and show only "+ New". The next launch MUST open the menu window with no note windows and no note rows.

#### Scenario: Delete the last note
- **WHEN** one note exists and the user clicks its trash button and then "Delete"
- **THEN** the note window closes and the app keeps running
- **AND** the menu shows only "+ New"

#### Scenario: Launch with no notes
- **WHEN** the user deleted every note, quits the app, and launches it again
- **THEN** the menu window opens and shows only "+ New"
- **AND** no note window opens

### Requirement: New chooser with lists
Clicking "+ New" SHALL replace the note list in the menu window with a chooser. The chooser MUST show a "<--" back control at its top-right, a "+ New Note" row, and a "+ New List" row, both enabled. Clicking "<--" MUST show the note list again without creating anything.

#### Scenario: Open the chooser
- **WHEN** the user clicks "+ New" in the menu
- **THEN** the menu window shows "<--", "+ New Note", and "+ New List"
- **AND** "+ New List" looks enabled and reacts to hover

#### Scenario: Back from the chooser
- **WHEN** the chooser shows and the user clicks "<--"
- **THEN** the menu window shows the note list
- **AND** nothing is created

### Requirement: Create a list from the menu
Clicking "+ New List" SHALL create one new list with an empty title and no items, and open its window at the same frame a new note would get: 220 by 150 points, placed next to the menu window by the rules of "Create a note from the menu". The new list's title MUST receive keyboard focus. The menu window MUST then show the note list with the new list's row first.

#### Scenario: Click "+ New List"
- **WHEN** the menu has room on its right and the user clicks "+ New List"
- **THEN** a new 220 by 150 point list window opens 12 points to the right of the menu, top edges aligned
- **AND** its title row shows "Untitled list" and receives keystrokes
- **AND** the menu shows the note list with "Untitled list" as the first row

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
