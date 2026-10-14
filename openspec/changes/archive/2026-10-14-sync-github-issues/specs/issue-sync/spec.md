# Spec Delta

## Purpose

Keeps a list linked to a GitHub repository in step with that repository's issues, in both directions, and logs every exchange with GitHub so failures can be traced.

## ADDED Requirements

### Requirement: Check the token on Connect
Clicking "Connect" in the GitHub Account sheet SHALL ask GitHub which account the token belongs to before saving it. While GitHub answers, "Connect" MUST show progress and be disabled. When GitHub accepts the token, it MUST be saved and the sheet closed. When GitHub rejects it, the token MUST NOT be saved and the sheet MUST stay open with "GitHub didn't accept this token." When GitHub can't be reached, the sheet MUST say so and save nothing.

#### Scenario: Valid token
- **WHEN** the user pastes a valid token and clicks "Connect"
- **THEN** the sheet closes and Settings > Integrations shows "Connected as @<login>"

#### Scenario: Rejected token
- **WHEN** the user pastes a revoked token and clicks "Connect"
- **THEN** the sheet stays open and shows "GitHub didn't accept this token."
- **AND** nothing is saved in the Keychain

#### Scenario: Offline
- **WHEN** the Mac is offline and the user clicks "Connect"
- **THEN** the sheet stays open and shows "GitHub can't be reached. Check the connection and try again."

### Requirement: Account login shown
While connected, Settings > Integrations SHALL show the account as "Connected as @<login>", with the login GitHub returned for the token. Until the login is known after a launch, it MUST show "Connected".

#### Scenario: Login after relaunch
- **WHEN** the user connected as "jorge", relaunches the app, and opens Settings > Integrations once GitHub answers
- **THEN** the account shows "Connected as @jorge"

### Requirement: Search repositories in the picker
When the repository picker opens, it SHALL list the repositories the token can reach: owned, collaborator, and organization member repositories, as `owner/repo`, sorted by most recently pushed. Typing in the field MUST filter the list to names containing the typed text, ignoring case. Clicking a row MUST put its name in the field. While the list loads, the results area MUST show progress. When it fails, it MUST say so, and typing `owner/repo` MUST still work.

#### Scenario: Pick from the list
- **WHEN** the picker opens and the user types "note" and clicks "jorge/notely"
- **THEN** the field shows "jorge/notely" and "Link" is enabled

#### Scenario: List fails
- **WHEN** GitHub can't be reached while the picker opens
- **THEN** the results area says the repositories couldn't be loaded
- **AND** typing "acme/website" still enables "Link"

### Requirement: Check the repository on Link
Clicking "Link" SHALL ask GitHub for the repository before linking. When GitHub can't find it, or the token can't reach it, the picker MUST stay open with "Repository not found, or this token can't reach it." When the repository has issues turned off, the picker MUST stay open with "Issues are turned off for <owner/repo>." Otherwise linking MUST go on as before.

#### Scenario: Unknown repository
- **WHEN** the user types "acme/nothing-here" and clicks "Link"
- **THEN** the picker stays open with "Repository not found, or this token can't reach it."

#### Scenario: Issues turned off
- **WHEN** the user links a repository whose issues are turned off
- **THEN** the picker stays open with "Issues are turned off for acme/website." and the list stays unlinked

### Requirement: Which issues show
A linked list SHALL show, as unchecked items, the repository's open issues that are assigned to the account's user or assigned to no one. An issue assigned to the user and to others MUST show. An issue assigned only to others MUST NOT show. Pull requests MUST NOT show. Each item's text MUST be its issue's title.

#### Scenario: Assigned and unassigned issues
- **WHEN** a repository has open issue #1 assigned to the user, #2 unassigned, #3 assigned to someone else, and an open pull request
- **THEN** the linked list shows #1 and #2 and nothing else

#### Scenario: Shared assignment
- **WHEN** an open issue is assigned to the user and to someone else
- **THEN** the linked list shows it

### Requirement: When a linked list refreshes
Every linked list SHALL refresh from GitHub at launch, right after it is linked, every 10 minutes while the app runs, and when the user clicks its refresh button. While a list refreshes, its refresh button MUST spin and MUST NOT start a second refresh. While no account is connected, no list MUST refresh.

#### Scenario: Refresh on demand
- **WHEN** someone opens an unassigned issue on GitHub and the user clicks the list's refresh button
- **THEN** the button spins, and the new issue shows as an unchecked item when it stops

#### Scenario: Refresh by timer
- **WHEN** someone opens an unassigned issue on GitHub and the app keeps running for 10 minutes
- **THEN** the issue shows in the linked list without the user doing anything

### Requirement: Issues changed on GitHub
On refresh, an item whose issue is no longer among the shown open issues SHALL follow its issue. A closed issue MUST move to the top of the checked items, unless the item is checked already. A deleted or transferred issue, or one now assigned only to others, MUST be removed. An issue reopened on GitHub MUST show unchecked again. A title changed on GitHub MUST show as the item's text, unless the item has keyboard focus.

#### Scenario: Closed elsewhere
- **WHEN** someone closes issue #2 on GitHub and the list refreshes
- **THEN** #2 shows checked, at the top of the checked items

#### Scenario: Deleted elsewhere
- **WHEN** an admin deletes issue #2 and the list refreshes
- **THEN** #2 is no longer in the list

#### Scenario: Reassigned elsewhere
- **WHEN** issue #2 is assigned to someone else only and the list refreshes
- **THEN** #2 is no longer in the list

### Requirement: Checked items kept
A linked list SHALL keep at most the 10 most recently checked items. When an item is checked beyond that, the oldest checked item MUST be removed from the list. Its issue MUST stay as it is on GitHub.

#### Scenario: Eleventh checked item
- **WHEN** a linked list has 10 checked items and the user checks another
- **THEN** the list shows 10 checked items, without the one checked longest ago

### Requirement: Create issues from items
On a linked list, an item with no issue SHALL be created as an issue in the repository, titled with the item's text, when the item loses keyboard focus with text, and at each refresh for items kept by "Create as issues". The issue MUST be assigned to the user when they have push access, and to no one otherwise.

#### Scenario: New item
- **WHEN** the user types "fix login" in the "New item" row of a linked list and clicks elsewhere
- **THEN** an issue titled "fix login" is created in the repository
- **AND** with push access, it is assigned to the user

#### Scenario: Items kept on link
- **WHEN** the user links a list with two unchecked items and clicks "Create as issues"
- **THEN** two issues titled with the items' text are created, and the items stay in the list

### Requirement: Close, reopen, and rename issues
On a linked list, checking an item SHALL close its issue, and unchecking it MUST reopen it. When an item loses keyboard focus with text other than its issue's title, the issue MUST be renamed to that text. Each change MUST show in the list at once, before GitHub answers.

#### Scenario: Close from the list
- **WHEN** the user checks the item of issue #4
- **THEN** the item moves to the checked items at once, and issue #4 is closed on GitHub

#### Scenario: Rename from the list
- **WHEN** the user changes the item of issue #4 from "fix login" to "fix login on Safari" and clicks elsewhere
- **THEN** issue #4 is titled "fix login on Safari" on GitHub

### Requirement: Items can't be emptied
On a linked list, an item that loses keyboard focus while empty SHALL get its issue's title back, and nothing MUST be sent to GitHub. An item that has no issue yet and is empty MUST be removed, as on local lists. Backspace in an empty item that has an issue MUST NOT remove the item.

#### Scenario: Clear an item
- **WHEN** the user clears the text of the item of issue #4 and clicks elsewhere
- **THEN** the item shows its issue's title again, and issue #4 is unchanged

#### Scenario: Backspace in a cleared item
- **WHEN** the user clears the text of the item of issue #4 and presses Backspace
- **THEN** the item stays, with keyboard focus

### Requirement: Rights on an issue
The app SHALL read the user's permission on a linked repository when linking and at each refresh. An issue the user can close, reopen, and rename is one in a repository where they have triage access or more, or one they opened. On any other issue the item's circle MUST show dimmed, MUST NOT react to clicks or Cmd+Return, and MUST show the tooltip "You can't close this issue". The item's text MUST be read-only.

#### Scenario: Read-only repository
- **WHEN** the user has read access to a repository and an unassigned issue opened by someone else shows
- **THEN** that item's circle shows dimmed, with the tooltip "You can't close this issue"
- **AND** clicking the circle or editing the text changes nothing

#### Scenario: Own issue in a read-only repository
- **WHEN** the user has read access and an issue they opened shows
- **THEN** they can check, uncheck, and rename that item

### Requirement: Changes wait until sent
A change made on a linked list SHALL be kept until GitHub accepts it, also across quit and relaunch, and MUST be sent again at each refresh. While a list has changes waiting, its GitHub button MUST show a badge, and its GitHub menu MUST show "<n> changes not sent yet". When GitHub refuses a change for good (forbidden, not found, or gone), the change MUST be dropped, the item MUST take its issue's state on GitHub, and the menu MUST show why until the next refresh.

#### Scenario: Check while offline
- **WHEN** the Mac is offline and the user checks the item of issue #4
- **THEN** the item shows checked at once and the GitHub button shows a badge
- **AND** once online, the next refresh closes issue #4 and the badge goes away

#### Scenario: Quit with waiting changes
- **WHEN** the user checks an item offline, quits, and launches the app online
- **THEN** the issue is closed on GitHub after the launch refresh

#### Scenario: Refused for good
- **WHEN** the user renames an item whose issue was deleted meanwhile
- **THEN** the change is dropped and the item is removed at the refresh

### Requirement: Token no longer accepted
When GitHub rejects the saved token, sync SHALL pause for every list until the user connects again. Every linked list's GitHub button MUST show a badge, and its menu MUST show "GitHub token no longer works" and "Reconnect…". "Reconnect…" MUST open Settings on the Integrations pane. Changes waiting MUST be kept.

#### Scenario: Revoked token
- **WHEN** the user revokes the token on GitHub and a refresh runs
- **THEN** every linked list's GitHub menu shows "GitHub token no longer works" and "Reconnect…"
- **AND** choosing "Reconnect…" opens Settings on Integrations

### Requirement: GitHub activity log
The app SHALL write each GitHub request to the macOS unified log, under subsystem "com.alvarezjorge.Notely" and category "github". Each entry MUST show the method, the path, the status code, the time taken, and the remaining rate limit. Each sync decision MUST be logged too: issues added, moved, removed, changes sent, retried, or dropped. Failures MUST log at error level with GitHub's message.

#### Scenario: Read the log
- **WHEN** the user runs `log stream --predicate 'subsystem == "com.alvarezjorge.Notely"' --level info` and clicks a list's refresh button
- **THEN** the stream shows each GitHub request of that refresh with its status code

#### Scenario: Failed request logged
- **WHEN** closing an issue fails with status 403
- **THEN** the log shows an error entry with the path, 403, and GitHub's message

### Requirement: No secrets in the log
The log SHALL NOT contain the token, the `Authorization` header, or full request or response bodies. Issue titles and repository names MUST be logged as private values, which macOS hides unless private data logging is turned on.

#### Scenario: Token absent
- **WHEN** the user connects and refreshes a list while streaming the log
- **THEN** no log entry contains the token
