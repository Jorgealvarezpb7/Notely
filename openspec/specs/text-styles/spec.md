# text-styles Specification

## Purpose

Lets the user mark parts of a note's text as bold, italic, or underlined from the note window's bottom bar or the keyboard, and keeps those styles between app launches.

## Requirements

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

### Requirement: Toggle a style on selected text
With text selected in a note area, clicking a style button or pressing its shortcut SHALL toggle that style on the selection. When the whole selection already has the style, the style MUST be removed from the whole selection. Otherwise the style MUST be applied to the whole selection. Toggling one style MUST NOT change the other two styles, the text, the font, or the size.

#### Scenario: Make a word bold
- **WHEN** the user selects the word "milk" and clicks the Bold button
- **THEN** "milk" shows bold and the rest of the note is unchanged

#### Scenario: Remove bold
- **WHEN** the user selects a word that is bold and clicks the Bold button
- **THEN** the word no longer shows bold

#### Scenario: Mixed selection
- **WHEN** the user selects "buy milk" where only "milk" is bold, and clicks the Bold button
- **THEN** all of "buy milk" shows bold

#### Scenario: Combine styles
- **WHEN** the user selects a bold word and clicks the Italic button and then the Underline button
- **THEN** the word shows bold, italic, and underlined

### Requirement: Toggle a style for new typing
With no text selected in a note area that has keyboard focus, clicking a style button or pressing its shortcut SHALL toggle that style for the text typed next at the caret. Moving the caret by clicking or with the arrow keys MUST reset the styles for new typing to those of the text before the caret.

#### Scenario: Type bold text
- **WHEN** the caret is in plain text, the user presses Cmd+B, and types "urgent"
- **THEN** "urgent" shows bold

#### Scenario: Turn bold off while typing
- **WHEN** the user types bold text, presses Cmd+B, and types more text
- **THEN** the text typed after the second Cmd+B is not bold

#### Scenario: Caret moves
- **WHEN** the user presses Cmd+B with nothing typed, and then clicks in plain text elsewhere and types
- **THEN** the typed text is not bold

### Requirement: Style button state
While a note area has keyboard focus, each style button SHALL show as active when its style applies to the whole selection or, with no selection, to text typed next at the caret. Otherwise the button MUST show as inactive. The state MUST follow every change of selection, caret position, and style. While the note area does not have keyboard focus, all three buttons MUST show as inactive.

#### Scenario: Caret in bold text
- **WHEN** the user clicks inside a bold word
- **THEN** the Bold button shows as active and the Italic and Underline buttons show as inactive

#### Scenario: Mixed selection state
- **WHEN** the user selects text of which only part is underlined
- **THEN** the Underline button shows as inactive

#### Scenario: Editing ended
- **WHEN** the caret is in bold text and the user presses Esc
- **THEN** all three style buttons show as inactive

### Requirement: Style shortcuts and Format menu
Cmd+B, Cmd+I, and Cmd+U SHALL toggle bold, italic, and underline in the note area that has keyboard focus, the same as the buttons. The menu bar MUST show a "Format" menu with the entries "Bold" (Cmd+B), "Italic" (Cmd+I), and "Underline" (Cmd+U). The entries MUST be enabled only while a note area has keyboard focus, and each MUST show a check mark when its button would show as active. The shortcuts MUST do nothing in list windows and the menu window.

#### Scenario: Shortcut on a selection
- **WHEN** the user selects a word in a note and presses Cmd+I
- **THEN** the word shows italic

#### Scenario: Shortcut in a list
- **WHEN** a list item has keyboard focus and the user presses Cmd+B
- **THEN** the item's text does not change

#### Scenario: Format menu disabled
- **WHEN** no note area has keyboard focus
- **THEN** the "Format" menu's entries are disabled

### Requirement: Italic in a font without an italic face
Italic text SHALL show slanted in both font choices. When the chosen font has an italic face, italic text MUST use that face. When it has none, as American Typewriter, italic text MUST show as the font's upright face with a slant. Bold italic text MUST show both bold and slanted.

#### Scenario: Italic in American Typewriter
- **WHEN** the font setting is American Typewriter and the user makes a word italic
- **THEN** the word shows slanted in American Typewriter

#### Scenario: Italic in the system font
- **WHEN** the font setting is "System" and a note has an italic word
- **THEN** the word shows in the system font's italic face

### Requirement: Styles follow font and size changes
Changing the font or the text size SHALL keep every style range of every note. Styled text MUST show in the new font and at the new size, with its styles.

#### Scenario: Switch font with styles
- **WHEN** a note has a bold word and an italic word, and the user chooses "System" in the font menu
- **THEN** the bold word shows in the bold system font and the italic word in the italic system font

#### Scenario: Change size with styles
- **WHEN** a note has an underlined word and the user sets the size to 18 points
- **THEN** the word shows at 18 points and stays underlined

### Requirement: Paste keeps only styles
Pasting rich text into a note area SHALL keep bold, italic, and underline from the pasted text, and MUST drop every other attribute, such as font, size, color, background, and links. The pasted text MUST show in the font and at the size of the text appearance setting. Pasting plain text MUST insert it with the styles for new typing at the caret.

#### Scenario: Paste from a web page
- **WHEN** the user copies a red, 24-point, bold link from a web page and pastes it into a note
- **THEN** the pasted text shows bold, in the note's font, size, and text color, with no link

#### Scenario: Copy between notes
- **WHEN** the user copies an italic word from one note and pastes it into another note
- **THEN** the pasted word shows italic

### Requirement: Styles persist
The styles of every note SHALL persist across app quit and relaunch without an explicit save action, with the same timing as note text. Undo and redo MUST cover style changes. Notes saved by earlier versions MUST open with their text unchanged and no styles. A build without this capability MUST still open every note and show its text, without styles.

#### Scenario: Relaunch keeps styles
- **WHEN** the user makes a word bold, quits the app, and launches it again
- **THEN** that word shows bold

#### Scenario: Undo a style
- **WHEN** the user makes a word bold and presses Cmd+Z
- **THEN** the word no longer shows bold

#### Scenario: Note from an earlier version
- **WHEN** the app launches with notes saved by a version without styles
- **THEN** every note shows its saved text unchanged, with no styles

#### Scenario: Edit text around styles
- **WHEN** a note has a bold word and the user types text before it and quits and relaunches
- **THEN** the same word shows bold, and the typed text is not bold
