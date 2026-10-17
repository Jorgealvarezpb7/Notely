# Spec Delta

## ADDED Requirements

### Requirement: GitHub menu in the menu bar
The menu bar SHALL have a GitHub menu with "Description" (Cmd+D), "Refresh Issues" (Cmd+R), and "Link to Repository…" (Cmd+L), acting on the front list window. "Refresh Issues" MUST be enabled only for a linked list that is not syncing. With a note window in front, every entry MUST be disabled.

#### Scenario: Refresh with the keyboard
- **WHEN** a linked list window is in front and the user presses Cmd+R
- **THEN** the list refreshes and its refresh button spins

#### Scenario: Note window in front
- **WHEN** a note window is in front
- **THEN** "Description", "Refresh Issues", and "Link to Repository…" are disabled

### Requirement: Link shortcut
"Link to Repository…" MUST be enabled for any list while a GitHub token is saved. On an unlinked list it MUST open the repository picker at the list's GitHub button. On a linked list it MUST open the GitHub button's menu, with "Open on GitHub" and "Unlink". While the picker or that menu is open, Cmd+L MUST close it.

#### Scenario: Link with the keyboard
- **WHEN** an unlinked list window is in front, a token is saved, and the user presses Cmd+L
- **THEN** the repository picker opens at the list's GitHub button

#### Scenario: Shortcut on a linked list
- **WHEN** a linked list window is in front and the user presses Cmd+L
- **THEN** the GitHub button's menu opens, with "Open on GitHub" and "Unlink"

#### Scenario: Shortcut closes what it opened
- **WHEN** the picker or the GitHub button's menu is open and the user presses Cmd+L
- **THEN** it closes
