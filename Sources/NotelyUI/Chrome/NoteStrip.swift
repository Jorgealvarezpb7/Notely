import AppKit
import NotelyCore
import SwiftUI

/// A small borderless button for "−" and trash in the drag strip, and for
/// the bottom bar's buttons. It accepts the first click even while the
/// app is not active, so one click works while another app is frontmost.
/// The action gets the button, to anchor a menu or popover on it.
struct StripButton: NSViewRepresentable {
    final class FirstMouseButton: NSButton {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    }

    /// Reuses the standard close button's natural size purely as a sizing
    /// constant; the button itself is never shown. Keeps the strip height
    /// and button hit targets the same as when the window had a close button.
    static let referenceSize = NSWindow.standardWindowButton(.closeButton, for: [.titled, .closable])!.frame.size

    let symbolName: String
    let accessibilityLabel: String
    /// `nil` for a plain button. Set for an on/off button (the style
    /// buttons): no background in any state; the symbol shows in the
    /// label color (white in dark appearance) while on and gray while
    /// off. The button never takes keyboard focus, so the note keeps its
    /// selection.
    var isOn: Bool? = nil
    /// Set for a color swatch (the tint button): the symbol shows in this
    /// color instead of the bar's icon color.
    var color: NSColor? = nil
    /// Called once with the button when it is made, for controls that
    /// open a menu or popover at it without a click (a shortcut).
    var onMake: ((NSButton) -> Void)? = nil
    let action: (NSButton) -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = FirstMouseButton()
        button.isBordered = false
        button.bezelStyle = .regularSquare
        if isOn != nil {
            button.refusesFirstResponder = true
        }
        button.setAccessibilityLabel(accessibilityLabel)
        button.target = context.coordinator
        button.action = #selector(Coordinator.fire(_:))
        onMake?(button)
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        context.coordinator.action = action
        // The tint button switches between "circle" and "circle.fill".
        if context.coordinator.symbolName != symbolName {
            context.coordinator.symbolName = symbolName
            nsView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityLabel)
            nsView.image?.isTemplate = true
        }
        if let isOn {
            nsView.contentTintColor = isOn ? .labelColor : .secondaryLabelColor
        } else {
            nsView.contentTintColor = color
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    final class Coordinator: NSObject {
        var action: (NSButton) -> Void
        var symbolName: String?
        init(action: @escaping (NSButton) -> Void) { self.action = action }
        @objc func fire(_ sender: NSButton) { action(sender) }
    }
}

/// Height of the top and bottom bars: the buttons plus a margin around
/// them.
let barHeight = max(16, StripButton.referenceSize.height) + 12

/// Gap between a bar and the note or list content.
let barGap: CGFloat = 4

/// Shade of both bars: `primary` is black in light appearance and white
/// in dark appearance, so the bars show darker or lighter than the note.
let barFill = Color.primary.opacity(0.08)

/// Strength of a note's tint over the material: one value for every
/// color, low enough that the desktop always shows through.
let tintStrength = 0.2

/// The background of note and list windows: the translucent material,
/// with the note's tint, if any, as a faint wash over it.
struct NoteBackground: View {
    let tint: String?

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            if let color = tintColor(tint) {
                Color(nsColor: color).opacity(tintStrength)
            }
        }
    }
}

/// Fill of the logo in the top bar, a stronger tint of `barFill`'s color:
/// black in light appearance and white in dark appearance, quieter than
/// the bar's buttons. White gets more alpha because it looks weaker on
/// the dark material.
let logoFill = Color(nsColor: NSColor(name: nil) { appearance in
    appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        ? NSColor.white.withAlphaComponent(0.30)
        : NSColor.black.withAlphaComponent(0.25)
})

/// Outline of the Notely logo: the `d` attribute of
/// `Packaging/notely-logo.svg`, whose viewBox is 837 by 465 and whose fill
/// rule is even-odd.
let notelyLogoPathData = "M 209,4 203,14 202,25 201,26 201,52 202,53 203,65 206,72 209,76 216,79 242,79 243,80 250,80 251,81 251,376 249,378 221,378 220,379 214,379 210,381 205,387 203,393 203,398 202,399 202,431 203,432 204,442 208,450 211,453 216,455 388,455 391,454 397,447 400,437 400,431 401,430 401,401 400,400 400,395 398,389 394,382 388,379 382,379 381,378 336,378 334,375 335,373 335,368 334,367 334,197 335,196 335,167 337,164 340,167 354,188 377,227 383,235 512,450 520,458 532,463 538,463 539,464 561,464 562,463 571,462 580,458 586,452 589,445 589,88 590,87 590,81 591,80 621,79 626,77 629,74 632,68 633,60 634,59 634,49 635,48 635,27 634,26 633,16 629,7 625,3 622,2 601,2 600,1 486,1 485,2 475,1 474,2 460,2 457,3 453,7 450,13 448,20 447,42 448,43 448,60 449,61 450,68 453,74 456,77 461,79 489,79 490,80 503,80 504,81 504,92 505,93 505,116 504,117 504,123 505,124 504,125 505,126 504,128 505,129 504,130 505,131 505,142 504,143 504,146 505,147 505,155 504,156 505,159 504,160 505,202 504,204 505,206 504,207 504,211 505,212 505,222 504,223 504,271 503,272 499,268 357,29 351,21 343,7 340,4 335,2 327,2 326,1 236,1 235,2 213,2 Z M 801,0 800,1 795,1 786,5 777,13 773,20 771,27 771,41 772,42 772,50 773,51 774,65 775,66 777,85 779,92 782,119 783,120 783,125 784,126 784,131 786,138 786,144 789,151 793,155 800,158 809,158 815,155 819,151 821,146 822,136 823,135 823,129 824,128 824,122 825,121 825,115 827,108 827,102 828,101 828,94 829,93 831,75 832,74 832,68 833,67 834,55 835,54 837,31 836,30 835,22 832,16 825,8 813,1 Z M 714,0 713,1 708,1 699,5 691,12 687,18 684,26 684,44 685,45 685,51 686,52 686,58 687,59 688,72 690,79 690,85 691,86 691,92 692,93 693,106 694,107 695,119 697,126 697,133 698,134 699,145 701,150 707,156 711,158 721,158 726,156 732,150 734,145 737,119 738,118 738,112 739,111 739,105 740,104 741,92 742,91 743,79 744,78 744,72 745,71 747,53 748,52 749,35 750,34 749,33 749,25 744,14 736,6 725,1 Z M 117,0 116,1 107,2 97,8 91,15 87,24 86,40 87,41 88,56 89,57 90,71 92,78 92,84 93,85 93,91 94,92 94,98 95,99 95,105 96,106 96,113 97,114 97,121 98,122 99,137 100,138 101,147 103,151 108,156 112,158 123,158 129,155 132,152 135,146 136,135 137,134 137,127 139,120 139,114 140,113 141,101 142,100 144,82 145,81 145,75 146,74 146,69 147,68 147,63 149,56 149,50 150,49 150,43 151,42 151,28 146,15 137,6 126,1 Z M 29,0 28,1 23,1 16,4 9,9 3,17 0,25 0,45 1,46 3,69 4,70 4,76 6,83 6,90 7,91 7,97 9,104 9,110 10,111 10,117 11,118 12,131 13,132 13,138 14,139 15,147 17,151 22,156 27,158 37,158 43,155 46,152 49,145 52,119 53,118 53,112 54,111 54,104 56,97 57,83 58,82 59,70 61,63 61,56 62,55 62,49 63,48 64,29 60,17 50,6 39,1 Z"

/// The Notely logo, drawn from `notelyLogoPathData` and scaled to fit the
/// proposed rect with its proportions kept. The parser handles only what
/// that file uses: absolute `M`, then `x,y` points joined by straight
/// lines, then `Z`. An export with relative commands or curves needs a
/// new parser.
struct NotelyLogo: Shape {
    static let viewBox = CGSize(width: 837, height: 465)

    /// Each subpath's points, in viewBox units. SVG and SwiftUI both put
    /// the origin at the top left with y pointing down, so no flip.
    static let subpaths: [[CGPoint]] = {
        var subpaths: [[CGPoint]] = []
        var current: [CGPoint] = []
        for token in notelyLogoPathData.split(whereSeparator: \.isWhitespace) {
            switch token {
            case "M":
                current = []
            case "Z":
                if !current.isEmpty { subpaths.append(current) }
                current = []
            default:
                let pair = token.split(separator: ",").compactMap { Double($0) }
                if pair.count == 2 {
                    current.append(CGPoint(x: pair[0], y: pair[1]))
                }
            }
        }
        return subpaths
    }()

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / Self.viewBox.width, rect.height / Self.viewBox.height)
        var path = Path()
        for points in Self.subpaths {
            path.addLines(points.map { CGPoint(x: rect.minX + $0.x * scale,
                                               y: rect.minY + $0.y * scale) })
            path.closeSubpath()
        }
        return path
    }
}

/// The top bar shared by note and list windows: drags the window and
/// ends editing, with the Notely logo at its center and "−" (close) and
/// trash (delete) at the trailing edge.
struct NoteStrip: View {
    var onClose: () -> Void
    var onDelete: () -> Void

    /// Logo size: shorter than the bar, with its artwork's proportions.
    static let logoHeight: CGFloat = 12
    static let logoWidth = logoHeight * NotelyLogo.viewBox.width / NotelyLogo.viewBox.height

    /// Narrowest bar that shows the logo at its center with 8 points to
    /// spare before "−": the buttons take their trailing padding, two
    /// button widths, and the gap between them.
    static let logoMinimumWidth: CGFloat = {
        let buttons = 12 + 2 * StripButton.referenceSize.width + 16
        return 2 * (buttons + 8) + logoWidth
    }()

    var body: some View {
        // The buttons sit on top of the click target, so clicks on them
        // never start a window drag.
        ZStack {
            EndEditingView(drags: true)
            // Decoration only: clicks and drags fall through to the click
            // target below. Hidden when it would touch "−".
            GeometryReader { proxy in
                if proxy.size.width >= Self.logoMinimumWidth {
                    NotelyLogo()
                        .fill(logoFill, style: FillStyle(eoFill: true))
                        .frame(width: Self.logoWidth, height: Self.logoHeight)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            // The wide gap keeps trash away from "−", so a close is not
            // mistaken for a delete.
            HStack(spacing: 16) {
                Spacer(minLength: 0)
                StripButton(symbolName: "minus", accessibilityLabel: "Close Note", action: { _ in onClose() })
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
                StripButton(symbolName: "trash", accessibilityLabel: "Delete Note", action: { _ in onDelete() })
                    .frame(width: StripButton.referenceSize.width,
                           height: StripButton.referenceSize.height)
            }
            .padding(.trailing, 12)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
        .frame(height: barHeight)
        .background(barFill)
    }
}

/// Height of the bottom bar: 20% lower than the top bar, which needs
/// room for the buttons.
let bottomBarHeight = (barHeight * 0.8).rounded()
