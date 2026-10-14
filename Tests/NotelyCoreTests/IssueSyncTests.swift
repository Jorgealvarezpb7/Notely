import Foundation
import NotelyCore
import Testing

/// An item in step with issue `number`.
private func synced(_ number: Int, _ title: String, done: Bool = false, author: String = "me") -> ListItem {
    ListItem(id: UUID(), text: title, done: done, issueNumber: number,
             remoteTitle: title, remoteClosed: done, issueAuthor: author)
}

private func issue(_ number: Int, _ title: String, assignees: [String] = [], author: String = "me") -> RemoteIssue {
    RemoteIssue(number: number, title: title, author: author, assignees: assignees)
}

struct PendingChangeTests {
    @Test func itemsInStepHaveNoChanges() {
        #expect(IssueSync.pendingChanges(in: [synced(1, "a"), synced(2, "b", done: true)], focused: nil).isEmpty)
    }

    @Test func newItemIsCreated() {
        let item = ListItem(id: UUID(), text: " fix login ", done: false)
        #expect(IssueSync.pendingChanges(in: [item], focused: nil) == [.create(item: item.id, title: "fix login")])
    }

    @Test func emptyNewItemIsNotCreated() {
        let item = ListItem(id: UUID(), text: "  ", done: false)
        #expect(IssueSync.pendingChanges(in: [item], focused: nil).isEmpty)
    }

    @Test func changedTextIsRenamed() {
        var item = synced(4, "fix login")
        item.text = "fix login on Safari"
        #expect(IssueSync.pendingChanges(in: [item], focused: nil)
                == [.rename(item: item.id, number: 4, title: "fix login on Safari")])
    }

    @Test func emptiedTextIsNotRenamed() {
        var item = synced(4, "fix login")
        item.text = ""
        #expect(IssueSync.pendingChanges(in: [item], focused: nil).isEmpty)
    }

    @Test func checkedItemIsClosedAndUncheckedReopened() {
        var checked = synced(4, "a")
        checked.done = true
        var unchecked = synced(5, "b", done: true)
        unchecked.done = false
        #expect(IssueSync.pendingChanges(in: [checked, unchecked], focused: nil)
                == [.close(item: checked.id, number: 4), .reopen(item: unchecked.id, number: 5)])
    }

    @Test func focusedItemIsNotCreatedOrRenamedButStillClosed() {
        let new = ListItem(id: UUID(), text: "fix", done: false)
        var renamed = synced(4, "a")
        renamed.text = "ab"
        renamed.done = true
        #expect(IssueSync.pendingChanges(in: [new], focused: new.id).isEmpty)
        #expect(IssueSync.pendingChanges(in: [renamed], focused: renamed.id) == [.close(item: renamed.id, number: 4)])
    }

    @Test func itemNeverInStepIsNotRenamed() {
        let item = ListItem(id: UUID(), text: "fix login", done: false, issueNumber: 4)
        #expect(IssueSync.pendingChanges(in: [item], focused: nil).isEmpty)
    }
}

struct ShownTests {
    @Test func showsAssignedToMeOrNoOne() {
        #expect(IssueSync.isShown(issue(1, "a", assignees: ["me"]), login: "me"))
        #expect(IssueSync.isShown(issue(2, "b"), login: "me"))
        #expect(IssueSync.isShown(issue(3, "c", assignees: ["me", "ana"]), login: "me"))
        #expect(!IssueSync.isShown(issue(4, "d", assignees: ["ana"]), login: "me"))
    }

    @Test func hidesPullRequestsAndClosedIssues() {
        var pull = issue(5, "pr")
        pull.isPullRequest = true
        var closed = issue(6, "done")
        closed.closed = true
        #expect(!IssueSync.isShown(pull, login: "me"))
        #expect(!IssueSync.isShown(closed, login: "me"))
    }

    @Test func answers() {
        var closed = issue(1, "a")
        closed.closed = true
        #expect(IssueSync.answer(for: closed, login: "me") == .closed(title: "a"))
        #expect(IssueSync.answer(for: issue(2, "b"), login: "me") == .shown)
        #expect(IssueSync.answer(for: issue(3, "c", assignees: ["ana"]), login: "me") == .hidden)
    }
}

struct MergeTests {
    @Test func newIssuesAreAppendedAfterUncheckedItems() {
        let a = synced(1, "a")
        let old = synced(9, "old", done: true)
        let result = IssueSync.merge(items: [a, old], shown: [issue(1, "a"), issue(3, "c"), issue(2, "b")], focused: nil)
        #expect(result.items.map(\.text) == ["a", "b", "c", "old"])
        #expect(result.items[1].issueNumber == 2)
        #expect(result.items[1].remoteClosed == false)
        #expect(result.ask.isEmpty)
    }

    @Test func titleChangedOnGitHubUpdatesItem() {
        let result = IssueSync.merge(items: [synced(1, "a")], shown: [issue(1, "a2")], focused: nil)
        #expect(result.items[0].text == "a2")
        #expect(result.items[0].remoteTitle == "a2")
    }

    @Test func focusedItemKeepsItsText() {
        let item = synced(1, "a")
        let result = IssueSync.merge(items: [item], shown: [issue(1, "a2")], focused: item.id)
        #expect(result.items[0].text == "a")
        #expect(result.items[0].remoteTitle == "a2")
    }

    @Test func waitingRenameKeepsItsText() {
        var item = synced(1, "a")
        item.text = "mine"
        let result = IssueSync.merge(items: [item], shown: [issue(1, "theirs")], focused: nil)
        #expect(result.items[0].text == "mine")
        #expect(IssueSync.pendingChanges(in: result.items, focused: nil)
                == [.rename(item: item.id, number: 1, title: "mine")])
    }

    @Test func reopenedOnGitHubUnchecksItem() {
        let a = synced(1, "a")
        let b = synced(2, "b", done: true)
        let result = IssueSync.merge(items: [a, b], shown: [issue(1, "a"), issue(2, "b")], focused: nil)
        #expect(result.items.map(\.text) == ["a", "b"])
        #expect(result.items[1].done == false)
        #expect(result.items[1].remoteClosed == false)
    }

    @Test func waitingCloseStaysChecked() {
        var item = synced(1, "a")
        item.done = true
        let result = IssueSync.merge(items: [item], shown: [issue(1, "a")], focused: nil)
        #expect(result.items[0].done)
        #expect(IssueSync.pendingChanges(in: result.items, focused: nil) == [.close(item: item.id, number: 1)])
    }

    @Test func missingUncheckedItemsAreAskedAbout() {
        let result = IssueSync.merge(items: [synced(1, "a"), synced(2, "b"), synced(3, "c", done: true)],
                                     shown: [issue(2, "b")], focused: nil)
        #expect(result.ask == [1])
        #expect(result.items.count == 3)
    }

    @Test func itemNeverInStepIsSeededWithoutRename() {
        let item = ListItem(id: UUID(), text: "old title", done: false, issueNumber: 1)
        let result = IssueSync.merge(items: [item], shown: [issue(1, "new title")], focused: nil)
        #expect(result.items[0].text == "new title")
        #expect(IssueSync.pendingChanges(in: result.items, focused: nil).isEmpty)
    }

    @Test func itemsWithoutIssueStay() {
        let new = ListItem(id: UUID(), text: "fix", done: false)
        let result = IssueSync.merge(items: [new], shown: [issue(1, "a")], focused: nil)
        #expect(result.items.map(\.text) == ["fix", "a"])
    }
}

struct ResolveTests {
    @Test func closedMovesToTopOfCheckedItems() {
        let items = [synced(1, "a"), synced(2, "b"), synced(3, "c", done: true)]
        let result = IssueSync.resolve(items: items, answers: [1: .closed(title: "a")])
        #expect(result.map(\.text) == ["b", "a", "c"])
        #expect(result[1].done && result[1].remoteClosed == true)
    }

    @Test func goneAndHiddenAreRemoved() {
        let items = [synced(1, "a"), synced(2, "b"), synced(3, "c")]
        let result = IssueSync.resolve(items: items, answers: [1: .gone, 2: .hidden, 3: .shown])
        #expect(result.map(\.text) == ["c"])
    }
}

struct PruneTests {
    @Test func eleventhCheckedItemDropsOldest() {
        let checked = (1...11).map { synced($0, "c\($0)", done: true) }
        let result = IssueSync.prune(items: [synced(20, "open")] + checked)
        #expect(result.map(\.text) == ["open"] + (1...10).map { "c\($0)" })
    }

    @Test func waitingCloseIsKept() {
        var waiting = synced(11, "c11")
        waiting.done = true
        let checked = (1...10).map { synced($0, "c\($0)", done: true) } + [waiting]
        #expect(IssueSync.prune(items: checked).count == 11)
    }
}

struct ChangeResultTests {
    @Test func appliedSetsIssueFields() {
        let item = ListItem(id: UUID(), text: "fix", done: false)
        let created = RemoteIssue(number: 7, title: "fix", author: "me")
        let result = IssueSync.applied(.create(item: item.id, title: "fix"), issue: created, in: [item])
        #expect(result[0].issueNumber == 7)
        #expect(result[0].remoteTitle == "fix")
        #expect(result[0].remoteClosed == false)
        #expect(result[0].issueAuthor == "me")
    }

    @Test func droppedCreateRemovesItem() {
        let item = ListItem(id: UUID(), text: "fix", done: false)
        #expect(IssueSync.drop(.create(item: item.id, title: "fix"), in: [item]).isEmpty)
    }

    @Test func droppedRenameResetsText() {
        var item = synced(4, "fix login")
        item.text = "other"
        let result = IssueSync.drop(.rename(item: item.id, number: 4, title: "other"), in: [item])
        #expect(result[0].text == "fix login")
    }

    @Test func droppedCloseUnchecks() {
        var item = synced(4, "a")
        item.done = true
        let result = IssueSync.drop(.close(item: item.id, number: 4), in: [synced(5, "b", done: true), item])
        #expect(result.map(\.text) == ["a", "b"])
        #expect(result[0].done == false)
    }
}

struct EditableTests {
    private let access = RepoAccess(canTriage: false, canPush: false)

    @Test func triageCanEditAnyIssue() {
        #expect(IssueSync.isEditable(item: synced(1, "a", author: "ana"),
                                     access: RepoAccess(canTriage: true, canPush: false), login: "me"))
    }

    @Test func readAccessCanEditOwnIssuesOnly() {
        #expect(IssueSync.isEditable(item: synced(1, "a", author: "me"), access: access, login: "me"))
        #expect(!IssueSync.isEditable(item: synced(2, "b", author: "ana"), access: access, login: "me"))
    }

    @Test func newItemAndUnknownAccessAreEditable() {
        #expect(IssueSync.isEditable(item: ListItem(id: UUID(), text: "x", done: false), access: access, login: "me"))
        #expect(IssueSync.isEditable(item: synced(2, "b", author: "ana"), access: nil, login: "me"))
    }
}
