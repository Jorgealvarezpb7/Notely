import Foundation

/// A GitHub issue as the API returns it, reduced to what lists use.
public struct RemoteIssue: Equatable {
    public var number: Int
    public var title: String
    public var closed: Bool
    /// Login of the user who opened the issue.
    public var author: String
    /// Logins of the assignees.
    public var assignees: [String]
    public var isPullRequest: Bool

    public init(number: Int, title: String, closed: Bool = false, author: String,
                assignees: [String] = [], isPullRequest: Bool = false) {
        self.number = number
        self.title = title
        self.closed = closed
        self.author = author
        self.assignees = assignees
        self.isPullRequest = isPullRequest
    }
}

/// What the user may do in a repository.
public struct RepoAccess: Equatable {
    /// Triage access or more: close, reopen, and rename any issue.
    public var canTriage: Bool
    /// Push access or more: also assign issues.
    public var canPush: Bool
    public var hasIssues: Bool

    public init(canTriage: Bool, canPush: Bool, hasIssues: Bool = true) {
        self.canTriage = canTriage
        self.canPush = canPush
        self.hasIssues = hasIssues
    }
}

/// Why a GitHub request failed.
public enum IssueServiceError: Error, Equatable {
    /// 401: the token is missing, revoked, or expired.
    case unauthorized
    /// 403, with GitHub's message.
    case forbidden(String?)
    /// 403 with no requests left until the rate limit resets.
    case rateLimited
    case notFound
    case gone
    /// 301: the issue or repository was transferred.
    case moved
    /// 422, with GitHub's message.
    case invalid(String?)
    /// 5xx.
    case server(Int)
    /// GitHub could not be reached.
    case offline

    /// GitHub refused the request for good; sending it again cannot help.
    public var isPermanent: Bool {
        switch self {
        case .forbidden, .notFound, .gone, .moved, .invalid: return true
        case .unauthorized, .rateLimited, .server, .offline: return false
        }
    }

    /// A short reason for the GitHub menu.
    public var reason: String {
        switch self {
        case .unauthorized: return "GitHub token no longer works"
        case .forbidden(let message): return message.map { "Not allowed: \($0)" } ?? "Not allowed"
        case .rateLimited: return "GitHub's request limit is reached"
        case .notFound: return "Not found, or this token can't reach it"
        case .gone: return "Deleted on GitHub"
        case .moved: return "Moved to another repository"
        case .invalid(let message): return message.map { "Not accepted: \($0)" } ?? "Not accepted"
        case .server(let status): return "GitHub had a problem (\(status))"
        case .offline: return "GitHub can't be reached"
        }
    }
}

/// The GitHub requests issue sync makes. Every request but
/// `currentUser(token:)` uses the saved token.
public protocol IssueService: AnyObject {
    /// The login the token belongs to.
    func currentUser(token: String) async throws -> String
    /// Repositories the token reaches, as "owner/repo", most recently
    /// pushed first.
    func repositories() async throws -> [String]
    func repository(_ repo: String) async throws -> RepoAccess
    /// Open issues and pull requests assigned to `assignee`, a login or
    /// "none".
    func openIssues(_ repo: String, assignee: String) async throws -> [RemoteIssue]
    func issue(_ repo: String, number: Int) async throws -> RemoteIssue
    func create(_ repo: String, title: String, assignees: [String]) async throws -> RemoteIssue
    /// Changes the title, the state, or both; `nil` leaves it as it is.
    func update(_ repo: String, number: Int, title: String?, closed: Bool?) async throws -> RemoteIssue
}
