import Foundation

/// A change on a linked list that GitHub has not seen yet.
public enum PendingChange: Equatable {
    case create(item: UUID, title: String, body: String = "")
    case rename(item: UUID, number: Int, title: String)
    case editBody(item: UUID, number: Int, body: String)
    case close(item: UUID, number: Int)
    case reopen(item: UUID, number: Int)

    public var itemID: UUID {
        switch self {
        case .create(let item, _, _), .rename(let item, _, _), .editBody(let item, _, _),
             .close(let item, _), .reopen(let item, _):
            return item
        }
    }
}

/// What to do with a waiting description change, given the description
/// GitHub has now.
public enum BodyDecision: Equatable {
    /// GitHub still has the description last seen: send the change.
    case send
    /// GitHub already has the user's description: nothing to send.
    case alreadyThere
    /// Someone changed it on GitHub meanwhile: hold the change.
    case hold
}

/// What GitHub says about an issue that left a list's shown set.
public enum IssueAnswer: Equatable {
    /// `body` is `nil` when not known.
    case closed(title: String, body: String? = nil)
    /// Open and still one the list shows.
    case shown
    /// Open, but assigned only to others.
    case hidden
    /// Deleted or transferred.
    case gone
}

/// The rules that keep a linked list and its repository's issues in step.
/// Pure functions over items, so they are tested without a network; the
/// sync controller runs the requests between them.
///
/// Items stay in display order: unchecked items, then checked items,
/// most recently checked first.
public enum IssueSync {
    /// A linked list keeps at most this many checked items.
    public static let checkedLimit = 10

    /// A description as compared and sent: `nil` reads as empty, CRLF and
    /// lone CR line breaks become LF, and trailing whitespace goes, since
    /// GitHub may return a description with either.
    public static func normalizedBody(_ body: String?) -> String {
        var text = (body ?? "").replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        while let last = text.last, last.isWhitespace {
            text.removeLast()
        }
        return text
    }

    /// Changes waiting to be sent, in item order. The focused item is
    /// still being typed in, so it is not created or renamed yet; the item
    /// whose description is being edited is not created and its
    /// description not sent yet. A held description is not sent.
    public static func pendingChanges(in items: [ListItem], focused: UUID?,
                                      editingBody: UUID? = nil) -> [PendingChange] {
        var changes: [PendingChange] = []
        for item in items {
            guard let number = item.issueNumber else {
                let title = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if item.id != focused, item.id != editingBody, !title.isEmpty {
                    changes.append(.create(item: item.id, title: title, body: normalizedBody(item.body)))
                }
                continue
            }
            if item.id != focused, let remoteTitle = item.remoteTitle,
               !item.text.isEmpty, item.text != remoteTitle {
                changes.append(.rename(item: item.id, number: number, title: item.text))
            }
            if item.id != editingBody, hasWaitingBody(item) {
                changes.append(.editBody(item: item.id, number: number, body: normalizedBody(item.body)))
            }
            if let remoteClosed = item.remoteClosed, item.done != remoteClosed {
                changes.append(item.done ? .close(item: item.id, number: number)
                                         : .reopen(item: item.id, number: number))
            }
        }
        return changes
    }

    /// Whether the item's description differs from the one last seen on
    /// GitHub, with no conflict held. An item never seen on GitHub with a
    /// description has none waiting: the first merge seeds it.
    public static func hasWaitingBody(_ item: ListItem) -> Bool {
        guard item.issueNumber != nil, item.heldBody == nil, let remote = item.remoteBody else { return false }
        return normalizedBody(item.body) != normalizedBody(remote)
    }

    /// Items whose description change is held for a conflict.
    public static func heldCount(in items: [ListItem]) -> Int {
        items.filter { $0.heldBody != nil }.count
    }

    /// Decides a waiting description change from the description GitHub
    /// has now (design.md Decision 2).
    public static func bodyDecision(item: ListItem, github: String) -> BodyDecision {
        let github = normalizedBody(github)
        if github == normalizedBody(item.body) { return .alreadyThere }
        if github == normalizedBody(item.remoteBody) { return .send }
        return .hold
    }

    /// Records the description GitHub has for the item: as last seen
    /// when `held` is false, as a held conflict otherwise.
    public static func recordBody(_ github: String, held: Bool, item itemID: UUID,
                                  in items: [ListItem]) -> [ListItem] {
        var result = items
        guard let index = result.firstIndex(where: { $0.id == itemID }) else { return result }
        if held {
            result[index].heldBody = normalizedBody(github)
        } else {
            result[index].remoteBody = normalizedBody(github)
            result[index].heldBody = nil
        }
        return result
    }

    /// Takes GitHub's description `github` into `item`, keeping the
    /// user's waiting or held change (design.md Decision 4):
    /// - Being edited: only seeds `remoteBody`; the send step checks it.
    /// - Held: follows GitHub's latest, and ends the conflict when GitHub
    ///   now has the user's description.
    /// - Waiting: a description GitHub changed too becomes a conflict.
    ///   `remoteBody` must not move to GitHub's, or the change would
    ///   overwrite it unseen.
    /// - Otherwise: the item takes GitHub's description.
    static func mergeBody(_ github: String, into item: inout ListItem, editing: Bool) {
        let github = normalizedBody(github)
        let mine = normalizedBody(item.body)
        if editing {
            if item.remoteBody == nil { item.remoteBody = github }
        } else if item.heldBody != nil {
            if github == mine {
                item.remoteBody = github
                item.heldBody = nil
            } else {
                item.heldBody = github
            }
        } else if item.remoteBody == nil || mine == normalizedBody(item.remoteBody) {
            item.body = github
            item.remoteBody = github
        } else if github == mine {
            item.remoteBody = github
        } else if github != normalizedBody(item.remoteBody) {
            item.heldBody = github
        }
    }

    /// Whether a list shows `issue`: open issues and no pull requests,
    /// assigned to `login` or to no one.
    public static func isShown(_ issue: RemoteIssue, login: String) -> Bool {
        !issue.closed && !issue.isPullRequest && (issue.assignees.isEmpty || issue.assignees.contains(login))
    }

    /// `issue`, fetched on its own, as an answer for `resolve`.
    public static func answer(for issue: RemoteIssue, login: String) -> IssueAnswer {
        if issue.closed { return .closed(title: issue.title, body: issue.body) }
        return isShown(issue, login: login) ? .shown : .hidden
    }

    /// Merges the open issues the list shows into its items.
    /// - An item with an issue in `shown` takes the issue's title, unless
    ///   it is focused or has a rename waiting, and its description by the
    ///   rules of `mergeBody`. A checked item whose close
    ///   was already sent was reopened on GitHub: it is unchecked and moves
    ///   to the end of the unchecked items.
    /// - An issue with no item is added at the end of the unchecked items,
    ///   in ascending number.
    /// - Returns the numbers of unchecked items whose issue is not in
    ///   `shown`, to ask GitHub about.
    public static func merge(items: [ListItem], shown: [RemoteIssue], focused: UUID?,
                             editingBody: UUID? = nil) -> (items: [ListItem], ask: [Int]) {
        var byNumber: [Int: RemoteIssue] = [:]
        for issue in shown { byNumber[issue.number] = issue }

        var unchecked: [ListItem] = []
        var reopened: [ListItem] = []
        var checked: [ListItem] = []
        var ask: [Int] = []
        var known = Set<Int>()

        for var item in items {
            guard let number = item.issueNumber else {
                if item.done { checked.append(item) } else { unchecked.append(item) }
                continue
            }
            known.insert(number)
            guard let issue = byNumber[number] else {
                if item.done { checked.append(item) } else {
                    unchecked.append(item)
                    ask.append(number)
                }
                continue
            }
            // Seeds an item that has never been in step: no rename is sent.
            let waitingRename = item.remoteTitle != nil && item.text != item.remoteTitle
            if !waitingRename, item.id != focused {
                item.text = issue.title
            }
            item.remoteTitle = issue.title
            item.issueAuthor = issue.author
            mergeBody(issue.body, into: &item, editing: item.id == editingBody)
            let closeSent = item.remoteClosed == true
            item.remoteClosed = false
            if item.done, closeSent {
                item.done = false
                reopened.append(item)
            } else if item.done {
                checked.append(item)
            } else {
                unchecked.append(item)
            }
        }

        let added = shown
            .filter { !known.contains($0.number) }
            .sorted { $0.number < $1.number }
            .map { issue in
                ListItem(id: UUID(), text: issue.title, done: false, issueNumber: issue.number,
                         remoteTitle: issue.title, remoteClosed: false, issueAuthor: issue.author,
                         body: issue.body, remoteBody: issue.body)
            }
        return (unchecked + reopened + added + checked, ask)
    }

    /// Applies GitHub's answers about issues that left the shown set.
    /// Closed: the item is checked and moves to the top of the checked
    /// items. Hidden or gone: the item is removed. No answer (the request
    /// failed): the item stays as it is.
    public static func resolve(items: [ListItem], answers: [Int: IssueAnswer],
                               editingBody: UUID? = nil) -> [ListItem] {
        var result = items
        for (number, answer) in answers {
            guard let index = result.firstIndex(where: { $0.issueNumber == number }) else { continue }
            switch answer {
            case .closed(let title, let body):
                var item = result.remove(at: index)
                item.done = true
                item.remoteClosed = true
                if item.text == item.remoteTitle { item.text = title }
                item.remoteTitle = title
                if let body {
                    mergeBody(body, into: &item, editing: item.id == editingBody)
                }
                result.insert(item, at: result.filter { !$0.done }.count)
            case .hidden, .gone:
                result.remove(at: index)
            case .shown:
                break
            }
        }
        return result
    }

    /// Keeps the `keepingChecked` most recently checked items. A checked
    /// item whose close is still waiting stays, so the close is not lost.
    public static func prune(items: [ListItem], keepingChecked limit: Int = checkedLimit) -> [ListItem] {
        var kept = 0
        return items.filter { item in
            guard item.done else { return true }
            kept += 1
            let closeWaiting = item.issueNumber == nil || item.remoteClosed != true
            return kept <= limit || closeWaiting
        }
    }

    /// Updates the item behind `change` from the issue GitHub returned.
    /// The item's text, description, and checked state stay as the user
    /// left them. `remoteBody` moves only for a create or a description
    /// change: after a rename or close, GitHub's description may hold an
    /// edit made elsewhere that a waiting description change must not
    /// overwrite unseen.
    public static func applied(_ change: PendingChange, issue: RemoteIssue, in items: [ListItem]) -> [ListItem] {
        var result = items
        guard let index = result.firstIndex(where: { $0.id == change.itemID }) else { return result }
        result[index].issueNumber = issue.number
        result[index].remoteTitle = issue.title
        result[index].remoteClosed = issue.closed
        result[index].issueAuthor = issue.author
        switch change {
        case .create, .editBody:
            result[index].remoteBody = issue.body
            result[index].heldBody = nil
        case .rename, .close, .reopen:
            break
        }
        return result
    }

    /// Drops a change GitHub refused for good: a create removes its item;
    /// any other change puts the item back as GitHub last showed it.
    public static func drop(_ change: PendingChange, in items: [ListItem]) -> [ListItem] {
        var result = items
        guard let index = result.firstIndex(where: { $0.id == change.itemID }) else { return result }
        switch change {
        case .create:
            result.remove(at: index)
        case .rename:
            result[index].text = result[index].remoteTitle ?? result[index].text
        case .editBody:
            result[index].body = result[index].remoteBody
        case .close, .reopen:
            var item = result.remove(at: index)
            item.done = item.remoteClosed ?? item.done
            result.insert(item, at: result.filter { !$0.done }.count)
        }
        return result
    }

    /// Whether the user may check, uncheck, and rename `item`: always
    /// before it has an issue, and while the access is not known yet;
    /// otherwise with triage access, or on an issue they opened.
    public static func isEditable(item: ListItem, access: RepoAccess?, login: String?) -> Bool {
        guard item.issueNumber != nil, let access else { return true }
        return access.canTriage || (login != nil && item.issueAuthor == login)
    }
}
