import Foundation

/// A change on a linked list that GitHub has not seen yet.
public enum PendingChange: Equatable {
    case create(item: UUID, title: String)
    case rename(item: UUID, number: Int, title: String)
    case close(item: UUID, number: Int)
    case reopen(item: UUID, number: Int)

    public var itemID: UUID {
        switch self {
        case .create(let item, _), .rename(let item, _, _), .close(let item, _), .reopen(let item, _):
            return item
        }
    }
}

/// What GitHub says about an issue that left a list's shown set.
public enum IssueAnswer: Equatable {
    case closed(title: String)
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

    /// Changes waiting to be sent, in item order. The focused item is
    /// still being typed in, so it is not created or renamed yet.
    public static func pendingChanges(in items: [ListItem], focused: UUID?) -> [PendingChange] {
        var changes: [PendingChange] = []
        for item in items {
            guard let number = item.issueNumber else {
                let title = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if item.id != focused, !title.isEmpty {
                    changes.append(.create(item: item.id, title: title))
                }
                continue
            }
            if item.id != focused, let remoteTitle = item.remoteTitle,
               !item.text.isEmpty, item.text != remoteTitle {
                changes.append(.rename(item: item.id, number: number, title: item.text))
            }
            if let remoteClosed = item.remoteClosed, item.done != remoteClosed {
                changes.append(item.done ? .close(item: item.id, number: number)
                                         : .reopen(item: item.id, number: number))
            }
        }
        return changes
    }

    /// Whether a list shows `issue`: open issues and no pull requests,
    /// assigned to `login` or to no one.
    public static func isShown(_ issue: RemoteIssue, login: String) -> Bool {
        !issue.closed && !issue.isPullRequest && (issue.assignees.isEmpty || issue.assignees.contains(login))
    }

    /// `issue`, fetched on its own, as an answer for `resolve`.
    public static func answer(for issue: RemoteIssue, login: String) -> IssueAnswer {
        if issue.closed { return .closed(title: issue.title) }
        return isShown(issue, login: login) ? .shown : .hidden
    }

    /// Merges the open issues the list shows into its items.
    /// - An item with an issue in `shown` takes the issue's title, unless
    ///   it is focused or has a rename waiting. A checked item whose close
    ///   was already sent was reopened on GitHub: it is unchecked and moves
    ///   to the end of the unchecked items.
    /// - An issue with no item is added at the end of the unchecked items,
    ///   in ascending number.
    /// - Returns the numbers of unchecked items whose issue is not in
    ///   `shown`, to ask GitHub about.
    public static func merge(items: [ListItem], shown: [RemoteIssue],
                             focused: UUID?) -> (items: [ListItem], ask: [Int]) {
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
                         remoteTitle: issue.title, remoteClosed: false, issueAuthor: issue.author)
            }
        return (unchecked + reopened + added + checked, ask)
    }

    /// Applies GitHub's answers about issues that left the shown set.
    /// Closed: the item is checked and moves to the top of the checked
    /// items. Hidden or gone: the item is removed. No answer (the request
    /// failed): the item stays as it is.
    public static func resolve(items: [ListItem], answers: [Int: IssueAnswer]) -> [ListItem] {
        var result = items
        for (number, answer) in answers {
            guard let index = result.firstIndex(where: { $0.issueNumber == number }) else { continue }
            switch answer {
            case .closed(let title):
                var item = result.remove(at: index)
                item.done = true
                item.remoteClosed = true
                if item.text == item.remoteTitle { item.text = title }
                item.remoteTitle = title
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
    /// The item's text and checked state stay as the user left them.
    public static func applied(_ change: PendingChange, issue: RemoteIssue, in items: [ListItem]) -> [ListItem] {
        var result = items
        guard let index = result.firstIndex(where: { $0.id == change.itemID }) else { return result }
        result[index].issueNumber = issue.number
        result[index].remoteTitle = issue.title
        result[index].remoteClosed = issue.closed
        result[index].issueAuthor = issue.author
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
