import AppKit
import SwiftUI

/// A note's window: a titled, resizable window whose title bar is
/// transparent and hidden, so the note keeps its own look while getting
/// native resizing, corners, and shadow.
final class NoteWindow: NSWindow {
    /// Set by a list window's view. `nil` for note windows, so the GitHub
    /// menu's items are disabled there.
    weak var listCommands: ListCommands?

    @objc func showIssueDescription(_ sender: Any?) {
        guard listCommands?.canShowDescription() == true else { return }
        listCommands?.showDescription()
    }

    @objc func refreshIssues(_ sender: Any?) {
        guard listCommands?.canRefresh() == true else { return }
        listCommands?.refresh()
    }

    @objc func linkToRepository(_ sender: Any?) {
        guard listCommands?.canLink() == true else { return }
        listCommands?.link?()
    }

    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        switch menuItem.action {
        case #selector(showIssueDescription(_:)):
            return listCommands?.canShowDescription() == true
        case #selector(refreshIssues(_:)):
            return listCommands?.canRefresh() == true
        case #selector(linkToRepository(_:)):
            return listCommands?.canLink() == true && listCommands?.link != nil
        default:
            return super.validateMenuItem(menuItem)
        }
    }

    /// Esc sends `cancelOperation(_:)` up the responder chain from a
    /// focused NSTextView. Resign first responder to end editing while
    /// keeping the note text.
    override func cancelOperation(_ sender: Any?) {
        makeFirstResponder(nil)
    }
}

/// A click target that ends editing, as Esc does, and with `drags` then
/// drags the window. TextEditor consumes mouseDown itself (for text
/// selection), so dragging by the window background alone cannot work
/// once the note fills the window; the bars give an explicit, visible
/// drag target instead.
struct EndEditingView: NSViewRepresentable {
    let drags: Bool

    final class ClickView: NSView {
        var drags = true

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(nil)
            if drags {
                window?.performDrag(with: event)
            }
        }
    }

    func makeNSView(context: Context) -> ClickView {
        ClickView()
    }

    func updateNSView(_ nsView: ClickView, context: Context) {
        nsView.drags = drags
    }
}
