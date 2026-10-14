# github-integration Specification

## Purpose
Connects Notely to the user's GitHub account and links a list to one GitHub repository, so the list can show and manage that repository's issues.

## Requirements

### Requirement: GitHub section in Integrations
Settings > Integrations SHALL show a "GitHub" section. With no saved token, the section MUST show the account as "Not connected" with a "Setup Account" button. With a saved token, it MUST show the account as "Connected" with a "Disconnect" button.

#### Scenario: Not connected
- **WHEN** no GitHub token is saved and the user opens Settings > Integrations
- **THEN** the GitHub section shows "Not connected" and a "Setup Account" button

#### Scenario: Connected
- **WHEN** a GitHub token is saved and the user opens Settings > Integrations
- **THEN** the GitHub section shows "Connected" and a "Disconnect" button

### Requirement: GitHub account sheet
Clicking "Setup Account" SHALL open a sheet titled "GitHub Account" on the Settings window. The sheet MUST show a "Personal Access Token" field that hides the typed characters, a note recommending a classic token with the "repo" scope, and "Cancel" and "Connect" buttons. "Connect" MUST be disabled while the field is empty or only spaces. "Cancel" and Esc MUST close the sheet without saving anything.

#### Scenario: Connect
- **WHEN** the user pastes a token in the sheet and clicks "Connect"
- **THEN** the sheet closes and the GitHub section shows "Connected"

#### Scenario: Empty field
- **WHEN** the sheet is open and the token field is empty
- **THEN** "Connect" is disabled

#### Scenario: Cancel
- **WHEN** the user types a token in the sheet and presses Esc
- **THEN** the sheet closes and the GitHub section still shows "Not connected"

### Requirement: Token kept in the Keychain
The app SHALL keep the GitHub token only in the macOS Keychain, trimmed of leading and trailing spaces. The token MUST NOT be written to the notes data, to the app's preferences, or to any log. A saved token MUST persist across quit and relaunch.

#### Scenario: Relaunch keeps the account
- **WHEN** the user connects GitHub, quits the app, and launches it again
- **THEN** Settings > Integrations shows "Connected"

#### Scenario: Token not in app data
- **WHEN** the user connects GitHub
- **THEN** the token shows in Keychain Access as an item of the app
- **AND** the app's saved notes and preferences do not contain the token

### Requirement: Disconnect GitHub
Clicking "Disconnect" SHALL remove the token from the Keychain and show the account as "Not connected". Every list window MUST hide its GitHub and refresh buttons at once. Every list's linked repository MUST be kept, and MUST show again once the user connects GitHub again.

#### Scenario: Disconnect
- **WHEN** a linked list window is open and the user clicks "Disconnect"
- **THEN** the list window's bottom bar shows no GitHub button and no refresh button
- **AND** Settings > Integrations shows "Not connected"

#### Scenario: Reconnect keeps the link
- **WHEN** the user disconnects, then connects GitHub again
- **THEN** a list that was linked to "acme/website" before shows the GitHub button with "acme/website" linked

### Requirement: GitHub button on list windows
While a GitHub token is saved, every list window SHALL show a GitHub button at the leading edge of its bottom bar. While no token is saved, no list window MUST show it. Note windows and the menu window MUST NOT show it. The button MUST use the same borderless icon style and size as the other bottom bar buttons, MUST work on the first click, and MUST NOT move the window.

#### Scenario: Button with an account
- **WHEN** a GitHub token is saved and a list window is open
- **THEN** its bottom bar shows the GitHub button at the leading edge

#### Scenario: No button without an account
- **WHEN** no GitHub token is saved and a list window is open
- **THEN** its bottom bar shows no GitHub button

#### Scenario: No button on notes
- **WHEN** a GitHub token is saved and a note window is open
- **THEN** its bottom bar shows no GitHub button

### Requirement: GitHub menu
Clicking the GitHub button SHALL open a menu at the button. For an unlinked list, the menu MUST show one entry: "Link to Repository…". For a linked list, the menu MUST show the repository as `owner/repo` with a check mark, then "Open on GitHub", then "Unlink". "Open on GitHub" MUST open the repository's issues page in the default browser. Esc or a click outside MUST close the menu without a change.

#### Scenario: Menu on an unlinked list
- **WHEN** the user clicks the GitHub button of an unlinked list
- **THEN** the menu shows only "Link to Repository…"

#### Scenario: Menu on a linked list
- **WHEN** the user clicks the GitHub button of a list linked to "acme/website"
- **THEN** the menu shows "acme/website" with a check mark, "Open on GitHub", and "Unlink"

#### Scenario: Open on GitHub
- **WHEN** the user chooses "Open on GitHub" for a list linked to "acme/website"
- **THEN** the default browser opens https://github.com/acme/website/issues

### Requirement: Repository picker
"Link to Repository…" SHALL open a popover at the GitHub button with a search field, a results area, and "Cancel" and "Link" buttons. The user MUST be able to type a repository as `owner/repo`. "Link" MUST be enabled only when the field holds one owner and one repository name separated by one "/", each made of letters, digits, "-", "_", or ".". "Cancel" and Esc MUST close the popover without linking.

#### Scenario: Type a repository
- **WHEN** the user types "acme/website" in the picker
- **THEN** "Link" is enabled

#### Scenario: Not a repository
- **WHEN** the user types "acme" or "acme/web site" in the picker
- **THEN** "Link" is disabled

#### Scenario: Cancel the picker
- **WHEN** the picker is open with "acme/website" typed and the user presses Esc
- **THEN** the popover closes and the list stays unlinked

### Requirement: Link a list
Clicking "Link" SHALL link the list to the typed repository and close the picker. When the list has no unchecked items, it MUST link at once and drop any checked items. When it has unchecked items, a sheet MUST first ask "Link "<title>" to <owner/repo>?", give the number of unchecked items, and offer "Cancel", "Discard", and "Create as issues". "Cancel" MUST leave the list unchanged and unlinked. "Discard" MUST remove every item and link. "Create as issues" MUST keep the unchecked items, remove the checked items, and link. The list's title MUST stay unchanged in every case.

#### Scenario: Link an empty list
- **WHEN** a list has no items and the user links it to "acme/website"
- **THEN** no sheet shows and the list is linked to "acme/website"

#### Scenario: Link a list with items
- **WHEN** the list "Bugs" has two unchecked items and one checked item, and the user links it to "acme/website"
- **THEN** a sheet asks to link "Bugs" to acme/website, says it has 2 items, and offers "Cancel", "Discard", and "Create as issues"

#### Scenario: Create as issues
- **WHEN** the sheet shows and the user clicks "Create as issues"
- **THEN** the list is linked, keeps its two unchecked items, and no longer shows the checked item

#### Scenario: Discard
- **WHEN** the sheet shows and the user clicks "Discard"
- **THEN** the list is linked, keeps its title, and shows no items

#### Scenario: Cancel linking
- **WHEN** the sheet shows and the user clicks "Cancel"
- **THEN** the list is not linked and its items are unchanged

### Requirement: Unlink a list
Choosing "Unlink" SHALL remove the list's link at once and hide its refresh button. The list MUST keep its title and items as local items.

#### Scenario: Unlink
- **WHEN** a list linked to "acme/website" shows two items and the user chooses "Unlink"
- **THEN** the GitHub menu shows "Link to Repository…" again
- **AND** the list keeps its title and both items, and shows no refresh button

### Requirement: Link persists
A list's linked repository SHALL be saved with the list and restored on the next launch. Lists saved by earlier versions MUST open unlinked and unchanged.

#### Scenario: Relaunch keeps the link
- **WHEN** a list is linked to "acme/website" and the user quits and launches the app again
- **THEN** that list's GitHub menu shows "acme/website" with a check mark

#### Scenario: Older lists stay unlinked
- **WHEN** the app launches with lists saved by a version without GitHub links
- **THEN** every list opens unlinked with its title and items unchanged

### Requirement: Refresh button on linked lists
While a GitHub token is saved, every linked list window SHALL show a refresh button directly after the GitHub button. Unlinked list windows, note windows, and the menu window MUST NOT show it. The button MUST use the same borderless icon style and size as the other bottom bar buttons, MUST work on the first click, and MUST NOT move the window.

#### Scenario: Refresh button on a linked list
- **WHEN** a GitHub token is saved and a list is linked
- **THEN** its bottom bar shows the GitHub button and then the refresh button at the leading edge

#### Scenario: No refresh button on an unlinked list
- **WHEN** a GitHub token is saved and a list is not linked
- **THEN** its bottom bar shows the GitHub button and no refresh button

### Requirement: Linked lists summary
Settings > Integrations SHALL show a "Linked lists" area under the GitHub account row, with one row per linked list: the list's title, or "Untitled list" when it is empty, and its repository as `owner/repo`. The rows MUST NOT be editable. With no linked list, the area MUST show "No linked lists". The area MUST update while the Settings window is open.

#### Scenario: Summary shows links
- **WHEN** the list "Bugs" is linked to "acme/website" and the user opens Settings > Integrations
- **THEN** "Linked lists" shows a row "Bugs" with "acme/website"

#### Scenario: Summary follows a new link
- **WHEN** Settings > Integrations is open and the user links a list to "jorge/notely"
- **THEN** a row for that list with "jorge/notely" shows without reopening Settings
