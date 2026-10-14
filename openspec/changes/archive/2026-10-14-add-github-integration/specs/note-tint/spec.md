# Spec Delta

## MODIFIED Requirements

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
