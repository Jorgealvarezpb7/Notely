# sticky-note Specification

## Purpose

Provides note windows that the user can type into, and that keep their text and position between app launches.

## Requirements

### Requirement: Editable note text
Every note panel SHALL show one note area in place of the previous greeting and clock. The user MUST be able to type, delete, select, copy, and paste text in each note area. Note text MAY carry bold, italic, and underline styles as defined by the text-styles capability; it MUST NOT carry any other formatting. Web addresses in note text show as links as defined by the links capability; that display is not formatting the note carries.

#### Scenario: Type into the note
- **WHEN** the user clicks inside a note area and types characters
- **THEN** the typed characters appear in that note area at the caret position

#### Scenario: Standard editing shortcuts
- **WHEN** a note area has keyboard focus and the user presses Cmd+A, Cmd+C, Cmd+V, Cmd+X, or Cmd+Z
- **THEN** that note area performs select all, copy, paste, cut, or undo on its note text

#### Scenario: Long text
- **WHEN** a note's text is longer than the visible note area
- **THEN** the note area scrolls vertically and the note window keeps its current size

#### Scenario: Greeting and clock removed
- **WHEN** the app launches
- **THEN** no panel shows greeting text or a clock

#### Scenario: No other formatting
- **WHEN** the user pastes text with colors and links whose visible text is not a web address into a note area
- **THEN** the note shows the text with no colors and no links

### Requirement: End editing
The user SHALL be able to end editing from the keyboard and with the pointer. Pressing Esc, or clicking the window's drag area or bottom bar, MUST end editing. Ending editing MUST remove keyboard focus from the note area and MUST keep the note text. A click on the drag area or bottom bar MUST end editing also when the user then drags the window.

#### Scenario: Press Esc while editing
- **WHEN** the note area has keyboard focus and the user presses Esc
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Click the drag area while editing
- **WHEN** the note area has keyboard focus and the user clicks the drag area, outside the "−" and trash buttons
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Click the bottom bar while editing
- **WHEN** the note area has keyboard focus and the user clicks the bottom bar
- **THEN** the note area loses keyboard focus and shows no caret
- **AND** the note text is unchanged

#### Scenario: Drag the window while editing
- **WHEN** the note area has keyboard focus and the user drags the drag area
- **THEN** the window moves with the pointer
- **AND** the note area shows no caret after the drag

#### Scenario: Click the note area again
- **WHEN** editing has ended and the user clicks inside the note area
- **THEN** the note area gets keyboard focus and shows the caret at the clicked position

### Requirement: Note persistence
The text of every note SHALL persist across app quit and relaunch. Changes MUST be saved without an explicit save action.

#### Scenario: Relaunch keeps text
- **WHEN** the user types text in a note, quits the app, and launches it again
- **THEN** that note shows the same text

#### Scenario: First launch
- **WHEN** the app launches with no saved note
- **THEN** one note opens, and its note area is empty and shows placeholder text that invites the user to type

#### Scenario: Save without explicit action
- **WHEN** the user types text in any note and the app is quit normally within one second of the last keystroke
- **THEN** the next launch shows that note's full text including the last keystroke

### Requirement: Panel stays movable
The user SHALL be able to move the panel by dragging a visible area that is not the text. Every note window MUST show a drag area across its top edge and a bottom bar across its bottom edge. Both MUST span the full width of the window. The bottom bar MUST be 20% lower than the drag area. Both MUST show a shaded fill that sets them apart from the note area: darker than the note area in light appearance and lighter in dark appearance. The drag area MUST NOT show a grip mark. The drag area MUST show only its shaded fill, the "−" and trash buttons, and the Notely logo. The bottom bar of a note window MUST show only the Bold, Italic, and Underline buttons at its leading edge, and the gear button and the tint button at its trailing edge. Dragging the drag area, or the bottom bar outside its buttons, MUST move the panel. The note area MUST end above the bottom bar, so no note text shows under it. Dragging inside the text MUST select text and MUST NOT move the panel.

#### Scenario: Drag the drag area
- **WHEN** the user drags the panel's drag area
- **THEN** the panel moves with the pointer

#### Scenario: Drag the bottom bar
- **WHEN** the user drags the panel's bottom bar outside its buttons
- **THEN** the panel moves with the pointer

#### Scenario: Bottom bar controls
- **WHEN** a note window is open
- **THEN** its bottom bar shows the Bold, Italic, and Underline buttons at the leading edge, the gear button and the tint button at the trailing edge, and no other controls

#### Scenario: Drag inside text
- **WHEN** the user drags across text in the note area
- **THEN** the text is selected and the panel does not move

#### Scenario: Bars in light appearance
- **WHEN** the system appearance is light
- **THEN** the drag area and the bottom bar show darker than the note area, from the left edge to the right edge of the window

#### Scenario: Bars in dark appearance
- **WHEN** the system appearance is dark
- **THEN** the drag area and the bottom bar show lighter than the note area, from the left edge to the right edge of the window

#### Scenario: No grip mark
- **WHEN** a note window is open
- **THEN** its drag area shows only its shaded fill, the "−" and trash buttons, and the Notely logo

#### Scenario: Long note above the bottom bar
- **WHEN** a note's text is longer than its visible note area
- **THEN** the last visible line of text ends above the bottom bar

### Requirement: Panel position persists
Every panel SHALL open at the position where the user last left it. When a note has no saved position, or its saved position is not on any connected screen, its panel MUST open 20 points from the top and right edges of the main screen's visible area. Every panel MUST always open fully inside one screen's visible area.

#### Scenario: Relaunch keeps position
- **WHEN** the user drags a panel to a new position, quits the app, and launches it again
- **THEN** that panel opens at the same position

#### Scenario: First launch position
- **WHEN** the app launches with no saved note
- **THEN** the one panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved screen disconnected
- **WHEN** a note's saved position is on a screen that is no longer connected, and the app launches
- **THEN** that panel opens 20 points from the top and right edges of the main screen's visible area

#### Scenario: Saved position partly off-screen
- **WHEN** a note's saved position puts part of its panel outside the visible area of the screen it overlaps, and the app launches
- **THEN** that panel opens fully inside that screen's visible area, moved the shortest distance from the saved position

### Requirement: Normal window layering
Every note window SHALL stack with other applications' windows as a normal window: it MUST NOT stay above other applications' windows. A note window MUST show only on the Space where it is open. Clicking a note window MUST bring it to the front and make the app the active application.

#### Scenario: Click another app's window
- **WHEN** a note window overlaps a window of another application and the user clicks that other window
- **THEN** the other window comes in front of the note window

#### Scenario: Click a note window behind another app
- **WHEN** a note window is partly behind a window of another application and the user clicks the visible part of the note window
- **THEN** the note window comes to the front
- **AND** the menu bar shows the app's menus

#### Scenario: Switch Space
- **WHEN** a note window is open on one Space and the user switches to another Space
- **THEN** that note window is not visible on the other Space

### Requirement: Note typeface
Every note area SHALL show its note text in the font and at the size of the text appearance setting: American Typewriter or the macOS system font, at 10 to 20 points, with American Typewriter at 15 points when the user has not changed the setting. The placeholder text of an empty note area MUST use the same typeface and size as note text, and MUST start at the position where the first typed character appears, at every font and size. The placeholder MUST use the same color as note text: white in dark appearance and black in light appearance.

#### Scenario: Typed text uses the chosen font
- **WHEN** the font setting is "System" at 12 points and the user types text in a note area
- **THEN** the text shows in the system font at 12 points

#### Scenario: Typed text uses American Typewriter
- **WHEN** the user has never changed the text appearance setting and types text in a note area
- **THEN** the text shows in American Typewriter at 15 points

#### Scenario: Placeholder uses American Typewriter
- **WHEN** the user has never changed the text appearance setting and a note area is empty
- **THEN** the placeholder text shows in American Typewriter at the same size as note text

#### Scenario: Placeholder uses the note font
- **WHEN** the font setting is "System" at 12 points and a note area is empty
- **THEN** the placeholder text shows in the system font at 12 points

#### Scenario: Placeholder lines up with the caret
- **WHEN** a note area is empty and has keyboard focus, at any font and size
- **THEN** the caret shows at the start of the placeholder text's first line

#### Scenario: Placeholder color
- **WHEN** a note area is empty
- **THEN** the placeholder shows white in dark appearance and black in light appearance

#### Scenario: Saved text after upgrade
- **WHEN** the app launches with notes saved by an earlier version
- **THEN** every note shows its saved text unchanged, in the font and size of the text appearance setting

### Requirement: Scroll bar shows only while scrolling
The scroll bar of every note area SHALL be hidden while the user is not scrolling that note area. When the user scrolls a note area whose text is longer than the visible area, that note area MUST show its scroll bar over the text, and MUST hide the scroll bar again after scrolling stops. This behavior MUST NOT depend on the macOS "Show scroll bars" setting or on the connected pointing device, and MUST stay the same when either changes while the app runs. The note area MUST keep scrolling with the trackpad, the mouse wheel, and caret movement.

#### Scenario: Idle long note
- **WHEN** a note's text is longer than its visible note area and the user is not scrolling
- **THEN** the note area shows no scroll bar
- **AND** the note text uses the full width of the note area

#### Scenario: Scroll a long note
- **WHEN** the user scrolls a note area whose text is longer than the visible area
- **THEN** the scroll bar shows over the text while scrolling
- **AND** the scroll bar hides after scrolling stops

#### Scenario: System setting is "Always"
- **WHEN** the macOS "Show scroll bars" setting is "Always" and the app launches with a long note
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Mouse connected
- **WHEN** a mouse is connected, the "Show scroll bars" setting is "Automatically based on mouse or trackpad", and the app launches with a long note
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Setting changes while the app runs
- **WHEN** the app is running and the user changes the "Show scroll bars" setting, or connects or disconnects a mouse
- **THEN** every open note area still hides its scroll bar until the user scrolls it

#### Scenario: New note
- **WHEN** the user creates a note with "+ New Note" in the menu and types text longer than its visible note area
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Reopened note
- **WHEN** the user closes a long note with "−" and opens it again from the menu
- **THEN** that note area shows no scroll bar until the user scrolls it

#### Scenario: Scroll with the caret
- **WHEN** a note's text is longer than its visible note area and the user moves the caret below the visible area with the arrow keys
- **THEN** the note area scrolls to keep the caret visible

### Requirement: Logo in the drag area
The drag area of every note window and every list window SHALL show the Notely logo: an "N" between two pairs of quote marks, as drawn in `Packaging/notely-logo.svg`. The logo MUST be centered horizontally in the window and vertically in the drag area, and MUST keep the artwork's proportions. The logo MUST be shorter than the drag area, with space above and below it. The logo MUST show in a translucent black in light appearance and a translucent white in dark appearance, so it matches the drag area's shaded fill, and MUST show less strongly than the "−" and trash buttons. The logo MUST change color at once when the system appearance changes. The logo MUST NOT be a control: a click on it MUST end editing, and dragging from it MUST move the window, as on any other part of the drag area. When the window is too narrow for the logo to show at the center without touching the "−" button, the drag area MUST NOT show the logo. The menu window MUST NOT show the logo.

#### Scenario: Logo in a note window
- **WHEN** a note window is open at its default size
- **THEN** its drag area shows the Notely logo at the horizontal center of the window

#### Scenario: Logo in a list window
- **WHEN** a list window is open at its default size
- **THEN** its drag area shows the Notely logo at the horizontal center of the window

#### Scenario: Logo in light appearance
- **WHEN** the system appearance is light
- **THEN** the logo shows in a translucent black, lighter than the "−" and trash buttons

#### Scenario: Logo in dark appearance
- **WHEN** the system appearance is dark
- **THEN** the logo shows in a translucent white, dimmer than the "−" and trash buttons

#### Scenario: Appearance changes
- **WHEN** a note window is open and the user switches the system appearance from light to dark
- **THEN** the logo changes from translucent black to translucent white without reopening the window

#### Scenario: Drag from the logo
- **WHEN** the user drags the window starting on the logo
- **THEN** the window moves with the pointer

#### Scenario: Click the logo while editing
- **WHEN** the note area has keyboard focus and the user clicks the logo
- **THEN** editing ends and the note text is kept

#### Scenario: Narrow window
- **WHEN** the user resizes a note window to its minimum width
- **THEN** the drag area shows no logo
- **AND** the "−" and trash buttons show and work as before

#### Scenario: Menu window
- **WHEN** the menu window is open
- **THEN** it shows no Notely logo
