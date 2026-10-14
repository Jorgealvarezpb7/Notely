# Design

## Context

`NoteWindowController.closeNote` (`Sources/NotelyUI/App/NoteWindowController.swift`) detaches the window, marks the note closed in the store, and calls `window.close()`. `open(_:)` marks the note open and calls `openWindow(for:)`, which builds the window and orders it in. Note windows have no `.miniaturizable` style, and their traffic-light buttons are hidden. The main menu has no Minimize item.

macOS has no public API to play the minimize animation on its own, and none that returns the frame of an app's Dock icon. A first attempt drew a picture of the note shrinking and fading toward a computed Dock point. It did not look native, and without the Accessibility permission (which the app never asks for) it landed in the middle of the Dock. It was dropped.

## Goals / Non-Goals

**Goals:**
- The exact system animation, by minimizing the real window.
- No permission and no private API.
- Closing keeps today's save order: the note is saved and closed before the animation runs.

**Non-Goals:**
- Choosing where the note lands. macOS decides: the minimized-windows area next to the Trash, or the app icon when the user's Dock setting says so.
- Animating delete, launch, "+ New", or rows of notes that are already open.

## Decisions

### 1. Minimize the real window, then close it

Note windows get `.miniaturizable` (the button stays hidden, as it already is), so `miniaturize(_:)` plays the user's chosen effect. `closeNote` becomes: detach the window (its delegate goes, so no frame is saved) → `store.setOpen(false, for:)` → `window.miniaturize(nil)`. When `NSWindow.didMiniaturizeNotification` arrives for that window, `window.close()` removes its Dock tile.

- Alternatives considered: a picture of the note shrinking and fading (tried; did not look native), a strip-sliced fake genie (close, not exact), and private CGS window-warp calls (can break on any macOS update).

### 2. Reopen: show invisible, minimize, restore

macOS restores a window from the Dock only if it was on screen when it was minimized. `open(_:)` for a closed note therefore builds the window without showing it (`openWindow(for:show: false)`), sets `alphaValue = 0` and orders it in. On the next run-loop turn it calls `miniaturize(nil)`, an animation no one sees. On `didMiniaturizeNotification` it sets `alphaValue = 1` and, on the next turn, calls `deminiaturize(nil)`, which plays the system restore animation to the saved frame. On `didDeminiaturizeNotification` it calls `makeKeyAndOrderFront`.

- Tried first, and dropped: minimizing a window that was never shown. macOS put it in the Dock but restored it only on a click on its tile.
- `reopening: Set<UUID>` marks a note on its way out. Another click on its row does nothing, so no second window opens. If the note is already visible in the Dock but not restored, the click restores it, as a click on its tile would.
- `closeNote` on a note still in the Dock closes it at once, since no minimize notification would come.
- Cost: a short pause and a tile in the Dock between the click and the restore.

### 3. One-shot observers

A small helper, `once(_:of:run:)`, adds a block observer for one notification on one window, keeps its token in a controller property, and removes it when it fires. Each step checks that the note's window is still the current one before acting, so a note closed or deleted mid-animation is not shown again. The closure keeps a closing window alive until it closes. A row clicked during the close animation opens a new window for the note; the closing one is already detached and closes on its own.

### 4. Skip conditions

The animations play only when both hold: the Settings switch is on, and `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is false. Otherwise notes close or open instantly (today's code path). Delete (`removeNote`) is unchanged.

### 5. The Settings switch

`NoteAnimation` (in `NoteWindowController.swift`) holds the `UserDefaults` key `animateNotes` and reads it, with `true` when nothing is saved. `GeneralPane` binds the switch with `@AppStorage(NoteAnimation.key)`. The controller reads the value at each close and open, so a change applies at once, with no observer. The key is apart from `notes`, so builds without this setting ignore it, as with the font keys.

- Alternative considered: a property on `TextAppearance`. Rejected: that type is about text, and nothing else needs to observe the switch.

## Risks / Trade-offs

- [The note's tile appears in the Dock for a moment, and the Dock closes the gap when it goes] → Accepted; it's what makes the animation native.
- [The landing spot isn't the Notely icon by default] → Accepted by the user; it is the right end of the Dock, or the icon with "Minimize windows into application icon".
- [`didMiniaturize` never arrives, e.g. the system refuses to minimize] → The closing window stays minimized in the Dock. Clicking its tile would show it, detached. Low risk: the style mask allows minimizing.
