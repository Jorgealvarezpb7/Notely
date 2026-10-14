# Spec Delta

## MODIFIED Requirements

### Requirement: Style buttons in the note bottom bar
The bottom bar of every note window SHALL show three icon buttons at its leading edge, in this order: Bold, Italic, Underline. The buttons MUST use the same borderless icon style and size as the gear and tint buttons. Each button MUST work on the first click, also while another application is active. Clicking a button MUST NOT move the window, MUST NOT end editing, and MUST keep the selection. List windows and the menu window MUST NOT show these buttons.

#### Scenario: Buttons in a note window
- **WHEN** a note window is open
- **THEN** its bottom bar shows the Bold, Italic, and Underline buttons at the leading edge
- **AND** the gear and tint buttons at the trailing edge

#### Scenario: No buttons in a list window
- **WHEN** a list window is open
- **THEN** its bottom bar shows no Bold, Italic, or Underline button

#### Scenario: Click keeps editing
- **WHEN** the user selects a word in a note and clicks the Bold button
- **THEN** the note area keeps keyboard focus and the word stays selected
