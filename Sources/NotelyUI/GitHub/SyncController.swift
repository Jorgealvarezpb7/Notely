import Foundation
import NotelyCore
import NotelyGitHub
import os

/// Keeps every linked list in step with its repository's issues: a full
/// refresh at launch, after linking, every 10 minutes, and on the refresh
/// button; a push of waiting changes shortly after each change the user
/// makes. One sync runs per list at a time. The rules themselves are in
/// `IssueSync`; this runs the requests between them and logs each step.
@MainActor
@Observable
final class SyncController {
    static let refreshInterval: TimeInterval = 600
    private static let pushDelay: Duration = .milliseconds(500)

    /// One list's sync, for its bottom bar and GitHub menu.
    struct ListState {
        var isRunning = false
        /// Why the last sync stopped, or why GitHub refused a change. Shown
        /// in the GitHub menu until the next full refresh.
        var message: String?
    }

    private(set) var states: [UUID: ListState] = [:]
    /// What the user may do, per repository, from the last refresh.
    private(set) var access: [String: RepoAccess] = [:]
    /// The item each list is editing, so its text is not sent or replaced
    /// while the user types.
    private(set) var focused: [UUID: UUID] = [:]

    let service: any IssueService
    private let store: NoteStore
    private let account: GitHubAccount
    @ObservationIgnored private var timer: Timer?
    /// Syncs asked for while one runs: `true` for a full refresh.
    @ObservationIgnored private var queued: [UUID: Bool] = [:]
    @ObservationIgnored private var pushTasks: [UUID: Task<Void, Never>] = [:]

    init(store: NoteStore, account: GitHubAccount, service: any IssueService) {
        self.store = store
        self.account = account
        self.service = service
    }

    /// Learns the login, refreshes every linked list, and starts the timer.
    func start() {
        Task {
            if account.isConnected { await account.loadLogin() }
            refreshAll()
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAll() }
        }
    }

    func refreshAll() {
        for note in store.notes where note.isList && note.githubRepo != nil {
            refresh(note.id)
        }
    }

    /// A full refresh of one list.
    func refresh(_ id: UUID) {
        schedule(id, full: true)
    }

    /// The list's items changed: keeps the checked-item limit and sends
    /// the changes shortly, so a burst of changes goes out together.
    func itemsChanged(_ id: UUID) {
        guard let items = store.note(id)?.items, store.note(id)?.githubRepo != nil else { return }
        store.setItems(IssueSync.prune(items: items), for: id)
        pushTasks[id]?.cancel()
        pushTasks[id] = Task { [weak self] in
            try? await Task.sleep(for: Self.pushDelay)
            guard !Task.isCancelled else { return }
            self?.schedule(id, full: false)
        }
    }

    func setFocused(_ item: UUID?, in id: UUID) {
        focused[id] = item
    }

    /// Changes the list has that GitHub has not seen yet.
    func pendingCount(_ id: UUID) -> Int {
        guard let note = store.note(id), note.githubRepo != nil else { return 0 }
        return IssueSync.pendingChanges(in: note.items ?? [], focused: focused[id]).count
    }

    func isEditable(_ item: ListItem, in id: UUID) -> Bool {
        guard let repo = store.note(id)?.githubRepo else { return true }
        return IssueSync.isEditable(item: item, access: access[repo], login: account.login)
    }

    private func schedule(_ id: UUID, full: Bool) {
        guard account.isConnected, !account.tokenRejected,
              store.note(id)?.githubRepo != nil else { return }
        if states[id]?.isRunning == true {
            queued[id] = (queued[id] ?? false) || full
            return
        }
        states[id, default: ListState()].isRunning = true
        Task {
            await run(id, full: full)
            states[id]?.isRunning = false
            if let full = queued.removeValue(forKey: id) {
                schedule(id, full: full)
            }
        }
    }

    // MARK: Sync

    private func items(_ id: UUID) -> [ListItem] {
        store.note(id)?.items ?? []
    }

    /// Runs one sync. Between requests the user may have edited the list
    /// or unlinked it, so each step reads the items again and stops when
    /// the link changed.
    private func run(_ id: UUID, full: Bool) async {
        guard let repo = store.note(id)?.githubRepo else { return }
        if account.login == nil { await account.loadLogin() }
        guard let login = account.login else {
            states[id]?.message = account.tokenRejected ? nil : IssueServiceError.offline.reason
            return
        }
        if full { states[id]?.message = nil }
        do {
            let access = try await service.repository(repo)
            self.access[repo] = access
            try await push(id, repo: repo, login: login, access: access)
            guard full else { return }
            try await fetch(id, repo: repo, login: login)
        } catch let error as IssueServiceError {
            fail(error, list: id, repo: repo)
        } catch {
            fail(.offline, list: id, repo: repo)
        }
    }

    /// Sends every waiting change. A change GitHub refuses for good is
    /// dropped; any other failure stops here and is tried again later.
    private func push(_ id: UUID, repo: String, login: String, access: RepoAccess) async throws {
        let changes = IssueSync.pendingChanges(in: items(id), focused: focused[id])
        if !changes.isEmpty {
            Logger.github.info("Sending \(changes.count) changes to \(repo, privacy: .private)")
        }
        for change in changes {
            guard store.note(id)?.githubRepo == repo else { return }
            do {
                let issue: RemoteIssue
                switch change {
                case .create(_, let title):
                    issue = try await service.create(repo, title: title, assignees: access.canPush ? [login] : [])
                    Logger.github.info("Created #\(issue.number) \(title, privacy: .private)")
                case .rename(_, let number, let title):
                    issue = try await service.update(repo, number: number, title: title, closed: nil)
                    Logger.github.info("Renamed #\(number) to \(title, privacy: .private)")
                case .close(_, let number):
                    issue = try await service.update(repo, number: number, title: nil, closed: true)
                    Logger.github.info("Closed #\(number)")
                case .reopen(_, let number):
                    issue = try await service.update(repo, number: number, title: nil, closed: false)
                    Logger.github.info("Reopened #\(number)")
                }
                guard store.note(id)?.githubRepo == repo else { return }
                store.setItems(IssueSync.applied(change, issue: issue, in: items(id)), for: id)
            } catch let error as IssueServiceError where error.isPermanent {
                Logger.github.error("Dropped a change GitHub refused: \(error.reason, privacy: .public)")
                store.setItems(IssueSync.drop(change, in: items(id)), for: id)
                states[id]?.message = "A change was not sent: \(error.reason)"
            }
        }
    }

    /// Fetches the issues the list shows and merges them in, then asks
    /// about the items whose issue left that set.
    private func fetch(_ id: UUID, repo: String, login: String) async throws {
        async let mine = service.openIssues(repo, assignee: login)
        async let unassigned = service.openIssues(repo, assignee: "none")
        var shown: [Int: RemoteIssue] = [:]
        for issue in try await mine + unassigned where IssueSync.isShown(issue, login: login) {
            shown[issue.number] = issue
        }
        guard store.note(id)?.githubRepo == repo else { return }

        let before = Set(items(id).compactMap(\.issueNumber))
        let merged = IssueSync.merge(items: items(id), shown: Array(shown.values), focused: focused[id])
        store.setItems(merged.items, for: id)
        let added = shown.keys.filter { !before.contains($0) }.sorted()
        if !added.isEmpty {
            let numbers = added.map { "#\($0)" }.joined(separator: " ")
            Logger.github.info("Added \(added.count) issues to the list: \(numbers, privacy: .public)")
        }

        var answers: [Int: IssueAnswer] = [:]
        for number in merged.ask {
            do {
                answers[number] = IssueSync.answer(for: try await service.issue(repo, number: number), login: login)
            } catch IssueServiceError.notFound, IssueServiceError.gone, IssueServiceError.moved {
                answers[number] = .gone
            }
        }
        guard store.note(id)?.githubRepo == repo else { return }
        for (number, answer) in answers.sorted(by: { $0.key < $1.key }) {
            switch answer {
            case .closed: Logger.github.info("#\(number) was closed on GitHub: checked")
            case .hidden: Logger.github.info("#\(number) is assigned to others only: removed")
            case .gone: Logger.github.info("#\(number) was deleted or moved: removed")
            case .shown: break
            }
        }
        let resolved = IssueSync.resolve(items: items(id), answers: answers)
        store.setItems(IssueSync.prune(items: resolved), for: id)
    }

    private func fail(_ error: IssueServiceError, list id: UUID, repo: String) {
        Logger.github.error("Sync of \(repo, privacy: .private) stopped: \(error.reason, privacy: .public)")
        if error == .unauthorized {
            account.markTokenRejected()
            return
        }
        states[id]?.message = error.reason
    }
}
