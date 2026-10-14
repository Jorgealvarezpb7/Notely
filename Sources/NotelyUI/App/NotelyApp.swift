import AppKit
import NotelyCore
import NotelyLinks

/// Starts Notely with the state it shares across windows and runs it
/// until it quits.
public enum NotelyApp {
    @MainActor
    public static func run(store: NoteStore, appearance: TextAppearance, account: GitHubAccount,
                           service: any IssueService, linkPages: LinkPageStore) {
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)   // Dock icon and visible app menus
        // The application holds its delegate weakly.
        let delegate = AppDelegate(store: store, appearance: appearance, account: account,
                                   service: service, linkPages: linkPages)
        app.delegate = delegate
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
