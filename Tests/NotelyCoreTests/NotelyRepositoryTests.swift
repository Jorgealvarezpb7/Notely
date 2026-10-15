import Foundation
import NotelyCore
import Testing

/// A folder of its own per test, removed when the test ends.
final class TempFolder {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("NotelyTests-\(UUID().uuidString)", isDirectory: true)

    /// `<folder>/db/data.sqlite3`: the `db` folder does not exist yet.
    var databaseURL: URL {
        url.appendingPathComponent("db", isDirectory: true).appendingPathComponent("data.sqlite3")
    }

    deinit {
        try? FileManager.default.removeItem(at: url)
    }
}

struct NotelyRepositoryTests {
    @Test func createsMissingFoldersAndFile() throws {
        let folder = TempFolder()
        _ = try NotelyRepository(databaseURL: folder.databaseURL)
        #expect(FileManager.default.fileExists(atPath: folder.databaseURL.path))
    }

    @Test func reopeningKeepsData() throws {
        let folder = TempFolder()
        do {
            let repository = try NotelyRepository(databaseURL: folder.databaseURL)
            try repository.execute("CREATE TABLE t (a TEXT)")
            try repository.execute("INSERT INTO t VALUES ('kept')")
        }
        let repository = try NotelyRepository(databaseURL: folder.databaseURL)
        let statement = try repository.prepare("SELECT a FROM t")
        #expect(try statement.step())
        #expect(statement.string(at: 0) == "kept")
    }

    @Test func defaultLocationIsUnderTheHomeFolder() {
        let path = NotelyRepository.defaultDatabaseURL.path
        #expect(path.hasSuffix("/.Notely/db/data.sqlite3"))
        #expect(path.hasPrefix(FileManager.default.homeDirectoryForCurrentUser.path))
    }

    @Test func valuesRoundTrip() throws {
        let folder = TempFolder()
        let repository = try NotelyRepository(databaseURL: folder.databaseURL)
        try repository.execute("CREATE TABLE t (s TEXT, n INTEGER, z TEXT)")
        let insert = try repository.prepare("INSERT INTO t VALUES (?, ?, ?)")
        insert.bind("héllo 'quoted'", at: 1)
        insert.bind(42, at: 2)
        insert.bind(nil as String?, at: 3)
        try insert.step()

        let select = try repository.prepare("SELECT s, n, z FROM t")
        #expect(try select.step())
        #expect(select.string(at: 0) == "héllo 'quoted'")
        #expect(select.int(at: 1) == 42)
        #expect(select.string(at: 2) == nil)
        #expect(try select.step() == false)
    }

    private func rowCount(_ repository: NotelyRepository) throws -> Int {
        let statement = try repository.prepare("SELECT COUNT(*) FROM t")
        try statement.step()
        return statement.int(at: 0) ?? -1
    }

    @Test func transactionCommitsOnSuccess() throws {
        let folder = TempFolder()
        let repository = try NotelyRepository(databaseURL: folder.databaseURL)
        try repository.execute("CREATE TABLE t (a TEXT)")
        try repository.transaction { try repository.execute("INSERT INTO t VALUES ('x')") }
        #expect(try rowCount(repository) == 1)
    }

    @Test func transactionRollsBackOnThrow() throws {
        struct Boom: Error {}
        let folder = TempFolder()
        let repository = try NotelyRepository(databaseURL: folder.databaseURL)
        try repository.execute("CREATE TABLE t (a TEXT)")
        #expect(throws: Boom.self) {
            try repository.transaction {
                try repository.execute("INSERT INTO t VALUES ('x')")
                throw Boom()
            }
        }
        #expect(try rowCount(repository) == 0)
    }

    @Test func userVersionPersists() throws {
        let folder = TempFolder()
        do {
            let repository = try NotelyRepository(databaseURL: folder.databaseURL)
            #expect(repository.userVersion == 0)
            repository.userVersion = 3
        }
        #expect(try NotelyRepository(databaseURL: folder.databaseURL).userVersion == 3)
    }

    @Test func parentThatIsAFileThrowsAndSurvives() throws {
        let folder = TempFolder()
        try FileManager.default.createDirectory(at: folder.url, withIntermediateDirectories: true)
        let blocker = folder.url.appendingPathComponent("db")
        try Data("keep".utf8).write(to: blocker)

        #expect(throws: (any Error).self) {
            _ = try NotelyRepository(databaseURL: folder.databaseURL)
        }
        #expect(try Data(contentsOf: blocker) == Data("keep".utf8))
    }
}
