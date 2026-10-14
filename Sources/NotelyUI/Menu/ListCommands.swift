import AppKit
import SwiftUI

/// What the menu bar's GitHub menu does in one list window. The list view
/// and its bottom bar fill in the closures; `NoteWindow` answers the menu
/// items with them, so the items act on the key window and are disabled
/// for note windows, which have none.
@MainActor
final class ListCommands: ObservableObject {
    var canShowDescription: () -> Bool = { false }
    var showDescription: () -> Void = {}
    var canRefresh: () -> Bool = { false }
    var refresh: () -> Void = {}
    var canLink: () -> Bool = { false }
    /// Set by the bottom bar once its GitHub button exists.
    var link: (() -> Void)?
}

/// Hands a list window's commands to its `NoteWindow` once the view is in
/// the window.
struct ListCommandsInstaller: NSViewRepresentable {
    let commands: ListCommands

    final class InstallView: NSView {
        var commands: ListCommands?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            (window as? NoteWindow)?.listCommands = commands
        }
    }

    func makeNSView(context: Context) -> InstallView {
        let view = InstallView()
        view.commands = commands
        return view
    }

    func updateNSView(_ nsView: InstallView, context: Context) {
        nsView.commands = commands
        (nsView.window as? NoteWindow)?.listCommands = commands
    }
}
