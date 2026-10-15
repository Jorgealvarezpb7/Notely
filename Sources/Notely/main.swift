import Foundation
import NotelyCore
import NotelyGitHub
import NotelyLinks
import NotelyUI

// Composition root: builds the shared state once and hands it to the app.
// Top-level code runs on the main thread, where the app must run.
MainActor.assumeIsolated {
    let tokens = KeychainTokenStore()
    let github = GitHubClient(tokens: tokens)
    // Notes live in ~/.Notely/db/data.sqlite3. When it cannot be opened,
    // notes stay in UserDefaults for this launch so none is lost.
    let repository: any NoteRepository
    do {
        repository = try NotesRepository(legacy: .standard)
    } catch {
        FileHandle.standardError.write(Data("Notely: using UserDefaults for notes: \(error)\n".utf8))
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
