import AppKit
import NotelyCore
import NotelyLinks
import SwiftUI

private extension NSView {
    /// Depth-first search for the first view of type `T` in this view's
    /// hierarchy that matches `match`.
    func firstDescendant<T: NSView>(_ type: T.Type, where match: (T) -> Bool = { _ in true }) -> T? {
        if let view = self as? T, match(view) { return view }
        for subview in subviews {
            if let found = subview.firstDescendant(type, where: match) { return found }
        }
        return nil
    }

    /// The first `NSTextView`, used to focus a freshly created note's
    /// text editor.
    var firstTextView: NSTextView? {
        firstDescendant(NSTextView.self)
    }
}

/// Owns every note and list window: opens and closes them, saves their
/// frames, keeps their size limits, and gives list rows their field
/// editor.
final class NoteWindowController: NSObject, NSWindowDelegate {
    private let store: NoteStore
    private let appearance: TextAppearance
    private let account: GitHubAccount
    private let sync: SyncController
    private let linkPages: LinkPageStore
    /// Opens the Settings window on a pane: General for the gear button,
    /// Integrations for "Reconnect…".
    var openSettings: (SettingsPane) -> Void = { _ in }
    private var windows: [UUID: NoteWindow] = [:]
    /// One scroller-style observation per note window, keyed by window.
    private var scrollerObservations: [ObjectIdentifier: NSKeyValueObservation] = [:]
    /// One list-row field editor per list window, keyed by window.
    private var fieldEditors: [ObjectIdentifier: LinkFieldEditor] = [:]

    init(store: NoteStore, appearance: TextAppearance, account: GitHubAccount,
         sync: SyncController, linkPages: LinkPageStore) {
        self.store = store
        self.appearance = appearance
        self.account = account
        self.sync = sync
        self.linkPages = linkPages
        super.init()
    }

    /// Opens a window for every note that was open when the app last quit.
    func openSavedWindows() {
        for note in store.notes where note.isOpen != false {
            openWindow(for: note)
        }
    }

    /// Brings every open note window to the front.
    func orderAllFront() {
        for window in windows.values {
            window.orderFront(nil)
        }
    }

    /// Gives every open note window overlay scrollers again.
    func applyOverlayScrollers() {
        for window in windows.values {
            applyOverlayScroller(to: window)
        }
    }

    /// Gives the window's scroll view (a note's text editor, or a list's
    /// rows) overlay scrollers, which show only while the user scrolls,
    /// whatever the system scroll bar setting. SwiftUI builds the scroll
    /// view on a later run loop turn; when it is not there yet, try once
    /// more on the next turn.
    private func applyOverlayScroller(to window: NSWindow, retry: Bool = true) {
        guard let scrollView = window.contentView?.firstDescendant(NSScrollView.self) else {
            if retry {
                DispatchQueue.main.async { [weak self, weak window] in
                    guard let window else { return }
                    self?.applyOverlayScroller(to: window, retry: false)
                }
            }
            return
        }
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        // From macOS 14, views do not clip their subviews by default. A
        // list's rows are real NSViews inside the scroll view; keep them
        // inside its frame, clear of the top and bottom bars. (The title
        // bar safe area, the other cause, is turned off in `openWindow`.)
        if #available(macOS 14, *) {
            scrollView.clipsToBounds = true
            scrollView.contentView.clipsToBounds = true
        }

        // SwiftUI and AppKit set the style back to the system preference
        // after this; set overlay again whenever it changes.
        scrollerObservations[ObjectIdentifier(window)] = scrollView.observe(\.scrollerStyle) { scrollView, _ in
            guard scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
        }
    }

    @discardableResult
    private func openWindow(for note: Note) -> NoteWindow {
        let size = savedSize(note.size)
        let frame: NSRect
        if let restored = restoredFrame(saved: note.origin, size: size,
                                        screens: NSScreen.screens.map(\.visibleFrame)) {
            frame = restored
        } else {
            // Default position: 20 points from the top and right edges of
            // the main screen's visible area.
            let screen = NSScreen.main?.visibleFrame ?? NSRect(origin: .zero, size: size)
            let fitted = fit(size, into: screen)
            frame = NSRect(x: screen.maxX - fitted.width - 20,
                           y: screen.maxY - fitted.height - 20,
                           width: fitted.width, height: fitted.height)
        }

        let window = NoteWindow(
            contentRect: frame,
            styleMask: [.titled, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The dictionary owns the window; without this, `close()` would
        // release it a second time.
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        // Full screen and window tiling are for the menu only; a note is
        // never offered as a tile or moved into a full-screen Space.
        window.collectionBehavior.formUnion([.fullScreenNone, .fullScreenDisallowsTiling])

        let hostingView = NSHostingView(rootView: WindowContent(
            store: store,
            appearance: appearance,
            account: account,
            sync: sync,
            linkPages: linkPages,
            id: note.id,
            onClose: { [weak self] in self?.closeNote(note.id) },
            onDelete: { [weak self] in self?.confirmDelete(note.id) },
            onSettings: { [weak self] pane in self?.openSettings(pane) }
        ))
        // The window alone owns its size; SwiftUI's preferred size must
        // not pin it.
        hostingView.sizingOptions = []
        // The note draws its own bars, so the transparent title bar gives
        // SwiftUI no safe area. Otherwise a list's ScrollView takes the
        // title bar height as a content inset and scrolls its rows up over
        // the drag area.
        if #available(macOS 13.3, *) {
            hostingView.safeAreaRegions = []
        }
        window.contentView = hostingView
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        // The drag handle performs dragging explicitly; disable
        // background-drag so it doesn't fight the text editor's own
        // mouse handling elsewhere in the window.
        window.isMovableByWindowBackground = false
        // The link pointer and preview follow the pointer over text.
        window.acceptsMouseMovedEvents = true
        window.minSize = minimumNoteSize
        // `contentRect` may be adjusted for the title bar; set the frame
        // itself so the saved size is the frame size.
        window.setFrame(frame, display: false)

        // Set after positioning, so opening a window never saves a frame
        // the user did not choose.
        window.delegate = self
        windows[note.id] = window
        window.orderFrontRegardless()
        // The text view exists only after SwiftUI builds the hosting
        // view's hierarchy, on the next run loop turn.
        DispatchQueue.main.async { [weak self, weak window] in
            guard let window else { return }
            self?.applyOverlayScroller(to: window)
        }
        return window
    }

    private func noteID(of notification: Notification) -> UUID? {
        guard let window = notification.object as? NSWindow else { return nil }
        return windows.first(where: { $0.value === window })?.key
    }

    /// Save on every move, not at quit, so a crash or `kill` keeps the
    /// last position too.
    func windowDidMove(_ notification: Notification) {
        guard let id = noteID(of: notification), let window = windows[id] else { return }
        store.setOrigin(NSStringFromPoint(window.frame.origin), for: id)
    }

    /// Saves origin and size together: a resize from the left or bottom
    /// edge moves the origin without always posting `windowDidMove`.
    func windowDidResize(_ notification: Notification) {
        guard let id = noteID(of: notification), let window = windows[id] else { return }
        store.setFrame(origin: NSStringFromPoint(window.frame.origin),
                       size: NSStringFromSize(window.frame.size),
                       for: id)
    }

    /// A note window never grows larger than its screen's visible area,
    /// nor shrinks below `minimumNoteSize`. Not `sender.minSize`: AppKit
    /// ties it to `contentMinSize`, which the SwiftUI hosting view can
    /// lower to its own fitting size, so it does not hold on its own.
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        let minimum = minimumNoteSize
        guard let screen = sender.screen?.visibleFrame else {
            return NSSize(width: max(frameSize.width, minimum.width),
                          height: max(frameSize.height, minimum.height))
        }
        return NSSize(width: max(min(frameSize.width, screen.width), minimum.width),
                      height: max(min(frameSize.height, screen.height), minimum.height))
    }

    /// Opens a new, empty note or list next to the menu window (see
    /// `newNoteFrame`), and gives keyboard focus to the note's text or the
    /// list's title.
    func add(list: Bool, nextTo menuWindow: NSWindow) {
        let screen = menuWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let frame = newNoteFrame(menu: menuWindow.frame, screen: screen)

        let origin = NSStringFromPoint(frame.origin)
        let size = NSStringFromSize(frame.size)
        let note = list ? store.addList(origin: origin, size: size) : store.add(origin: origin, size: size)
        let window = openWindow(for: note)

        window.makeKeyAndOrderFront(nil)
        // The editors exist only after SwiftUI builds the hosting view's
        // hierarchy, which happens on the next run loop turn.
        DispatchQueue.main.async {
            let editor: NSView? = list
                ? window.contentView?.firstDescendant(ListTextField.self, where: \.isTitle)
                : window.contentView?.firstTextView
            if let editor {
                window.makeFirstResponder(editor)
            }
        }
    }

    /// Shows a note's window in front, opening it at its saved frame when
    /// it is closed. An open window is not moved, and never duplicated.
    func open(_ id: UUID) {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            return
        }
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        store.setOpen(true, for: id)
        openWindow(for: note).makeKeyAndOrderFront(nil)
    }

    /// Stops tracking a note's window and returns it, ready to close.
    /// Closing the window would otherwise report a move to the origin it
    /// closes at; dropping the delegate first means nothing is saved for
    /// a frame the user did not choose.
    private func detachWindow(_ id: UUID) -> NoteWindow? {
        guard let window = windows.removeValue(forKey: id) else { return nil }
        window.delegate = nil
        scrollerObservations.removeValue(forKey: ObjectIdentifier(window))
        fieldEditors.removeValue(forKey: ObjectIdentifier(window))
        return window
    }

    /// List rows edit in a `LinkFieldEditor`, one per window, so they show
    /// and open links while edited. Every other client gets AppKit's own.
    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        guard client is ListTextField else { return nil }
        let key = ObjectIdentifier(sender)
        if let editor = fieldEditors[key] { return editor }
        let editor = LinkFieldEditor(usingTextLayoutManager: false)
        editor.isFieldEditor = true
        // As AppKit's own field editor: plain text, with undo.
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        fieldEditors[key] = editor
        return editor
    }

    /// Closes a note's window and keeps the note, listed in the menu.
    private func closeNote(_ id: UUID) {
        guard let window = detachWindow(id) else { return }
        store.setOpen(false, for: id)
        window.close()
    }

    /// Asks before deleting, in a sheet on the note's window. "Cancel" is
    /// the default button, so Return and Esc never delete; only a click on
    /// "Delete" does.
    private func confirmDelete(_ id: UUID) {
        guard let window = windows[id], window.attachedSheet == nil,
              let note = store.note(id) else { return }
        let name = note.isList ? listTitle(note.title) : noteTitle(note.text)
        TintControls.closePanel()
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Delete “\(name)”?"
        alert.informativeText = "This \(note.isList ? "list" : "note") will be deleted. You can't undo this."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete").hasDestructiveAction = true
        alert.beginSheetModal(for: window) { [weak self] response in
            if response == .alertSecondButtonReturn {
                self?.removeNote(id)
            }
        }
    }

    /// Deletes a note and closes its window at once. The app keeps
    /// running with no notes; the menu then shows only "+ New".
    private func removeNote(_ id: UUID) {
        guard let window = detachWindow(id) else { return }
        store.remove(id)
        window.close()
    }
}
