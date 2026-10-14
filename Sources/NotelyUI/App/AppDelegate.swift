import AppKit
import NotelyCore
import NotelyLinks

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store: NoteStore
    private let appearance: TextAppearance
    private let notes: NoteWindowController
    private let settings: SettingsWindowController
    private let sync: SyncController
    private lazy var menu = MenuWindowController(
        store: store,
        appearance: appearance,
        onOpen: { [weak self] id in self?.notes.open(id) },
        onNewNote: { [weak self] in self?.addFromMenu(list: false) },
        onNewList: { [weak self] in self?.addFromMenu(list: true) }
    )

    @MainActor
    init(store: NoteStore, appearance: TextAppearance, account: GitHubAccount,
         service: any IssueService, linkPages: LinkPageStore) {
        self.store = store
        self.appearance = appearance
        sync = SyncController(store: store, account: account, service: service)
        notes = NoteWindowController(store: store, appearance: appearance, account: account,
                                     sync: sync, linkPages: linkPages)
        settings = SettingsWindowController(store: store, appearance: appearance, account: account, sync: sync)
        super.init()
        notes.openSettings = { [weak self] pane in self?.settings.show(pane: pane) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()
        LinkHoverController.shared.start()

        // Notes open after the menu, so they stack in front of it.
        menu.open()
        notes.openSavedWindows()
        MainActor.assumeIsolated { sync.start() }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferredScrollerStyleDidChange(_:)),
            name: NSScroller.preferredScrollerStyleDidChangeNotification,
            object: nil
        )
    }

    /// Every scroll view resets itself to the system scroller style when
    /// the "Show scroll bars" setting or the pointing device changes.
    /// Observers run in no fixed order, so apply overlay again on the next
    /// run loop turn, after that reset.
    @objc private func preferredScrollerStyleDidChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.notes.applyOverlayScrollers()
        }
    }

    /// Clicking the Dock icon restores a minimized menu and brings the menu
    /// and every open note window to the front.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        menu.bringToFront()
        notes.orderAllFront()
        return true
    }

    /// Opens Settings on its General pane: from the app menu (Cmd+,) and
    /// from every note and list window's gear button.
    @objc func openSettings(_ sender: Any?) {
        settings.show(pane: .general)
    }

    private func addFromMenu(list: Bool) {
        guard let window = menu.window else { return }
        notes.add(list: list, nextTo: window)
    }
}
