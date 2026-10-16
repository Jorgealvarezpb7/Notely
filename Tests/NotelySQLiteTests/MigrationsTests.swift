import Foundation
import NotelyCore
@testable import NotelySQLite
import Testing

private struct Boom: Error {}

private func tableExists(_ name: String, _ connection: SQLiteConnection) throws -> Bool {
    let statement = try connection.prepare("SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name = ?")
    statement.bind(name, at: 1)
    try statement.step()
    return statement.int(at: 0) == 1
}

struct MigrationsTests {
    @Test func newDatabaseEndsAtTheLatestVersionWithTheNotesTable() throws {
        let folder = TempFolder()
        _ = try NotesDatabase(url: folder.databaseURL)
        let connection = try SQLiteConnection(url: folder.databaseURL)
        #expect(try connection.userVersion == Migrations.all.map(\.version).max())
        #expect(try tableExists("notes", connection))
    }

    @Test func reopeningDoesNotRunMigrationsAgain() throws {
        let folder = TempFolder()
        var runs = 0
        let counting = [Migration(version: 1) { _ in runs += 1 }]
        _ = try NotesDatabase(url: folder.databaseURL, migrations: counting)
        _ = try NotesDatabase(url: folder.databaseURL, migrations: counting)
        #expect(runs == 1)
    }

    @Test func onlyPendingMigrationsRunAndInOrder() throws {
        let folder = TempFolder()
        var order: [Int] = []
        let first = Migration(version: 1) { order.append(1); try $0.execute("CREATE TABLE a (x TEXT)") }
        let second = Migration(version: 2) { order.append(2); try $0.execute("CREATE TABLE b (x TEXT)") }
        _ = try NotesDatabase(url: folder.databaseURL, migrations: [first])
        _ = try NotesDatabase(url: folder.databaseURL, migrations: [first, second])
        #expect(order == [1, 2])
        let connection = try SQLiteConnection(url: folder.databaseURL)
        #expect(try connection.userVersion == 2)
        #expect(try tableExists("b", connection))
    }

    @Test func failingMigrationLeavesVersionZeroAndNoTable() throws {
        let folder = TempFolder()
        let broken = [Migration(version: 1) { try $0.execute(NotesTable.createSQL); throw Boom() }]
        #expect(throws: Boom.self) { _ = try NotesDatabase(url: folder.databaseURL, migrations: broken) }
        let connection = try SQLiteConnection(url: folder.databaseURL)
        #expect(try connection.userVersion == 0)
        #expect(try !tableExists("notes", connection))
        // The next launch tries again and succeeds.
        #expect(try NotesDatabase(url: folder.databaseURL).all().isEmpty)
    }

    @Test func failingSeedLeavesVersionZeroAndNoTable() throws {
        let folder = TempFolder()
        let id = UUID()
        #expect(throws: (any Error).self) {
            _ = try NotesDatabase(url: folder.databaseURL) {
                [Note(id: id, text: "a"), Note(id: id, text: "duplicate id")]
            }
        }
        let connection = try SQLiteConnection(url: folder.databaseURL)
        #expect(try connection.userVersion == 0)
        #expect(try !tableExists("notes", connection))
    }

    @Test func seedRunsOnlyForANewDatabase() throws {
        let folder = TempFolder()
        var calls = 0
        let seed: () -> [Note] = { calls += 1; return [Note(id: UUID(), text: "seed")] }
        #expect(try NotesDatabase(url: folder.databaseURL, initialNotes: seed).all().count == 1)
        #expect(try NotesDatabase(url: folder.databaseURL, initialNotes: seed).all().count == 1)
        #expect(calls == 1)
    }

    @Test func newerDatabaseIsOpenedUntouched() throws {
        let folder = TempFolder()
        let note = Note(id: UUID(), text: "kept")
        do {
            let database = try NotesDatabase(url: folder.databaseURL)
            try database.insert(note)
        }
        try SQLiteConnection(url: folder.databaseURL).setUserVersion(99)
        #expect(try NotesDatabase(url: folder.databaseURL).all().map(\.id) == [note.id])
        #expect(try SQLiteConnection(url: folder.databaseURL).userVersion == 99)
    }
}
