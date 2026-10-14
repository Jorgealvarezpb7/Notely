import Foundation
import NotelyCore

/// Answers GitHub requests from memory. A request whose answer is not set
/// throws `failure`.
final class FakeIssueService: IssueService {
    var logins: [String: String] = [:]
    var failure: IssueServiceError = .offline
    var repos: [String] = []
    var access: [String: RepoAccess] = [:]
    var issues: [Int: RemoteIssue] = [:]
    private(set) var created: [(title: String, body: String, assignees: [String])] = []
    private(set) var updates: [(number: Int, title: String?, body: String?, closed: Bool?)] = []

    func currentUser(token: String) async throws -> String {
        guard let login = logins[token] else { throw failure }
        return login
    }

    func repositories() async throws -> [String] {
        repos
    }

    func repository(_ repo: String) async throws -> RepoAccess {
        guard let access = access[repo] else { throw failure }
        return access
    }

    func openIssues(_ repo: String, assignee: String) async throws -> [RemoteIssue] {
        issues.values.filter { issue in
            !issue.closed && (assignee == "none" ? issue.assignees.isEmpty : issue.assignees.contains(assignee))
        }
    }

    func issue(_ repo: String, number: Int) async throws -> RemoteIssue {
        guard let issue = issues[number] else { throw failure }
        return issue
    }

    func create(_ repo: String, title: String, body: String, assignees: [String]) async throws -> RemoteIssue {
        created.append((title, body, assignees))
        let issue = RemoteIssue(number: (issues.keys.max() ?? 0) + 1, title: title, body: body, author: "me",
                                assignees: assignees)
        issues[issue.number] = issue
        return issue
    }

    func update(_ repo: String, number: Int, title: String?, body: String?, closed: Bool?) async throws -> RemoteIssue {
        guard var issue = issues[number] else { throw failure }
        updates.append((number, title, body, closed))
        if let title { issue.title = title }
        if let body { issue.body = IssueSync.normalizedBody(body) }
        if let closed { issue.closed = closed }
        issues[number] = issue
        return issue
    }
}
