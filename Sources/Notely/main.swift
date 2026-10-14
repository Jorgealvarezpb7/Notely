import NotelyCore
import NotelyGitHub
import NotelyLinks
import NotelyUI

// Composition root: builds the shared state once and hands it to the app.
// Top-level code runs on the main thread, where the app must run.
MainActor.assumeIsolated {
    let tokens = KeychainTokenStore()
    let github = GitHubClient(tokens: tokens)
    NotelyApp.run(
        store: NoteStore(repository: UserDefaultsNoteRepository(defaults: .standard)),
        appearance: TextAppearance(),
        account: GitHubAccount(tokens: tokens, service: github),
        service: github,
        linkPages: LinkPageStore()
    )
}
