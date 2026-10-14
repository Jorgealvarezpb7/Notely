import AppKit
import SwiftUI

/// Main menu the menu bar shows while the app is active. It gives every
/// note working edit shortcuts, Cmd+, for Settings, and Cmd+Q.
func makeMainMenu() -> NSMenu {
    let appMenu = NSMenu()
    // No target: the action goes up the responder chain to the app
    // delegate, from any key window.
    appMenu.addItem(withTitle: "Settings…",
                    action: #selector(AppDelegate.openSettings(_:)),
                    keyEquivalent: ",")
    appMenu.addItem(.separator())
    appMenu.addItem(withTitle: "Quit Notely",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q")

    // Actions with no target go to the first responder: the key window's
    // note text view.
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redo.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    editMenu.addItem(.separator())
    // Enabled only while a list item is edited (see `ListTextField`).
    editMenu.addItem(withTitle: "Check Item",
                     action: #selector(ListTextField.toggleChecklistItem(_:)),
                     keyEquivalent: "\r")

    // Only a note's text view responds to these, so they are disabled
    // unless a note has keyboard focus, and do nothing in lists.
    let formatMenu = NSMenu(title: "Format")
    formatMenu.addItem(withTitle: "Bold", action: #selector(NoteTextView.toggleNoteBold(_:)), keyEquivalent: "b")
    formatMenu.addItem(withTitle: "Italic", action: #selector(NoteTextView.toggleNoteItalic(_:)), keyEquivalent: "i")
    formatMenu.addItem(withTitle: "Underline", action: #selector(NoteTextView.toggleNoteUnderline(_:)), keyEquivalent: "u")

    // No target: the key window answers these, a list window's
    // `NoteWindow` only. Elsewhere they are disabled.
    let gitHubMenu = NSMenu(title: "GitHub")
    gitHubMenu.addItem(withTitle: "Description", action: #selector(NoteWindow.showIssueDescription(_:)),
                       keyEquivalent: "d")
    gitHubMenu.addItem(withTitle: "Refresh Issues", action: #selector(NoteWindow.refreshIssues(_:)),
                       keyEquivalent: "r")
    gitHubMenu.addItem(withTitle: "Link to Repository…", action: #selector(NoteWindow.linkToRepository(_:)),
                       keyEquivalent: "l")

    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    let editItem = NSMenuItem()
    editItem.submenu = editMenu
    let formatItem = NSMenuItem()
    formatItem.submenu = formatMenu
    let gitHubItem = NSMenuItem()
    gitHubItem.submenu = gitHubMenu

    let mainMenu = NSMenu()
    mainMenu.addItem(appItem)
    mainMenu.addItem(editItem)
    mainMenu.addItem(formatItem)
    mainMenu.addItem(gitHubItem)
    return mainMenu
}
