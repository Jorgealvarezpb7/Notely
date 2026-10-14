import AppKit
import SwiftUI

/// The two fonts the user can choose for note and list text.
enum FontFamily: String {
    case typewriter, system

    /// Title of the font in the Font pop-up in Settings.
    var menuTitle: String {
        switch self {
        case .typewriter: return "American Typewriter"
        case .system: return "System"
        }
    }
}

/// The one font and text size for every note and list. Each change is
/// saved to `UserDefaults` at once, under keys apart from `notes`, so a
/// build without this setting still reads notes and ignores it.
@Observable
public final class TextAppearance {
    static let sizeRange = 10...20
    /// Menu rows follow the font choice but always keep this size.
    static let menuSize: CGFloat = 15
    private static let familyKey = "textFontFamily"
    private static let sizeKey = "textFontSize"

    var family: FontFamily {
        didSet { UserDefaults.standard.set(family.rawValue, forKey: Self.familyKey) }
    }

    /// Callers keep this within `sizeRange`; the slider cannot leave it.
    var size: Int {
        didSet { UserDefaults.standard.set(size, forKey: Self.sizeKey) }
    }

    /// No saved setting means American Typewriter at 15 points. An
    /// unknown font falls back to American Typewriter, and a size outside
    /// `sizeRange` to the nearest limit.
    public init() {
        let defaults = UserDefaults.standard
        family = defaults.string(forKey: Self.familyKey).flatMap(FontFamily.init(rawValue:)) ?? .typewriter
        let saved = defaults.object(forKey: Self.sizeKey) as? Int ?? 15
        size = min(max(saved, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
    }

    /// The chosen font at `size`, for SwiftUI text.
    func swiftUIFont(size: CGFloat) -> Font {
        switch family {
        case .typewriter: return .custom("American Typewriter", size: size)
        case .system: return .system(size: size)
        }
    }

    /// The chosen font at the chosen size, for AppKit text. Falls back to
    /// the system font if American Typewriter is missing.
    func nsFont(bold: Bool) -> NSFont {
        let size = CGFloat(self.size)
        if family == .typewriter,
           let font = NSFont(name: bold ? "AmericanTypewriter-Bold" : "AmericanTypewriter", size: size) {
            return font
        }
        return .systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    /// Display attributes for note text with these traits: the chosen
    /// font, bold when asked, and for italic the font's italic face, or a
    /// slant when the font has none (American Typewriter).
    func noteAttributes(bold: Bool, italic: Bool) -> [NSAttributedString.Key: Any] {
        var font = nsFont(bold: bold)
        if italic {
            let descriptor = font.fontDescriptor.withSymbolicTraits(font.fontDescriptor.symbolicTraits.union(.italic))
            if let italicFont = NSFont(descriptor: descriptor, size: font.pointSize),
               italicFont.familyName == font.familyName,
               italicFont.fontDescriptor.symbolicTraits.contains(.italic) {
                font = italicFont
            } else {
                font = Self.slanted(font)
            }
        }
        return [.font: font, .foregroundColor: NSColor.textColor]
    }

    /// `font` sheared to the right, for a font with no italic face. The
    /// slant is part of the font, not an `.obliqueness` attribute, which
    /// the TextKit 2 note editor does not draw.
    private static func slanted(_ font: NSFont) -> NSFont {
        let size = font.pointSize
        let shear = AffineTransform(m11: size, m12: 0, m21: size * 0.2, m22: size, tX: 0, tY: 0)
        return NSFont(descriptor: font.fontDescriptor, textTransform: shear) ?? font
    }
}
