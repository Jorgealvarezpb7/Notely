import Foundation
import NotelyCore
import NotelyGitHub
import NotelyKeychainTokenStore
import NotelyLinks
import NotelySQLite
import NotelyUI

// Composition root: builds the shared state once and hands it to the app.
// Top-level code runs on the main thread, where the app must run.
MainActor.assumeIsolated {
    let tokens = KeychainTokenStore()
    let github = GitHubClient(tokens: tokens)
    // Notes live in ~/.Notely/db/data.sqlite3. When it cannot be opened,
    // notes stay in UserDefaults for this launch so none is lost.
    let log = Log("app")
    log.info("starting, log level \(Log.minimumLevel)")
    let repository: any NoteRepository
    do {
        repository = try SQLiteNoteRepository(legacy: .standard)
        log.info("notes in \(NotesDatabase.defaultURL.path)")
    } catch {
        log.error("database unavailable, using UserDefaults for notes: \(error)")
        repository = UserDefaultsNoteRepository(defaults: .standard)
    }
    NotelyApp.run(
        store: NoteStore(repository: repository),
        appearance: TextAppearance(),
        account: GitHubAccount(tokens: tokens, service: github),
        service: github,
        linkPages: LinkPageStore()
    )
}
