import AppKit
import NotelyLinks
import SwiftUI

/// Where keyboard focus can go in a list window, in display order: the
/// title, the items, and the "New item" row between unchecked and checked
/// items.
enum FocusTarget: Equatable {
    case title
    case item(UUID)
    case newItem
}

/// A list window's pending focus move. The `ListField` whose target
/// matches takes keyboard focus on the next run loop turn, once SwiftUI
/// has created its view, and clears the request.
final class ListFocus: ObservableObject {
    @Published var request: FocusTarget?
}

/// Keys a `ListField` hands to its list instead of editing its own text.
enum ListCommand {
    case returnKey, deleteEmpty, up, down, toggle
}

/// The `NSTextField` behind every editable list row. It answers "Check
/// Item" (Cmd+Return) only while it is an item: AppKit enables a menu item
/// only when some responder responds to its action.
final class ListTextField: NSTextField, LinkHost {
    var isTitle = false
    var onToggle: (() -> Void)?

    /// Cmd+click on a link opens it, also while another app is active,
    /// and does not start editing.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if openLink(for: event) { return }
        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        if LinkHoverController.shared.isActive {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }

    /// The link under `point` while the row is not being edited, found by
    /// laying out the shown text in a separate TextKit 1 stack the size of
    /// the cell's text area. While the row is edited, the field editor,
    /// which sits on top of the row, answers instead.
    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        guard currentEditor() == nil, let cell else { return nil }
        let text = attributedStringValue
        let links = LinkDetector.links(in: text.string)
        guard !links.isEmpty else { return nil }

        let textRect = cell.titleRect(forBounds: bounds)
        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: textRect.width, height: .greatestFiniteMagnitude))
        // NSTextFieldCell lays out its text with this padding.
        container.lineFragmentPadding = 2
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        // Container coordinates run down from the top of the text area.
        func toContainer(_ point: NSPoint) -> NSPoint {
            NSPoint(x: point.x - textRect.minX,
                    y: isFlipped ? point.y - textRect.minY : textRect.maxY - point.y)
        }
        func toView(_ rect: NSRect) -> NSRect {
            NSRect(x: rect.minX + textRect.minX,
                   y: isFlipped ? rect.minY + textRect.minY : textRect.maxY - rect.maxY,
                   width: rect.width, height: rect.height)
        }

        let containerPoint = toContainer(point)
        var fraction: CGFloat = 0
        let glyph = layoutManager.glyphIndex(for: containerPoint, in: container,
                                             fractionOfDistanceThroughGlyph: &fraction)
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyph, length: 1), in: container)
        guard glyphRect.contains(containerPoint) else { return nil }
        let index = layoutManager.characterIndexForGlyph(at: glyph)
        guard let link = links.first(where: { NSLocationInRange(index, $0.range) }) else { return nil }
        // The rect of the link's piece on the line under the pointer.
        var lineRange = NSRange()
        _ = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: &lineRange)
        let linkGlyphs = NSIntersectionRange(layoutManager.glyphRange(forCharacterRange: link.range,
                                                                      actualCharacterRange: nil),
                                             lineRange)
        let rect = layoutManager.boundingRect(forGlyphRange: linkGlyphs, in: container)
        return (link.url, toView(rect))
    }

    override func responds(to aSelector: Selector!) -> Bool {
        if aSelector == #selector(toggleChecklistItem(_:)) { return onToggle != nil }
        return super.responds(to: aSelector)
    }

    @objc func toggleChecklistItem(_ sender: Any?) {
        onToggle?()
    }
}

/// The field editor of list rows: AppKit's shared editor for a window,
/// replaced in list windows so rows show links and open them with
/// Cmd+click while they are edited. TextKit 1, like AppKit's own field
/// editor; `ListField` reads its `layoutManager` for caret lines.
final class LinkFieldEditor: NSTextView, LinkHost {
    private var links: [DetectedLink] = []

    func refreshLinks() {
        links = showLinks()
    }

    /// The row's text arrives here when editing starts, and when the list
    /// changes it from outside.
    override var string: String {
        didSet { refreshLinks() }
    }

    override func didChangeText() {
        super.didChangeText()
        refreshLinks()
    }

    /// AppKit inserts the editor into a row each time editing starts.
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        DispatchQueue.main.async { [weak self] in self?.refreshLinks() }
    }

    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        link(in: links, at: point)
    }

    override func mouseDown(with event: NSEvent) {
        if openLink(for: event) { return }
        super.mouseDown(with: event)
    }

    override func cursorUpdate(with event: NSEvent) {
        if LinkHoverController.shared.isActive {
            NSCursor.pointingHand.set()
        } else {
            super.cursorUpdate(with: event)
        }
    }
}

/// One editable, wrapping list row: the title, an item, or "New item".
/// AppKit rather than a SwiftUI `TextField`, because Return, Backspace and
/// the arrow keys must be intercepted, and `onKeyPress` needs macOS 14.
struct ListField: NSViewRepresentable {
    let text: String
    let placeholder: String
    let font: NSFont
    var done = false
    var isTitle = false
    var canToggle = false
    /// `false` for an item of an issue the user may not rename: the text
    /// can still be selected and copied.
    var isEditable = true
    let target: FocusTarget
    @ObservedObject var focus: ListFocus
    var onChange: (String) -> Void
    var onBeginEditing: () -> Void = {}
    var onEndEditing: () -> Void = {}
    var onCommand: (ListCommand) -> Bool = { _ in false }

    /// All list text, placeholders included, is white in dark appearance
    /// and black in light appearance, except web addresses, which show as
    /// links; checked items are struck through, links included.
    static func styled(_ text: String, font: NSFont, done: Bool) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ]
        if done {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        for link in LinkDetector.links(in: text) {
            result.addAttributes(linkDisplayAttributes, range: link.range)
        }
        return result
    }

    static func placeholderString(_ placeholder: String, font: NSFont) -> NSAttributedString {
        NSAttributedString(string: placeholder, attributes: [
            .font: font,
            .foregroundColor: NSColor.textColor,
        ])
    }

    func makeNSView(context: Context) -> ListTextField {
        let field = ListTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.usesSingleLineMode = false
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = 0
        field.font = font
        field.textColor = .textColor
        field.placeholderAttributedString = Self.placeholderString(placeholder, font: font)
        field.delegate = context.coordinator
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: ListTextField, context: Context) {
        context.coordinator.parent = self
        field.isTitle = isTitle
        if field.isEditable != isEditable {
            field.isEditable = isEditable
        }
        if canToggle {
            let onCommand = self.onCommand
            field.onToggle = { _ = onCommand(.toggle) }
        } else {
            field.onToggle = nil
        }

        // The text appearance setting changed: restyle in place. The field
        // editor keeps its text, caret, and undo history; only its font
        // changes.
        if field.font != font {
            field.font = font
            field.placeholderAttributedString = Self.placeholderString(placeholder, font: font)
            if let editor = field.currentEditor() as? NSTextView {
                editor.font = font
                editor.typingAttributes[.font] = font
            }
            field.invalidateIntrinsicContentSize()
        }

        if let editor = field.currentEditor() as? NSTextView {
            // While editing, the store already holds the typed text; only
            // an outside change (the "New item" row turning into an item)
            // replaces it. Never touch text an input method is composing.
            if !editor.hasMarkedText(), editor.string != text {
                editor.string = text
            }
        } else {
            field.attributedStringValue = Self.styled(text, font: font, done: done)
        }

        if focus.request == target {
            let listFocus = self.focus
            let wanted = self.target
            DispatchQueue.main.async { [weak field] in
                guard let field, let window = field.window, listFocus.request == wanted else { return }
                listFocus.request = nil
                window.makeFirstResponder(field)
                let end = (field.stringValue as NSString).length
                field.currentEditor()?.selectedRange = NSRange(location: end, length: 0)
            }
        }
    }

    /// Height of the wrapped text at the proposed width, so long items
    /// grow downward instead of being cut off.
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: ListTextField, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0,
              let cell = nsView.cell?.copy() as? NSCell else { return nil }
        // Without this the field's intrinsic width is its text on one
        // line, which can push the window's content wider than the window.
        nsView.preferredMaxLayoutWidth = width
        cell.attributedStringValue = Self.styled(text.isEmpty ? " " : text, font: font, done: done)
        let size = cell.cellSize(forBounds: NSRect(x: 0, y: 0, width: width,
                                                   height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ListField

        init(_ parent: ListField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            // Wait for an input method to commit (Option-e, then e)
            // before saving, so the "New item" row never turns into an
            // item halfway through a composed character.
            if let editor = notification.userInfo?["NSFieldEditor"] as? NSTextView,
               editor.hasMarkedText() { return }
            parent.onChange(field.stringValue)
        }

        func controlTextDidBeginEditing(_ notification: Notification) {
            parent.onBeginEditing()
        }

        /// Ending an edit puts the field editor's plain text back into
        /// the field, dropping the checked style; restyle it at once.
        func controlTextDidEndEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField {
                field.attributedStringValue = ListField.styled(field.stringValue, font: parent.font,
                                                               done: parent.done)
            }
            parent.onEndEditing()
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                // Cmd+Return normally arrives through the "Check Item"
                // menu item; this covers it reaching the field editor.
                if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                    return parent.onCommand(.toggle)
                }
                return parent.onCommand(.returnKey)
            case #selector(NSResponder.deleteBackward(_:)):
                return textView.string.isEmpty && parent.onCommand(.deleteEmpty)
            case #selector(NSResponder.moveUp(_:)):
                return caretLine(in: textView).isFirst && parent.onCommand(.up)
            case #selector(NSResponder.moveDown(_:)):
                return caretLine(in: textView).isLast && parent.onCommand(.down)
            case #selector(NSResponder.cancelOperation(_:)):
                control.window?.makeFirstResponder(nil)
                return true
            default:
                return false
            }
        }

        /// Whether the caret is on the first and/or last wrapped line of
        /// the field, so Up and Down move inside a long item before they
        /// move to the next row.
        private func caretLine(in textView: NSTextView) -> (isFirst: Bool, isLast: Bool) {
            let length = (textView.string as NSString).length
            guard length > 0, let layoutManager = textView.layoutManager else { return (true, true) }
            func lineY(_ characterIndex: Int) -> CGFloat {
                let glyph = layoutManager.glyphIndexForCharacter(at: characterIndex)
                return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).minY
            }
            let caret = min(textView.selectedRange().location, length - 1)
            let y = lineY(caret)
            return (y <= lineY(0), y >= lineY(length - 1))
        }
    }
}
