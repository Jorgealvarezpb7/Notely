# Spec Delta

## Purpose

Lets the user read and write a linked list item's issue description in Markdown from the list window, kept in step with GitHub without losing anyone's edit.

## ADDED Requirements

### Requirement: Description icon on linked items
On a linked list, every item SHALL show a description icon at its trailing edge. The icon MUST show at all times when the item has a description, and MUST show only while the pointer is over the row when it has none. Unlinked lists and the "New item" row MUST NOT show it. Clicking the icon MUST open the item's description popover, and MUST NOT give the item's text keyboard focus.

#### Scenario: Item with a description
- **WHEN** a linked list shows issue #4, whose description is "Steps to reproduce"
- **THEN** the item shows the description icon without the pointer over it

#### Scenario: Item without a description
- **WHEN** a linked list shows issue #5 with an empty description
- **THEN** the item shows no description icon until the pointer is over its row

#### Scenario: Unlinked list
- **WHEN** a list is not linked to a repository
- **THEN** none of its items shows a description icon, even under the pointer

### Requirement: Open the description with Cmd+D
In a linked list, Cmd+D SHALL open the description popover of the item that has keyboard focus or, when no item has focus, of the item under the pointer. While a description popover is open, Cmd+D MUST close it. With none of these, on an unlinked list, or in a note window, Cmd+D MUST do nothing.

#### Scenario: Shortcut on a focused item
- **WHEN** the user is editing the text of the item of issue #4 and presses Cmd+D
- **THEN** the description popover of issue #4 opens

#### Scenario: Shortcut on the item under the pointer
- **WHEN** no item is being edited, the pointer is over the item of issue #4, and the user presses Cmd+D
- **THEN** the description popover of issue #4 opens

#### Scenario: Shortcut closes the popover
- **WHEN** a description popover is open and the user presses Cmd+D
- **THEN** the popover closes

### Requirement: Description rendered as Markdown
The description popover SHALL show the description rendered as Markdown. It MUST render headings, bullet lists, numbered lists, task lists, fenced code blocks, bold, italic, inline code, and links. Task list boxes MUST show checked or unchecked and MUST NOT react to clicks. Tables, images, and other Markdown MUST show as their raw text. Links MUST open in the default browser. An empty description MUST show "No description".

#### Scenario: Lists and headings
- **WHEN** the description is "## Steps\n- open Safari\n- sign in"
- **THEN** the popover shows the heading "Steps" and a bullet list of two entries

#### Scenario: Task list
- **WHEN** the description contains "- [x] repro" and "- [ ] fix"
- **THEN** the popover shows one checked box and one unchecked box, and clicking them changes nothing

#### Scenario: Table stays raw
- **WHEN** the description contains a Markdown table
- **THEN** the popover shows the table's lines as written

### Requirement: Edit a description
The popover SHALL show "Edit" when the user may change the item, under the same rights as its title. "Edit" MUST show the description as raw Markdown text in an editable field, with "Done" in place of "Edit". The field MUST keep the text's line breaks and MUST NOT style it. "Done", or closing the popover, MUST end editing and show the rendered description. An issue the user may not change MUST open without "Edit". Emptying a description MUST be allowed.

#### Scenario: Edit and finish
- **WHEN** the user clicks "Edit", types "**Safari** only", and clicks "Done"
- **THEN** the popover shows "Safari only" with "Safari" in bold

#### Scenario: Read-only issue
- **WHEN** the user has read access and opens the description of an issue someone else opened
- **THEN** the popover shows the rendered description and no "Edit"

### Requirement: Description stored when editing ends
While the user edits a description, typing SHALL NOT change the item's stored description. The text MUST be stored when editing ends, by "Done" or by closing the popover.

#### Scenario: Typing is not stored until editing ends
- **WHEN** the user clicks "Edit" on issue #4 and types "Only on Safari"
- **THEN** the item's stored description is unchanged
- **AND WHEN** the user clicks "Done"
- **THEN** the item's description is "Only on Safari"

### Requirement: Descriptions sent to GitHub
A description change SHALL be sent to GitHub when editing ends, and each change MUST show in the popover at once, before GitHub answers. It MUST wait, be kept across quit, and be sent again at each refresh until GitHub accepts it, as title changes do. An item with no issue yet MUST send its description with the issue it creates. While the user edits a description, refreshes MUST NOT replace its text.

#### Scenario: Change sent
- **WHEN** the user edits the description of issue #4 to "Only on Safari" and clicks "Done"
- **THEN** issue #4's description on GitHub is "Only on Safari"

#### Scenario: Description with a new item
- **WHEN** the user types "fix login" in "New item", adds the description "Only on Safari", and clicks elsewhere
- **THEN** the issue created on GitHub has the title "fix login" and the description "Only on Safari"

### Requirement: Descriptions changed on GitHub
On refresh, an item SHALL take its issue's description from GitHub, unless the user is editing that description, or the item has a description change waiting or held. Line breaks MUST be compared the same whether written as CRLF or LF.

#### Scenario: Edited on GitHub
- **WHEN** someone changes the description of issue #4 on GitHub and the list refreshes
- **THEN** the description popover of issue #4 shows the new description

#### Scenario: Line breaks only
- **WHEN** GitHub returns the same description with CRLF line breaks
- **THEN** no description change is sent and no conflict shows

### Requirement: Description conflicts held
Before a description change is sent, the app SHALL read the issue's description on GitHub. When it differs from the description last seen on GitHub, the change MUST be held, not sent, and the item MUST keep the user's text. While held, the popover MUST say "Description changed on GitHub", offer "Keep mine" and "Use GitHub's", and show GitHub's description.

#### Scenario: Conflict found
- **WHEN** the user edits the description of issue #4 while someone else edits it on GitHub
- **THEN** the user's edit is not sent
- **AND** the popover of issue #4 shows "Description changed on GitHub", "Keep mine", and "Use GitHub's"

### Requirement: Resolve a description conflict
"Keep mine" SHALL send the user's description to GitHub, replacing GitHub's. "Use GitHub's" MUST replace the user's description with GitHub's and send nothing. Either choice MUST end the conflict. When a refresh finds GitHub's description equal to the user's, the conflict MUST end by itself. A held change MUST be kept across quit.

#### Scenario: Keep mine
- **WHEN** a conflict shows for issue #4 and the user clicks "Keep mine"
- **THEN** issue #4's description on GitHub becomes the user's description

#### Scenario: Use GitHub's
- **WHEN** a conflict shows for issue #4 and the user clicks "Use GitHub's"
- **THEN** the popover shows GitHub's description and nothing is sent

### Requirement: Descriptions not logged
The GitHub activity log SHALL NOT contain issue descriptions, neither the user's nor GitHub's.

#### Scenario: Log without descriptions
- **WHEN** the user edits a description while streaming the log
- **THEN** no log entry contains the description's text
