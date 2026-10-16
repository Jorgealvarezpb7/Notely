import CoreGraphics
import Foundation
@testable import NotelyCore
import Testing

private let screen = NSRect(x: 0, y: 0, width: 1000, height: 800)

struct ParsePairTests {
    /// Accepts "{10, 20}" and "{10.0, 20.0}".
    @Test(arguments: ["{10, 20}", "{10.0, 20.0}", " {10,20} "])
    func parsesBothFormats(_ saved: String) {
        let pair = parsePair(saved)
        #expect(pair?.0 == 10)
        #expect(pair?.1 == 20)
    }

    @Test func rejectsUnusableValues() {
        #expect(parsePair(nil) == nil)
        #expect(parsePair("{1}") == nil)
        #expect(parsePair("junk") == nil)
        #expect(parsePair("{a, b}") == nil)
    }

    @Test func savedSizeFallsBackToDefault() {
        #expect(savedSize(nil) == defaultNoteSize)
        #expect(savedSize("junk") == defaultNoteSize)
        #expect(savedSize("{300, 200}") == NSSize(width: 300, height: 200))
    }
}

struct FitTests {
    @Test func capsAtScreen() {
        #expect(fit(NSSize(width: 1200, height: 900), into: screen) == NSSize(width: 1000, height: 800))
    }

    @Test func floorsAtMinimum() {
        #expect(fit(NSSize(width: 100, height: 50), into: screen) == minimumNoteSize)
        #expect(fit(NSSize(width: 100, height: 50), into: screen, minimum: minimumMenuSize) == minimumMenuSize)
    }

    @Test func keepsSizeThatFits() {
        #expect(fit(NSSize(width: 300, height: 200), into: screen) == NSSize(width: 300, height: 200))
    }

    @Test func clampMovesFrameInside() {
        let frame = NSRect(x: 950, y: 10, width: 100, height: 100)
        #expect(clamp(frame, into: screen) == NSPoint(x: 900, y: 10))
    }
}

struct RestoredFrameTests {
    @Test func savedOriginOpensThere() {
        let frame = restoredFrame(saved: "{100, 100}", size: NSSize(width: 220, height: 150), screens: [screen])
        #expect(frame == NSRect(x: 100, y: 100, width: 220, height: 150))
    }

    @Test func nothingSavedUsesDefaultPosition() {
        #expect(restoredFrame(saved: nil, size: defaultNoteSize, screens: [screen]) == nil)
    }

    @Test func frameOnNoScreenUsesDefaultPosition() {
        let frame = NSRect(x: 3000, y: 3000, width: 220, height: 150)
        #expect(restoredFrame(frame, screens: [screen]) == nil)
    }

    @Test func frameHalfOffscreenMovesInside() {
        let frame = NSRect(x: 900, y: 700, width: 200, height: 200)
        #expect(restoredFrame(frame, screens: [screen]) == NSRect(x: 800, y: 600, width: 200, height: 200))
    }

    @Test func frameGoesToScreenItOverlapsMost() {
        let right = NSRect(x: 1000, y: 0, width: 1000, height: 800)
        let frame = NSRect(x: 950, y: 100, width: 200, height: 100)
        #expect(restoredFrame(frame, screens: [screen, right]) == NSRect(x: 1000, y: 100, width: 200, height: 120))
    }

    @Test func frameSmallerThanMinimumGrows() {
        let frame = NSRect(x: 100, y: 100, width: 60, height: 100)
        #expect(restoredFrame(frame, screens: [screen]) == NSRect(x: 100, y: 100, width: 190, height: 120))
    }

    @Test func frameLargerThanScreenShrinks() {
        let frame = NSRect(x: 0, y: 0, width: 1500, height: 1200)
        #expect(restoredFrame(frame, screens: [screen]) == screen)
    }
}

struct NewNoteFrameTests {
    @Test func opensRightOfMenu() {
        let menu = NSRect(x: 100, y: 300, width: 260, height: 360)
        #expect(newNoteFrame(menu: menu, screen: screen) == NSRect(x: 372, y: 510, width: 220, height: 150))
    }

    @Test func opensLeftOfMenuWhenRightDoesNotFit() {
        let menu = NSRect(x: 700, y: 300, width: 260, height: 360)
        #expect(newNoteFrame(menu: menu, screen: screen) == NSRect(x: 468, y: 510, width: 220, height: 150))
    }

    @Test func movesInsideWhenNeitherSideFits() {
        let narrow = NSRect(x: 0, y: 0, width: 500, height: 800)
        let menu = NSRect(x: 100, y: 300, width: 260, height: 360)
        #expect(newNoteFrame(menu: menu, screen: narrow) == NSRect(x: 280, y: 510, width: 220, height: 150))
    }
}
