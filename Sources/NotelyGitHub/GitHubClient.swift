import Foundation
import NotelyCore
import os

extension Logger {
    /// Every GitHub request and sync decision. Read it with
    /// `log stream --predicate 'subsystem == "com.alvarezjorge.Notely"' --level info`.
    public static let github = Logger(subsystem: "com.alvarezjorge.Notely", category: "github")
}

/// The GitHub REST API over `URLSession`, with the saved token.
///
/// Logging: one line per request with the method, the path with the
/// repository hidden as a private value, the status, the time taken, and
/// the remaining rate limit. The token, the headers, and the bodies are
/// never logged, and neither are issue descriptions.
public final class GitHubClient: IssueService {
    private static let api = "https://api.github.com"
    /// Pages followed at most for one list request.
    private static let maxPages = 5

    private let tokens: any TokenStore
    private let session: URLSession
    /// Last response per URL, for `If-None-Match`. GitHub does not count a
    /// 304 against the rate limit.
    private var etags: [URL: (etag: String, data: Data)] = [:]
    private let lock = NSLock()

    public init(tokens: any TokenStore) {
        self.tokens = tokens
        let configuration = URLSessionConfiguration.ephemeral
        // ETags are handled here; a URL cache would answer 304s itself.
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: configuration)
    }

    // MARK: IssueService

    public func currentUser(token: String) async throws -> String {
        let (data, _) = try await send("GET", Self.url("/user"), token: token)
        return try decode(UserJSON.self, data).login
    }

    public func repositories() async throws -> [String] {
        let url = Self.url("/user/repos", query: [
            "affiliation": "owner,collaborator,organization_member",
            "sort": "pushed",
            "per_page": "100",
        ])
        return try await pages(url, repo: nil, as: RepoNameJSON.self).map(\.full_name)
    }

    public func repository(_ repo: String) async throws -> RepoAccess {
        let (data, _) = try await send("GET", Self.url("/repos/\(repo)"), repo: repo)
        let json = try decode(RepoJSON.self, data)
        let permissions = json.permissions
        let canPush = permissions?.push == true || permissions?.maintain == true || permissions?.admin == true
        return RepoAccess(canTriage: canPush || permissions?.triage == true,
                          canPush: canPush,
                          hasIssues: json.has_issues)
    }

    public func openIssues(_ repo: String, assignee: String) async throws -> [RemoteIssue] {
        let url = Self.url("/repos/\(repo)/issues", query: [
            "state": "open",
            "assignee": assignee,
            "per_page": "100",
        ])
        return try await pages(url, repo: repo, as: IssueJSON.self).map(\.remote)
    }

    public func issue(_ repo: String, number: Int) async throws -> RemoteIssue {
        let (data, _) = try await send("GET", Self.url("/repos/\(repo)/issues/\(number)"), repo: repo)
        return try decode(IssueJSON.self, data).remote
    }

    public func create(_ repo: String, title: String, body description: String,
                       assignees: [String]) async throws -> RemoteIssue {
        var body: [String: Any] = ["title": title, "assignees": assignees]
        if !description.isEmpty { body["body"] = description }
        let (data, _) = try await send("POST", Self.url("/repos/\(repo)/issues"), repo: repo, body: body)
        return try decode(IssueJSON.self, data).remote
    }

    public func update(_ repo: String, number: Int, title: String?, body description: String?,
                       closed: Bool?) async throws -> RemoteIssue {
        var body: [String: Any] = [:]
        if let title { body["title"] = title }
        if let description { body["body"] = description }
        if let closed { body["state"] = closed ? "closed" : "open" }
        let (data, _) = try await send("PATCH", Self.url("/repos/\(repo)/issues/\(number)"), repo: repo, body: body)
        return try decode(IssueJSON.self, data).remote
    }

    // MARK: Requests

    private static func url(_ path: String, query: [String: String] = [:]) -> URL {
        // Paths are built from logins, numbers, and repository names that
        // `repositoryName` checked, so they need no escaping.
        var components = URLComponents(string: api + path)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        return components.url!
    }

    /// Every page of a list request, following `Link: rel="next"`.
    private func pages<Item: Decodable>(_ url: URL, repo: String?, as type: Item.Type) async throws -> [Item] {
        var items: [Item] = []
        var next: URL? = url
        var count = 0
        while let url = next, count < Self.maxPages {
            let (data, response) = try await send("GET", url, repo: repo)
            items += try decode([Item].self, data)
            next = Self.nextPage(response.value(forHTTPHeaderField: "Link"))
            count += 1
        }
        return items
    }

    /// The `rel="next"` URL of a `Link` header.
    static func nextPage(_ link: String?) -> URL? {
        guard let link else { return nil }
        for part in link.split(separator: ",") {
            let pieces = part.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard pieces.count >= 2, pieces.dropFirst().contains("rel=\"next\""),
                  pieces[0].hasPrefix("<"), pieces[0].hasSuffix(">") else { continue }
            return URL(string: String(pieces[0].dropFirst().dropLast()))
        }
        return nil
    }

    /// Sends one request with the saved token (or `token`), logs it, and
    /// maps failures to `IssueServiceError`. A GET with a cached ETag that
    /// GitHub answers with 304 returns the cached body.
    private func send(_ method: String, _ url: URL, repo: String? = nil, token: String? = nil,
                      body: [String: Any]? = nil) async throws -> (Data, HTTPURLResponse) {
        guard let token = token ?? tokens.read() else { throw IssueServiceError.unauthorized }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("Notely", forHTTPHeaderField: "User-Agent")
        let cached = method == "GET" ? cachedResponse(for: url) : nil
        if let cached {
            request.setValue(cached.etag, forHTTPHeaderField: "If-None-Match")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let path = Self.loggedPath(url, repo: repo)
        let start = ContinuousClock.now
        let data: Data
        let response: HTTPURLResponse
        do {
            let (received, urlResponse) = try await session.data(for: request)
            guard let http = urlResponse as? HTTPURLResponse else { throw IssueServiceError.offline }
            data = received
            response = http
        } catch let error as IssueServiceError {
            throw error
        } catch {
            Logger.github.error("\(method, privacy: .public) \(path, privacy: .public) [\(repo ?? "-", privacy: .private)] failed: \(error.localizedDescription, privacy: .public)")
            throw IssueServiceError.offline
        }
        let elapsed = start.duration(to: .now)
        let milliseconds = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
        let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining") ?? "?"
        let limit = response.value(forHTTPHeaderField: "X-RateLimit-Limit") ?? "?"
        let status = response.statusCode

        if (200..<300).contains(status) || status == 304 {
            Logger.github.info("\(method, privacy: .public) \(path, privacy: .public) [\(repo ?? "-", privacy: .private)] -> \(status) in \(milliseconds) ms (rate \(remaining, privacy: .public)/\(limit, privacy: .public))")
            if status == 304, let cached {
                return (cached.data, response)
            }
            if method == "GET", let etag = response.value(forHTTPHeaderField: "ETag") {
                storeResponse(etag: etag, data: data, for: url)
            }
            return (data, response)
        }

        let message = (try? JSONDecoder().decode(MessageJSON.self, from: data))?.message
        Logger.github.error("\(method, privacy: .public) \(path, privacy: .public) [\(repo ?? "-", privacy: .private)] -> \(status) in \(milliseconds) ms (rate \(remaining, privacy: .public)/\(limit, privacy: .public)): \(message ?? "no message", privacy: .public)")
        switch status {
        case 301: throw IssueServiceError.moved
        case 401: throw IssueServiceError.unauthorized
        case 403 where remaining == "0", 429: throw IssueServiceError.rateLimited
        case 403: throw IssueServiceError.forbidden(message)
        case 404: throw IssueServiceError.notFound
        case 410: throw IssueServiceError.gone
        case 422: throw IssueServiceError.invalid(message)
        default: throw IssueServiceError.server(status)
        }
    }

    /// The URL's path and query with the repository replaced by "<repo>",
    /// so the line can be public; the repository is logged as private.
    private static func loggedPath(_ url: URL, repo: String?) -> String {
        var path = url.path
        if let query = url.query { path += "?" + query }
        if let repo { path = path.replacingOccurrences(of: repo, with: "<repo>") }
        return path
    }

    private func cachedResponse(for url: URL) -> (etag: String, data: Data)? {
        lock.lock()
        defer { lock.unlock() }
        return etags[url]
    }

    private func storeResponse(etag: String, data: Data, for url: URL) {
        lock.lock()
        etags[url] = (etag, data)
        lock.unlock()
    }

    private func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            Logger.github.error("Unexpected response from GitHub: \(error.localizedDescription, privacy: .public)")
            throw IssueServiceError.server(200)
        }
    }
}

// MARK: JSON

private struct UserJSON: Decodable {
    let login: String
}

private struct MessageJSON: Decodable {
    let message: String
}

private struct RepoNameJSON: Decodable {
    let full_name: String
}

private struct RepoJSON: Decodable {
    struct Permissions: Decodable {
        let admin: Bool?
        let maintain: Bool?
        let push: Bool?
        let triage: Bool?
    }

    let has_issues: Bool
    let permissions: Permissions?
}

private struct IssueJSON: Decodable {
    struct PullRequest: Decodable {}

    let number: Int
    let title: String
    /// `null` when the issue has no description.
    let body: String?
    let state: String
    let user: UserJSON
    let assignees: [UserJSON]?
    let pull_request: PullRequest?

    var remote: RemoteIssue {
        RemoteIssue(number: number, title: title, body: body ?? "", closed: state == "closed", author: user.login,
                    assignees: (assignees ?? []).map(\.login), isPullRequest: pull_request != nil)
    }
}
