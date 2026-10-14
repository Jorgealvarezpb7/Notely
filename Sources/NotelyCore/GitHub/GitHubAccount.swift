import Foundation
import Observation

/// Where the GitHub token is kept between launches. The app keeps it in
/// the Keychain; tests keep it in memory.
public protocol TokenStore {
    func read() -> String?
    /// Returns whether the token was saved.
    func save(_ token: String) -> Bool
    func delete()
}

/// How a connect attempt ended.
public enum ConnectResult: Equatable {
    case connected
    /// Blank, or GitHub did not accept the token.
    case rejected
    case offline
    /// GitHub accepted the token, but the Keychain did not save it.
    case saveFailed
    /// Any other GitHub failure.
    case failed
}

/// The GitHub account: connected while a token is saved. Windows observe
/// `isConnected` to show or hide their GitHub controls, and
/// `tokenRejected` to pause sync until the user connects again.
@Observable
public final class GitHubAccount {
    public private(set) var isConnected: Bool
    /// The token's login, once GitHub has told it this launch.
    public private(set) var login: String?
    /// GitHub stopped accepting the saved token.
    public private(set) var tokenRejected = false

    private let tokens: any TokenStore
    private let service: any IssueService

    public init(tokens: any TokenStore, service: any IssueService) {
        self.tokens = tokens
        self.service = service
        isConnected = tokens.read() != nil
    }

    /// Checks `token`, trimmed of whitespace, with GitHub and saves it only
    /// when GitHub accepts it.
    @MainActor
    public func connect(token: String) async -> ConnectResult {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .rejected }
        let login: String
        do {
            login = try await service.currentUser(token: trimmed)
        } catch IssueServiceError.unauthorized {
            return .rejected
        } catch IssueServiceError.offline {
            return .offline
        } catch {
            return .failed
        }
        guard tokens.save(trimmed) else { return .saveFailed }
        self.login = login
        isConnected = true
        tokenRejected = false
        return .connected
    }

    /// Asks GitHub for the saved token's login. A rejected token marks
    /// the account; any other failure leaves the login unknown for now.
    @MainActor
    public func loadLogin() async {
        guard let token = tokens.read() else { return }
        do {
            login = try await service.currentUser(token: token)
        } catch IssueServiceError.unauthorized {
            tokenRejected = true
        } catch {}
    }

    /// GitHub answered a request with 401.
    @MainActor
    public func markTokenRejected() {
        tokenRejected = true
    }

    /// Removes the token. Links on lists stay, for the next connect.
    public func disconnect() {
        tokens.delete()
        isConnected = false
        login = nil
        tokenRejected = false
    }
}
