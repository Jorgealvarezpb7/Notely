# sync-status Specification

## Purpose
Shows beside a linked list's refresh button whether its last exchange with GitHub worked, so the user knows whether their changes are stored on GitHub.

## Requirements

### Requirement: Sync result beside the refresh button
After each sync of a linked list, a full refresh or a push of the user's changes, its bottom bar SHALL show a result icon directly after the refresh button: a check mark when the sync worked, or an x when it failed. The icon MUST use the bottom bar's icon size, MUST NOT move the window, and MUST NOT show while the list syncs. Unlinked lists MUST NOT show it.

#### Scenario: Refresh worked
- **WHEN** the user clicks the refresh button of a linked list and GitHub answers every request
- **THEN** a check mark shows after the refresh button once it stops spinning

#### Scenario: Change sent
- **WHEN** the user checks the item of issue #4 and GitHub closes the issue
- **THEN** a check mark shows after the refresh button

### Requirement: When a sync counts as worked
A sync SHALL show the check mark only when every request it made succeeded and the list has no change waiting or held afterwards. Otherwise it MUST show the x. That includes a sync where GitHub accepted some changes and refused others, one where GitHub can't be reached, one stopped by the request limit, one that finds a description conflict, and one stopped because GitHub no longer accepts the token.

#### Scenario: Partial success
- **WHEN** the user renames two items, and GitHub accepts one rename and refuses the other
- **THEN** an x shows after the refresh button

#### Scenario: Offline
- **WHEN** the Mac is offline and the user checks the item of issue #4
- **THEN** an x shows after the refresh button

#### Scenario: Token rejected
- **WHEN** the user revoked the token on GitHub and a refresh runs
- **THEN** an x shows after the refresh button of every linked list

### Requirement: Reason for an x
Pointing at the x SHALL show a tooltip with the reason, the same text the GitHub menu shows: for example "GitHub can't be reached", "1 change not sent yet", or "Description changed on GitHub".

#### Scenario: Offline tooltip
- **WHEN** an x shows because GitHub can't be reached and the user points at it
- **THEN** the tooltip says "GitHub can't be reached"

### Requirement: Result fades
A check mark SHALL fade out one minute after it shows. An x MUST stay while the list has changes waiting or held, and MUST fade out one minute after it shows when none are left. A new sync result MUST replace the shown icon. Once faded, the bottom bar MUST show the refresh button alone, as before any sync.

#### Scenario: Check fades
- **WHEN** a check mark shows and the user waits one minute
- **THEN** the bottom bar shows the refresh button with no icon after it

#### Scenario: X stays while changes wait
- **WHEN** the user checks an item offline and waits two minutes
- **THEN** the x still shows after the refresh button

#### Scenario: X clears after sending
- **WHEN** an x shows for a waiting change, the Mac comes online, and the next refresh sends it
- **THEN** a check mark replaces the x, and fades one minute later

#### Scenario: Refused change fades
- **WHEN** GitHub refuses a change for good, so that nothing is left waiting
- **THEN** the x shows, and fades one minute later

### Requirement: Result not kept across launches
The sync result SHALL be kept in memory only. After a launch, no icon MUST show until the list's first sync ends.

#### Scenario: After relaunch
- **WHEN** the user quits with an x showing and launches the app online with nothing waiting
- **THEN** no icon shows until the launch refresh ends, and then a check mark shows
