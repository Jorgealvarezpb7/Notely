import AppKit
import NotelyCore
import SwiftUI

/// The panes of the Settings window, in sidebar order.
enum SettingsPane: CaseIterable, Identifiable {
    case general, integrations

    var id: Self { self }

    var title: String {
        switch self {
        case .general: return "General"
        case .integrations: return "Integrations"
        }
    }

    var symbolName: String {
        switch self {
        case .general: return "gearshape"
        case .integrations: return "puzzlepiece.extension"
        }
    }
}

/// The pane the Settings window shows. A class, so the controller can
/// select General each time it opens the window.
@Observable
final class SettingsSelection {
    var pane = SettingsPane.general
}

/// Owns the one Settings window. Red closes it and keeps the app running;
/// opening it again reuses the same window.
final class SettingsWindowController: NSObject {
    private static let autosaveName = "NotelySettings"
    private static let defaultSize = NSSize(width: 620, height: 420)

    private let store: NoteStore
    private let appearance: TextAppearance
    private let account: GitHubAccount
    private let sync: SyncController
    private let selection = SettingsSelection()
    private var window: NSWindow?

    init(store: NoteStore, appearance: TextAppearance, account: GitHubAccount, sync: SyncController) {
        self.store = store
        self.appearance = appearance
        self.account = account
        self.sync = sync
        super.init()
    }

    /// Shows the Settings window on `pane`, in front and key.
    func show(pane: SettingsPane) {
        selection.pane = pane
        let window = self.window ?? makeWindow()
        self.window = window
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.defaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        // The controller keeps the window, so red only hides it.
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.toolbarStyle = .unified
        let content = NSHostingController(rootView: SettingsView(
            selection: selection,
            store: store,
            appearance: appearance,
            account: account,
            sync: sync
        ))
        // SwiftUI fills the title bar: the pane's name as the window title,
        // and the sidebar toggle in the toolbar.
        content.sceneBridgingOptions = [.title, .toolbars]
        // Only SwiftUI's minimum size reaches the window. Switching panes
        // must not resize or move it.
        content.sizingOptions = [.minSize]
        window.contentViewController = content
        window.setContentSize(Self.defaultSize)
        window.center()
        // Restores the frame the user last left, once there is one.
        window.setFrameAutosaveName(Self.autosaveName)
        Self.growToMinimum(window)
        return window
    }

    /// A frame saved before the minimum size held can be smaller than it.
    private static func growToMinimum(_ window: NSWindow) {
        window.contentView?.layoutSubtreeIfNeeded()
        let size = window.contentRect(forFrameRect: window.frame).size
        let minimum = window.contentMinSize
        guard size.width < minimum.width || size.height < minimum.height else { return }
        window.setContentSize(NSSize(width: max(size.width, minimum.width),
                                     height: max(size.height, minimum.height)))
    }
}

/// The Settings window's content: the sidebar and the selected pane.
struct SettingsView: View {
    let selection: SettingsSelection
    let store: NoteStore
    let appearance: TextAppearance
    let account: GitHubAccount
    let sync: SyncController

    /// The narrowest pane that still fits every row on one line. General's
    /// "Text size" row (label, A, 160-point slider, A, value) and
    /// Integrations' "Account" row with "Connected as @login", "Reconnect…",
    /// and "Disconnect" set it. Measure again when a pane grows.
    private static let paneMinWidth: CGFloat = 420
    private static let paneMinHeight: CGFloat = 320

    /// A click on empty sidebar space clears a `List` selection; keep the
    /// current pane instead.
    private var pane: Binding<SettingsPane?> {
        Binding(
            get: { selection.pane },
            set: { if let pane = $0 { selection.pane = pane } }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: pane) { pane in
                Label(pane.title, systemImage: pane.symbolName)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            Group {
                switch selection.pane {
                case .general:
                    GeneralPane(appearance: appearance)
                case .integrations:
                    IntegrationsPane(store: store, account: account, sync: sync)
                }
            }
            .frame(minWidth: Self.paneMinWidth, maxWidth: .infinity,
                   minHeight: Self.paneMinHeight, maxHeight: .infinity,
                   alignment: .topLeading)
            .navigationTitle(selection.pane.title)
        }
    }
}
