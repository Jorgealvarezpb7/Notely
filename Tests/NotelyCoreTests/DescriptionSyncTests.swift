import Foundation
import NotelyCore
import Testing

/// An item in step with issue `number`, its description `body` included.
private func synced(_ number: Int, _ title: String, body: String = "") -> ListItem {
    ListItem(id: UUID(), text: title, done: false, issueNumber: number, remoteTitle: title,
             remoteClosed: false, issueAuthor: "me", body: body, remoteBody: body)
}

private func issue(_ number: Int, _ title: String, body: String = "") -> RemoteIssue {
    RemoteIssue(number: number, title: title, body: body, author: "me")
}

struct NormalizedBodyTests {
    @Test func nilIsEmpty() {
        #expect(IssueSync.normalizedBody(nil) == "")
    }

    @Test func crlfAndLoneCRBecomeLF() {
        #expect(IssueSync.normalizedBody("a\r\nb\rc") == "a\nb\nc")
    }

    @Test func trailingWhitespaceGoes() {
        #expect(IssueSync.normalizedBody("a\n\n  ") == "a")
        #expect(IssueSync.normalizedBody("  a") == "  a")
    }

    @Test func remoteIssueBodyIsNormalized() {
        #expect(issue(1, "a", body: "x\r\ny\r\n").body == "x\ny")
    }
}

struct BodyChangeTests {
    @Test func changedBodyIsAChange() {
        var item = synced(4, "a", body: "old")
        item.body = "new"
        #expect(IssueSync.pendingChanges(in: [item], focused: nil)
                == [.editBody(item: item.id, number: 4, body: "new")])
    }

    @Test func lineBreaksOnlyAreNotAChange() {
        var item = synced(4, "a", body: "x\ny")
        item.body = "x\r\ny\n"
        #expect(IssueSync.pendingChanges(in: [item], focused: nil).isEmpty)
    }

    @Test func heldAndEditedBodiesAreNotSent() {
        var held = synced(4, "a", body: "old")
        held.body = "mine"
        held.heldBody = "theirs"
        var editing = synced(5, "b", body: "old")
        editing.body = "typing"
        #expect(IssueSync.pendingChanges(in: [held, editing], focused: nil, editingBody: editing.id).isEmpty)
    }

    @Test func unseededBodyIsNotAChange() {
        let item = ListItem(id: UUID(), text: "a", done: false, issueNumber: 4, remoteTitle: "a",
                            remoteClosed: false, body: "local")
        #expect(IssueSync.pendingChanges(in: [item], focused: nil).isEmpty)
    }

    @Test func createSendsTheBody() {
        let item = ListItem(id: UUID(), text: "fix login", done: false, body: "Only on Safari\r\n")
        #expect(IssueSync.pendingChanges(in: [item], focused: nil)
                == [.create(item: item.id, title: "fix login", body: "Only on Safari")])
    }

    @Test func createWaitsWhileItsBodyIsEdited() {
        let item = ListItem(id: UUID(), text: "fix login", done: false, body: "Only")
        #expect(IssueSync.pendingChanges(in: [item], focused: nil, editingBody: item.id).isEmpty)
    }

    @Test func droppedBodyChangeResets() {
        var item = synced(4, "a", body: "old")
        item.body = "new"
        let result = IssueSync.drop(.editBody(item: item.id, number: 4, body: "new"), in: [item])
        #expect(result[0].body == "old")
    }
}

struct BodyDecisionTests {
    /// Stored, so every use is the same item, with the same id.
    private let item: ListItem = {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        return item
    }()

    @Test func unchangedOnGitHubIsSent() {
        #expect(IssueSync.bodyDecision(item: item, github: "old\r\n") == .send)
    }

    @Test func alreadyOnGitHubIsNotSent() {
        #expect(IssueSync.bodyDecision(item: item, github: "mine") == .alreadyThere)
    }

    @Test func changedOnGitHubIsHeld() {
        #expect(IssueSync.bodyDecision(item: item, github: "theirs") == .hold)
    }

    @Test func recordHeldAndSeen() {
        let held = IssueSync.recordBody("theirs", held: true, item: item.id, in: [item])
        #expect(held[0].heldBody == "theirs")
        #expect(held[0].remoteBody == "old")
        #expect(IssueSync.heldCount(in: held) == 1)
        let seen = IssueSync.recordBody("mine", held: false, item: item.id, in: held)
        #expect(seen[0].remoteBody == "mine")
        #expect(seen[0].heldBody == nil)
    }

    @Test func appliedBodyChangeMovesRemoteBody() {
        let result = IssueSync.applied(.editBody(item: item.id, number: 4, body: "mine"),
                                       issue: issue(4, "a", body: "mine"), in: [item])
        #expect(result[0].remoteBody == "mine")
        #expect(result[0].body == "mine")
    }

    @Test func appliedCloseKeepsRemoteBody() {
        var closing = item
        closing.done = true
        let result = IssueSync.applied(.close(item: closing.id, number: 4),
                                       issue: issue(4, "a", body: "theirs"), in: [closing])
        #expect(result[0].remoteBody == "old")
    }
}

struct BodyMergeTests {
    @Test func idleItemTakesGitHubsBody() {
        let item = synced(4, "a", body: "old")
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "new")], focused: nil).items
        #expect(merged[0].body == "new")
        #expect(merged[0].remoteBody == "new")
    }

    @Test func waitingChangeUnchangedOnGitHubStaysWaiting() {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "old")], focused: nil).items
        #expect(merged[0].body == "mine")
        #expect(merged[0].remoteBody == "old")
        #expect(merged[0].heldBody == nil)
    }

    @Test func waitingChangeChangedOnGitHubIsHeld() {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "theirs")], focused: nil).items
        #expect(merged[0].body == "mine")
        #expect(merged[0].remoteBody == "old")
        #expect(merged[0].heldBody == "theirs")
    }

    @Test func editedBodyIsNotReplaced() {
        var item = synced(4, "a", body: "old")
        item.body = "typing"
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "theirs")],
                                     focused: nil, editingBody: item.id).items
        #expect(merged[0].body == "typing")
        #expect(merged[0].remoteBody == "old")
        #expect(merged[0].heldBody == nil)
    }

    @Test func heldBodyFollowsGitHub() {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        item.heldBody = "theirs"
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "theirs again")], focused: nil).items
        #expect(merged[0].heldBody == "theirs again")
        #expect(merged[0].body == "mine")
    }

    @Test func heldBodyEqualToMineEndsTheConflict() {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        item.heldBody = "theirs"
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "mine\r\n")], focused: nil).items
        #expect(merged[0].heldBody == nil)
        #expect(merged[0].remoteBody == "mine")
        #expect(IssueSync.pendingChanges(in: merged, focused: nil).isEmpty)
    }

    @Test func missingRemoteBodyIsSeededWithoutAChange() {
        let item = ListItem(id: UUID(), text: "a", done: false, issueNumber: 4, remoteTitle: "a",
                            remoteClosed: false, issueAuthor: "me")
        let merged = IssueSync.merge(items: [item], shown: [issue(4, "a", body: "desc")], focused: nil).items
        #expect(merged[0].body == "desc")
        #expect(merged[0].remoteBody == "desc")
        #expect(IssueSync.pendingChanges(in: merged, focused: nil).isEmpty)
    }

    @Test func addedIssueBringsItsBody() {
        let merged = IssueSync.merge(items: [], shown: [issue(7, "new", body: "desc")], focused: nil).items
        #expect(merged[0].body == "desc")
        #expect(merged[0].remoteBody == "desc")
    }

    @Test func closedAnswerTakesTheBody() {
        let item = synced(4, "a", body: "old")
        let result = IssueSync.resolve(items: [item], answers: [4: .closed(title: "a", body: "new")])
        #expect(result[0].done)
        #expect(result[0].body == "new")
    }
}

struct ConflictResolutionTests {
    private func storeWithHeld() -> (NoteStore, UUID, UUID) {
        var item = synced(4, "a", body: "old")
        item.body = "mine"
        item.heldBody = "theirs"
        let id = UUID()
        let list = Note(id: id, text: "", kind: Note.listKind, title: "", items: [item], githubRepo: "acme/web")
        return (NoteStore(repository: InMemoryNoteRepository([list])), id, item.id)
    }

    @Test func keepMineLeavesAWaitingChange() {
        let (store, id, itemID) = storeWithHeld()
        store.resolveConflict(item: itemID, for: id, keepMine: true)
        let items = store.note(id)?.items ?? []
        #expect(items[0].body == "mine")
        #expect(items[0].heldBody == nil)
        #expect(IssueSync.pendingChanges(in: items, focused: nil)
                == [.editBody(item: itemID, number: 4, body: "mine")])
        // Sent only while GitHub still has the description it had.
        #expect(IssueSync.bodyDecision(item: items[0], github: "theirs") == .send)
    }

    @Test func useGitHubsLeavesNothing() {
        let (store, id, itemID) = storeWithHeld()
        store.resolveConflict(item: itemID, for: id, keepMine: false)
        let items = store.note(id)?.items ?? []
        #expect(items[0].body == "theirs")
        #expect(items[0].heldBody == nil)
        #expect(IssueSync.pendingChanges(in: items, focused: nil).isEmpty)
    }

    @Test func setItemBodySaves() {
        let (store, id, itemID) = storeWithHeld()
        store.setItemBody("", item: itemID, for: id)
        #expect(store.note(id)?.items?[0].body == "")
    }
}

struct SyncStatusTests {
    private let start = Date(timeIntervalSince1970: 1_000)

    @Test func checkFadesAfterAMinute() {
        #expect(SyncStatus.visible(result: .ok, at: start, now: start.addingTimeInterval(59), waiting: 0))
        #expect(!SyncStatus.visible(result: .ok, at: start, now: start.addingTimeInterval(60), waiting: 0))
    }

    @Test func xStaysWhileWaiting() {
        #expect(SyncStatus.visible(result: .failed("offline"), at: start,
                                   now: start.addingTimeInterval(3_600), waiting: 1))
    }

    @Test func xWithNothingWaitingFades() {
        #expect(SyncStatus.visible(result: .failed("x"), at: start, now: start.addingTimeInterval(30), waiting: 0))
        #expect(!SyncStatus.visible(result: .failed("x"), at: start, now: start.addingTimeInterval(61), waiting: 0))
    }

    @Test func noResultShowsNothing() {
        #expect(!SyncStatus.visible(result: nil, at: nil, now: start, waiting: 3))
    }
}
