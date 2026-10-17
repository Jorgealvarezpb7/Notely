# Spec Delta

## MODIFIED Requirements

### Requirement: Changes wait until sent
A change made on a linked list SHALL be kept until GitHub accepts it, also across quit and relaunch, and MUST be sent again at each refresh. While a list has changes waiting, its sync result MUST show the x (see `sync-status`), and its GitHub menu MUST show "<n> changes not sent yet". When GitHub refuses a change for good (forbidden, not found, or gone), the change MUST be dropped, the item MUST take its issue's state on GitHub, and the menu MUST show why until the next refresh.

#### Scenario: Check while offline
- **WHEN** the Mac is offline and the user checks the item of issue #4
- **THEN** the item shows checked at once and the x shows after the refresh button
- **AND** once online, the next refresh closes issue #4 and a check mark replaces the x

#### Scenario: Quit with waiting changes
- **WHEN** the user checks an item offline, quits, and launches the app online
- **THEN** the issue is closed on GitHub after the launch refresh

#### Scenario: Refused for good
- **WHEN** the user renames an item whose issue was deleted meanwhile
- **THEN** the change is dropped and the item is removed at the refresh

### Requirement: Token no longer accepted
When GitHub rejects the saved token, sync SHALL pause for every list until the user connects again. Every linked list MUST show the x after its refresh button, and its GitHub menu MUST show "GitHub token no longer works" and "Reconnect…". "Reconnect…" MUST open Settings on the Integrations pane. Changes waiting MUST be kept.

#### Scenario: Revoked token
- **WHEN** the user revokes the token on GitHub and a refresh runs
- **THEN** every linked list shows the x, and its GitHub menu shows "GitHub token no longer works" and "Reconnect…"
- **AND** choosing "Reconnect…" opens Settings on Integrations

