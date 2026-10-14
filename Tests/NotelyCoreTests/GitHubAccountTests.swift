import Foundation
import NotelyCore
import Testing

/// Keeps the token in memory, as the Keychain would between launches.
final class InMemoryTokenStore: TokenStore {
    var token: String?
    var failsToSave = false

    init(_ token: String? = nil) {
        self.token = token
    }

    func read() -> String? {
        token
    }

    func save(_ token: String) -> Bool {
        guard !failsToSave else { return false }
        self.token = token
        return true
    }

    func delete() {
        token = nil
    }
}

/// An account over `tokens`, with GitHub accepting "ghp_abc" as "jorge".
private func makeAccount(_ tokens: InMemoryTokenStore, failure: IssueServiceError = .unauthorized)
    -> (GitHubAccount, FakeIssueService) {
    let service = FakeIssueService()
    service.logins = ["ghp_abc": "jorge"]
    service.failure = failure
    return (GitHubAccount(tokens: tokens, service: service), service)
}

@MainActor
struct GitHubAccountTests {
    @Test func savedTokenMeansConnected() {
        #expect(makeAccount(InMemoryTokenStore("ghp_abc")).0.isConnected)
        #expect(!makeAccount(InMemoryTokenStore()).0.isConnected)
    }

    @Test func connectSavesTrimmedTokenAndLogin() async {
        let tokens = InMemoryTokenStore()
        let (account, _) = makeAccount(tokens)
        #expect(await account.connect(token: "  ghp_abc\n") == .connected)
        #expect(account.isConnected)
        #expect(account.login == "jorge")
        #expect(tokens.token == "ghp_abc")
    }

    @Test func blankTokenIsNotSaved() async {
        let tokens = InMemoryTokenStore()
        let (account, _) = makeAccount(tokens)
        #expect(await account.connect(token: "   ") == .rejected)
        #expect(!account.isConnected)
        #expect(tokens.token == nil)
    }

    @Test func rejectedTokenIsNotSaved() async {
        let tokens = InMemoryTokenStore()
        let (account, _) = makeAccount(tokens)
        #expect(await account.connect(token: "ghp_revoked") == .rejected)
        #expect(!account.isConnected)
        #expect(tokens.token == nil)
    }

    @Test func offlineSavesNothing() async {
        let tokens = InMemoryTokenStore()
        let (account, _) = makeAccount(tokens, failure: .offline)
        #expect(await account.connect(token: "ghp_new") == .offline)
        #expect(tokens.token == nil)
    }

    @Test func failedSaveStaysDisconnected() async {
        let tokens = InMemoryTokenStore()
        tokens.failsToSave = true
        let (account, _) = makeAccount(tokens)
        #expect(await account.connect(token: "ghp_abc") == .saveFailed)
        #expect(!account.isConnected)
    }

    @Test func loadLoginAtLaunch() async {
        let (account, _) = makeAccount(InMemoryTokenStore("ghp_abc"))
        #expect(account.login == nil)
        await account.loadLogin()
        #expect(account.login == "jorge")
    }

    @Test func revokedTokenAtLaunchIsMarked() async {
        let (account, _) = makeAccount(InMemoryTokenStore("ghp_revoked"))
        await account.loadLogin()
        #expect(account.tokenRejected)
        #expect(account.isConnected)
    }

    @Test func connectClearsRejection() async {
        let (account, _) = makeAccount(InMemoryTokenStore("ghp_revoked"))
        account.markTokenRejected()
        #expect(await account.connect(token: "ghp_abc") == .connected)
        #expect(!account.tokenRejected)
    }

    @Test func disconnectRemovesToken() {
        let tokens = InMemoryTokenStore("ghp_abc")
        let (account, _) = makeAccount(tokens)
        account.disconnect()
        #expect(!account.isConnected)
        #expect(account.login == nil)
        #expect(tokens.token == nil)
    }
}
