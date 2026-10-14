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
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        // The controller keeps the window, so red only hides it.
        window.isReleasedWhenClosed = false
        window.title = "Settings"
        window.minSize = NSSize(width: 520, height: 320)
        window.contentView = NSHostingView(rootView: SettingsView(
            selection: selection,
            store: store,
            appearance: appearance,
            account: account,
            sync: sync
        ))
        window.center()
        // Restores the frame the user last left, once there is one.
        window.setFrameAutosaveName(Self.autosaveName)
        return window
    }
}

/// The Settings window's content: the sidebar and the selected pane.
struct SettingsView: View {
    let selection: SettingsSelection
    let store: NoteStore
    let appearance: TextAppearance
    let account: GitHubAccount
    let sync: SyncController

    /// A click on empty sidebar space clears a `List` selection; keep the
    /// current pane instead.
    private var pane: Binding<SettingsPane?> {
        Binding(
            get: { selection.pane },
            set: { if let pane = $0 { selection.pane = pane } }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            List(SettingsPane.allCases, selection: pane) { pane in
                Label(pane.title, systemImage: pane.symbolName)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .frame(width: 180)
            Divider()
            VStack(alignment: .leading, spacing: 0) {
                Text(selection.pane.title)
                    .font(.title2.bold())
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                switch selection.pane {
                case .general:
                    GeneralPane(appearance: appearance)
                case .integrations:
                    IntegrationsPane(store: store, account: account, sync: sync)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
