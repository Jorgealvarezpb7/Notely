import AppKit
import NotelyCore
import NotelyLinks
import SwiftUI

/// A note's text view. Text carries bold and italic as trait attributes
/// and underline as `underlineStyle`; `restyle` derives the font, slant,
/// and color from the traits and the text appearance setting, so a font
/// or size change keeps every style. AppKit rather than `TextEditor`,
/// which shows no attributed text before macOS 26.
final class NoteTextView: NSTextView, LinkHost, NSTextContentStorageDelegate {
    static let styledTextType = NSPasteboard.PasteboardType("com.alvarezjorge.Notely.styled-text")

    var textAppearance: TextAppearance?
    /// Link pages for the cards; set before `setUpLinkCards()`.
    var linkPages: LinkPageStore?
    var placeholder = "Type a note…"
    /// Called whenever the active styles may have changed.
    var onStylesChange: ((Set<TextStyle>) -> Void)?
    private var renderedFamily: FontFamily?
    private var renderedSize: Int?
    /// The web addresses shown as links, found again after every change.
    private var links: [DetectedLink] = []
    /// Cards above paragraphs with links, in text order.
    private var cardHosts: [LinkCardHost] = []
    /// Asks for pages a second after typing stops.
    private var requestTimer: Timer?
    private var pagesObserver: Any?
    private var cardLayoutPending = false
    /// The room last laid out above each card paragraph, by paragraph start.
    private var cardRooms: [Int: CGFloat] = [:]
    /// Room for the first paragraph's card, above the text. TextKit
    /// leaves out the space before the first paragraph, so its card's
    /// room moves the text container down instead.
    private var topRoom: CGFloat = 0

    deinit {
        if let pagesObserver { NotificationCenter.default.removeObserver(pagesObserver) }
    }

    // MARK: Styles

    func displayAttributes(for traits: Set<TextStyle>) -> [NSAttributedString.Key: Any] {
        var attributes = textAppearance?.noteAttributes(bold: traits.contains(.bold),
                                                        italic: traits.contains(.italic))
            ?? [.font: NSFont.systemFont(ofSize: 15), .foregroundColor: NSColor.textColor]
        attributes.merge(StyleTraits.attributes(for: traits)) { _, new in new }
        return attributes
    }

    /// Sets the display attributes of `range` from its traits, dropping
    /// every other attribute. Registers no undo.
    func restyle(_ range: NSRange) {
        guard let storage = textStorage, range.length > 0 else { return }
        var pieces: [(NSRange, Set<TextStyle>)] = []
        storage.enumerateAttributes(in: range) { attributes, piece, _ in
            pieces.append((piece, StyleTraits.traits(in: attributes)))
        }
        storage.beginEditing()
        for (piece, traits) in pieces {
            storage.setAttributes(displayAttributes(for: traits), range: piece)
        }
        storage.endEditing()
    }

    private var fullRange: NSRange {
        NSRange(location: 0, length: textStorage?.length ?? 0)
    }

    /// Shows `text` with the styles of `runs`, with no undo history.
    func load(text: String, runs: [StyleRun]) {
        textStorage?.setAttributedString(StyleTraits.attributed(text, runs: runs))
        renderedFamily = textAppearance?.family
        renderedSize = textAppearance?.size
        restyle(fullRange)
        typingAttributes = displayAttributes(for: [])
        links = showLinks()
        requestPages()
        placeCards()
    }

    /// Restyles every character after a font or size change, keeping the
    /// styles for new typing.
    func applyAppearance() {
        guard let appearance = textAppearance,
              appearance.family != renderedFamily || appearance.size != renderedSize else { return }
        renderedFamily = appearance.family
        renderedSize = appearance.size
        let typing = StyleTraits.traits(in: typingAttributes)
        restyle(fullRange)
        typingAttributes = displayAttributes(for: typing)
        links = showLinks()
        placeCards()
        needsDisplay = true
    }

    var runs: [StyleRun] {
        textStorage.map { StyleTraits.runs(of: $0) } ?? []
    }

    /// The styles of the whole selection, or with no selection those for
    /// new typing; none while the text view does not have keyboard focus.
    var activeStyles: Set<TextStyle> {
        guard window?.firstResponder === self, let storage = textStorage else { return [] }
        let ranges = selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
        if ranges.isEmpty {
            return StyleTraits.traits(in: typingAttributes)
        }
        var common = Set(TextStyle.allCases)
        for range in ranges {
            storage.enumerateAttributes(in: range) { attributes, _, stop in
                common.formIntersection(StyleTraits.traits(in: attributes))
                if common.isEmpty { stop.pointee = true }
            }
        }
        return common
    }

    func notifyStyles() {
        onStylesChange?(activeStyles)
    }

    /// Toggles `style` on the selection, or with no selection for new
    /// typing. A selection that has the style everywhere loses it;
    /// otherwise all of it gets it.
    func toggle(_ style: TextStyle) {
        if window?.firstResponder !== self {
            window?.makeFirstResponder(self)
        }
        let ranges = selectedRanges.map(\.rangeValue).filter { $0.length > 0 }
        guard let storage = textStorage, !ranges.isEmpty else {
            var traits = StyleTraits.traits(in: typingAttributes)
            traits.formSymmetricDifference([style])
            typingAttributes = displayAttributes(for: traits)
            notifyStyles()
            return
        }
        let remove = activeStyles.contains(style)
        guard shouldChangeText(inRanges: ranges.map { NSValue(range: $0) }, replacementStrings: nil) else { return }
        storage.beginEditing()
        for range in ranges {
            var pieces: [(NSRange, Set<TextStyle>)] = []
            storage.enumerateAttributes(in: range) { attributes, piece, _ in
                pieces.append((piece, StyleTraits.traits(in: attributes)))
            }
            for (piece, traits) in pieces {
                var traits = traits
                if remove { traits.remove(style) } else { traits.insert(style) }
                storage.setAttributes(displayAttributes(for: traits), range: piece)
            }
        }
        storage.endEditing()
        didChangeText()
        notifyStyles()
    }

    @objc func toggleNoteBold(_ sender: Any?) { toggle(.bold) }
    @objc func toggleNoteItalic(_ sender: Any?) { toggle(.italic) }
    @objc func toggleNoteUnderline(_ sender: Any?) { toggle(.underline) }

    override func validateUserInterfaceItem(_ item: NSValidatedUserInterfaceItem) -> Bool {
        let styles: [Selector: TextStyle] = [
            #selector(toggleNoteBold(_:)): .bold,
            #selector(toggleNoteItalic(_:)): .italic,
            #selector(toggleNoteUnderline(_:)): .underline,
        ]
        if let action = item.action, let style = styles[action] {
            (item as? NSMenuItem)?.state = activeStyles.contains(style) ? .on : .off
            return true
        }
        return super.validateUserInterfaceItem(item)
    }

    override func didChangeText() {
        // Undo and redo put back attributes rendered for the font
        // setting at that time; render them for the current one.
        if undoManager?.isUndoing == true || undoManager?.isRedoing == true {
            restyle(fullRange)
        }
        super.didChangeText()
        // Typing, paste, cut, undo, and redo all end here.
        links = showLinks()
        // Paragraphs moved; lay out every card paragraph's room again on
        // the next relayout.
        cardRooms = [:]
        updateTopRoom()
        placeCards()
        requestTimer?.invalidate()
        requestTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in
            self?.requestPages()
        }
        needsDisplay = true
    }

    // MARK: Link cards

    /// Leaves room above paragraphs for their cards and places the cards
    /// when pages arrive. Call once, before `load`.
    func setUpLinkCards() {
        textContentStorage?.delegate = self
        pagesObserver = NotificationCenter.default.addObserver(forName: LinkPageStore.didLoad, object: nil,
                                                               queue: .main) { [weak self] _ in
            self?.relayoutCards()
        }
    }

    /// Width of a card: the width of the text's lines. From the view's
    /// own width, which a resize sets at once; the text container follows
    /// it only on the next layout.
    private var cardWidth: CGFloat {
        let padding = textContainer?.lineFragmentPadding ?? 0
        return max(bounds.width - 2 * textContainerInset.width - 2 * padding, 0)
    }

    /// Each paragraph that has a web address, with its first one, in text
    /// order.
    private var linkParagraphs: [(range: NSRange, url: URL)] {
        let text = string as NSString
        var result: [(range: NSRange, url: URL)] = []
        for link in links {
            let paragraph = text.paragraphRange(for: NSRange(location: link.range.location, length: 0))
            if result.last?.range.location != paragraph.location {
                result.append((paragraph, link.url))
            }
        }
        return result
    }

    /// The card of the paragraph in `range`, once its page has arrived.
    private func card(inParagraph range: NSRange) -> (url: URL, page: LinkPage)? {
        let text = (string as NSString).substring(with: range)
        guard let url = LinkDetector.links(in: text).first?.url,
              let page = linkPages?.page(for: url) else { return nil }
        return (url, page)
    }

    private func requestPages() {
        for paragraph in linkParagraphs {
            linkPages?.request(paragraph.url)
        }
    }

    /// Lays out a paragraph that has a card with room for the card above
    /// it. Only what TextKit lays out changes; the text storage, and so
    /// the saved text, undo, and copy, never see the room.
    func textContentStorage(_ textContentStorage: NSTextContentStorage,
                            textParagraphWith range: NSRange) -> NSTextParagraph? {
        // The first paragraph's room is `topRoom`, not paragraph spacing.
        guard range.location > 0, range.length > 0, let storage = textStorage, NSMaxRange(range) <= storage.length,
              let card = card(inParagraph: range) else { return nil }
        let text = NSMutableAttributedString(attributedString: storage.attributedSubstring(from: range))
        let current = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        let style = (current ?? .default).mutableCopy() as! NSMutableParagraphStyle
        style.paragraphSpacingBefore = LinkCardLayout.height(for: card.page, width: cardWidth) + LinkCardLayout.gap
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        return NSTextParagraph(attributedString: text)
    }

    /// Asks TextKit for every paragraph again, so each gets the room its
    /// card needs now: after a page arrives or the width changes. Marks
    /// the text as edited without changing it, which registers no undo.
    private func relayoutCards() {
        updateTopRoom()
        guard textLayoutManager != nil, let storage = textStorage, storage.length > 0 else {
            placeCards()
            return
        }
        // The room each card paragraph needs now, by paragraph start.
        var rooms: [Int: CGFloat] = [:]
        for paragraph in linkParagraphs {
            if let page = linkPages?.page(for: paragraph.url) {
                rooms[paragraph.range.location] = LinkCardLayout.height(for: page, width: cardWidth)
            }
        }
        let changed = linkParagraphs.map(\.range).filter {
            rooms[$0.location] != cardRooms[$0.location]
        }
        cardRooms = rooms
        if !changed.isEmpty {
            // Inside a transaction, so TextKit 2 asks for the paragraphs
            // again at once instead of on some later event.
            let edit = {
                storage.beginEditing()
                for range in changed where NSMaxRange(range) <= storage.length {
                    storage.edited(.editedAttributes, range: range, changeInLength: 0)
                }
                storage.endEditing()
            }
            if let content = textContentStorage {
                content.performEditingTransaction(edit)
            } else {
                edit()
            }
        }
        // The cards are placed after the text view's own layout, which is
        // the layout that is drawn.
        needsLayout = true
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        placeCards()
    }

    /// The text starts below the first paragraph's card. Caret, selection,
    /// link clicks, the placeholder, and the cards all follow it.
    override var textContainerOrigin: NSPoint {
        let origin = super.textContainerOrigin
        return NSPoint(x: origin.x, y: origin.y + topRoom)
    }

    /// Sets `topRoom` from the first paragraph's card: the card's height
    /// and the gap under it, or 0 when that paragraph has no card yet.
    private func updateTopRoom() {
        var room: CGFloat = 0
        if let first = linkParagraphs.first, first.range.location == 0,
           let page = linkPages?.page(for: first.url) {
            room = LinkCardLayout.height(for: page, width: cardWidth) + LinkCardLayout.gap
        }
        guard room != topRoom else { return }
        topRoom = room
        invalidateTextContainerOrigin()
        sizeToFit()
        needsLayout = true
        needsDisplay = true
    }

    /// Puts a card in the room above each paragraph whose page has
    /// arrived, and removes cards whose paragraph lost its link.
    private func placeCards() {
        guard let layout = textLayoutManager else {
            cardHosts.forEach { $0.removeFromSuperview() }
            cardHosts = []
            return
        }
        let cards = linkParagraphs.compactMap { paragraph in
            linkPages?.page(for: paragraph.url).map { (paragraph.range, paragraph.url, $0) }
        }
        if !cards.isEmpty {
            layout.ensureLayout(for: layout.documentRange)
        }
        let width = cardWidth
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = textContainerOrigin
        var placed = 0
        for (range, url, page) in cards {
            guard let location = layout.location(layout.documentRange.location, offsetBy: range.location),
                  let fragment = layout.textLayoutFragment(for: location) else { continue }
            // The top of the paragraph's first line, below the room.
            let lineTop = fragment.textLineFragments.first?.typographicBounds.minY ?? 0
            let top = fragment.layoutFragmentFrame.minY + lineTop
            let height = LinkCardLayout.height(for: page, width: width)
            let frame = NSRect(x: origin.x + padding, y: origin.y + top - LinkCardLayout.gap - height,
                               width: width, height: height)
            let host: LinkCardHost
            if placed < cardHosts.count {
                host = cardHosts[placed]
                host.show(url: url, page: page)
            } else {
                host = LinkCardHost(url: url, page: page)
                addSubview(host)
                cardHosts.append(host)
            }
            host.frame = frame
            placed += 1
        }
        while cardHosts.count > placed {
            cardHosts.removeLast().removeFromSuperview()
        }
    }

    /// A new width wraps the text and the cards differently.
    override func setFrameSize(_ newSize: NSSize) {
        let widthChanged = newSize.width != frame.width
        // The text view sizes itself to its text, which leaves out
        // `topRoom`; grow by it so the last line is not cut off.
        var size = newSize
        if isVerticallyResizable, topRoom > 0, let layout = textLayoutManager {
            let needed = layout.usageBoundsForTextContainer.height + topRoom + 2 * textContainerInset.height
            size.height = max(size.height, needed)
        }
        super.setFrameSize(size)
        guard widthChanged, !cardLayoutPending else { return }
        cardLayoutPending = true
        DispatchQueue.main.async { [weak self] in
            self?.cardLayoutPending = false
            self?.relayoutCards()
        }
    }

    // MARK: Links

    func link(at point: NSPoint) -> (url: URL, rect: NSRect)? {
        link(in: links, at: point)
    }

    /// Cmd+click on a link opens it and leaves the caret alone.
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

    // MARK: Pasteboard

    override var writablePasteboardTypes: [NSPasteboard.PasteboardType] {
        super.writablePasteboardTypes + [Self.styledTextType]
    }

    /// Adds the selection's text and runs as a private type next to RTF
    /// and plain text, so a slanted italic copies exactly between notes.
    override func writeSelection(to pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        guard type == Self.styledTextType else { return super.writeSelection(to: pboard, type: type) }
        guard let storage = textStorage else { return false }
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let selection = storage.attributedSubstring(from: range)
        let payload = StyledText(text: selection.string, styles: StyleTraits.runs(of: selection))
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        return pboard.setData(data, forType: type)
    }

    override var readablePasteboardTypes: [NSPasteboard.PasteboardType] {
        [Self.styledTextType] + super.readablePasteboardTypes
    }

    /// Paste and drop keep only bold, italic, and underline; the text
    /// takes the note's font, size, and color. Plain text takes the
    /// styles for new typing.
    override func readSelection(from pboard: NSPasteboard, type: NSPasteboard.PasteboardType) -> Bool {
        let incoming: NSMutableAttributedString
        if let data = pboard.data(forType: Self.styledTextType),
           let payload = try? JSONDecoder().decode(StyledText.self, from: data) {
            incoming = StyleTraits.attributed(payload.text, runs: payload.styles)
        } else if let rich = Self.richText(from: pboard) {
            incoming = StyleTraits.sanitized(rich)
        } else if let plain = pboard.string(forType: .string) {
            let typing = StyleTraits.traits(in: typingAttributes)
            incoming = NSMutableAttributedString(string: plain, attributes: StyleTraits.attributes(for: typing))
        } else {
            return false
        }
        insertStyled(incoming)
        return true
    }

    private static func richText(from pboard: NSPasteboard) -> NSAttributedString? {
        if let data = pboard.data(forType: .rtfd), let text = NSAttributedString(rtfd: data, documentAttributes: nil) {
            return text
        }
        if let data = pboard.data(forType: .rtf), let text = NSAttributedString(rtf: data, documentAttributes: nil) {
            return text
        }
        if let data = pboard.data(forType: .html), let text = NSAttributedString(html: data, documentAttributes: nil) {
            return text
        }
        return nil
    }

    /// Replaces the selection with `text` as one undoable change.
    private func insertStyled(_ text: NSMutableAttributedString) {
        let range = rangeForUserTextChange
        guard range.location != NSNotFound, let storage = textStorage,
              shouldChangeText(in: range, replacementString: text.string) else { return }
        storage.replaceCharacters(in: range, with: text)
        restyle(NSRange(location: range.location, length: text.length))
        didChangeText()
        setSelectedRange(NSRange(location: range.location + text.length, length: 0))
    }

    // MARK: Behavior kept from the note's former text editor

    /// Esc ends editing and keeps the text.
    override func cancelOperation(_ sender: Any?) {
        window?.makeFirstResponder(nil)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.notifyStyles() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        DispatchQueue.main.async { [weak self] in self?.notifyStyles() }
        return resigned
    }

    /// The placeholder starts where the first typed character appears,
    /// at every font and size, since both use the text container's origin.
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard string.isEmpty else { return }
        let padding = textContainer?.lineFragmentPadding ?? 0
        let origin = NSPoint(x: textContainerOrigin.x + padding, y: textContainerOrigin.y)
        NSAttributedString(string: placeholder, attributes: displayAttributes(for: [])).draw(at: origin)
    }
}

/// Keeps a note's text view at least as tall as the visible area, so a
/// click below the last line still puts the caret in the note.
final class NoteScrollView: NSScrollView {
    override func tile() {
        super.tile()
        guard let textView = documentView as? NSTextView,
              textView.minSize.height != contentSize.height else { return }
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.sizeToFit()
    }
}
