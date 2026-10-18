import AppKit
import NotelyCore
import NotelyLinks
import SwiftUI

/// Hosts a note's `NoteTextView`. Loads the note's text and styles once;
/// after that the text view owns them and saves every change.
struct NoteEditor: NSViewRepresentable {
    let store: NoteStore
    let appearance: TextAppearance
    let linkPages: LinkPageStore
    /// Passed by value so SwiftUI updates the view when either changes.
    let family: FontFamily
    let size: Int
    let id: UUID
    let state: NoteEditorState

    func makeNSView(context: Context) -> NoteScrollView {
        let scrollView = NoteScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay

        let contentSize = scrollView.contentSize
        // TextKit 2, asked for explicitly: link cards need its content
        // storage and layout fragments.
        let textView = NoteTextView(usingTextLayoutManager: true)
        textView.frame = NSRect(origin: .zero, size: contentSize)
        textView.minSize = NSSize(width: 0, height: contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: contentSize.width,
                                                       height: .greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 6, height: 0)
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.allowsDocumentBackgroundColorChange = false
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.textAppearance = appearance
        textView.linkPages = linkPages
        textView.setUpLinkCards()
        let note = store.note(id)
        textView.load(text: note?.text ?? "", runs: note?.styles ?? [])
        textView.delegate = context.coordinator
        let state = self.state
        textView.onStylesChange = { styles in
            if state.active != styles { state.active = styles }
        }
        state.textView = textView

        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NoteScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NoteTextView else { return }
        textView.textAppearance = appearance
        textView.applyAppearance()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NoteEditor

        init(_ parent: NoteEditor) { self.parent = parent }

        /// Saves text and styles together on every change, style-only
        /// changes included.
        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NoteTextView else { return }
            parent.store.setText(textView.string, styles: textView.runs, for: parent.id)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            (notification.object as? NoteTextView)?.notifyStyles()
        }
    }
}
