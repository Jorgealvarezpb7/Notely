import CoreGraphics
import Foundation

/// Moves `frame` the shortest distance (x and y only) to sit fully inside
/// `screen`. Shared by `restoredFrame` (relaunch) and `newNoteFrame` (a
/// new note or list placed next to the menu), so both use the same rule.
func clamp(_ frame: NSRect, into screen: NSRect) -> NSPoint {
    NSPoint(x: min(max(frame.minX, screen.minX), screen.maxX - frame.width),
           y: min(max(frame.minY, screen.minY), screen.maxY - frame.height))
}

/// Smallest size a note or list window can have: wide enough for the
/// six bottom bar buttons of a note, and room for the bottom bar and one
/// line of text.
public let minimumNoteSize = NSSize(width: 190, height: 120)

/// Size of a note with no saved size.
let defaultNoteSize = NSSize(width: 220, height: 150)

/// Smallest size of the menu window.
public let minimumMenuSize = NSSize(width: 200, height: 200)

/// Size of the menu window with no saved frame.
public let defaultMenuSize = NSSize(width: 260, height: 360)

/// Parses the "{a, b}" form written by `NSStringFromPoint` and
/// `NSStringFromSize`. Their `...FromString` counterparts return .zero for
/// unparsable text, which is indistinguishable from a real value.
func parsePair(_ saved: String?) -> (Double, Double)? {
    guard let saved else { return nil }
    let numbers = saved
        .trimmingCharacters(in: CharacterSet(charactersIn: "{} "))
        .split(separator: ",")
        .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard numbers.count == 2 else { return nil }
    return (numbers[0], numbers[1])
}

/// A saved `NSStringFromSize` size, or the default size when nothing
/// usable is saved.
public func savedSize(_ saved: String?) -> NSSize {
    guard let pair = parsePair(saved) else { return defaultNoteSize }
    return NSSize(width: pair.0, height: pair.1)
}

/// `size` capped at `screen`'s size and floored at `minimum`.
public func fit(_ size: NSSize, into screen: NSRect, minimum: NSSize = minimumNoteSize) -> NSSize {
    NSSize(width: max(min(size.width, screen.width), minimum.width),
           height: max(min(size.height, screen.height), minimum.height))
}

/// Where to open a window from a saved `NSStringFromPoint` origin: the
/// saved frame, shrunk to fit and then moved the shortest distance to sit
/// fully inside the screen it overlaps most. Returns `nil` when nothing
/// usable is saved or the saved frame is on no screen, so the caller uses
/// the default position.
public func restoredFrame(saved: String?, size: NSSize, screens: [NSRect]) -> NSRect? {
    guard let pair = parsePair(saved) else { return nil }
    return restoredFrame(NSRect(origin: NSPoint(x: pair.0, y: pair.1), size: size),
                         screens: screens)
}

/// `frame` shrunk to fit (no smaller than `minimum`) and moved the shortest
/// distance to sit fully inside the screen it overlaps most, or `nil` when
/// it is on no screen.
public func restoredFrame(_ frame: NSRect, screens: [NSRect], minimum: NSSize = minimumNoteSize) -> NSRect? {
    func overlap(_ screen: NSRect) -> CGFloat {
        let common = screen.intersection(frame)
        return common.isNull ? 0 : common.width * common.height
    }
    guard let screen = screens.max(by: { overlap($0) < overlap($1) }),
          overlap(screen) > 0 else { return nil }

    let fitted = fit(frame.size, into: screen, minimum: minimum)
    let origin = clamp(NSRect(origin: frame.origin, size: fitted), into: screen)
    return NSRect(origin: origin, size: fitted)
}

/// Frame for a note created from the menu: the default note size, top
/// edges aligned, 12 points right of the menu; else 12 points left of it;
/// else the right-hand frame moved the shortest distance into `screen`.
public func newNoteFrame(menu: NSRect, screen: NSRect) -> NSRect {
    let size = fit(defaultNoteSize, into: screen)
    let y = menu.maxY - size.height
    let right = NSRect(x: menu.maxX + 12, y: y, width: size.width, height: size.height)
    if screen.contains(right) { return right }
    let left = NSRect(x: menu.minX - 12 - size.width, y: y, width: size.width, height: size.height)
    if screen.contains(left) { return left }
    return NSRect(origin: clamp(right, into: screen), size: size)
}
