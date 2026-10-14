# Spec Delta

## MODIFIED Requirements

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
