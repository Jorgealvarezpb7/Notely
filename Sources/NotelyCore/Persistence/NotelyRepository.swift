import Foundation
#if canImport(SQLite3)
import SQLite3
#else
import CSQLite
#endif

/// A failed SQLite call: its result code and SQLite's message.
public struct SQLiteError: Error, CustomStringConvertible {
    public let code: Int32
    public let message: String

    public var description: String { "SQLite error \(code): \(message)" }
}

/// The data-persistence layer: one SQLite3 connection to the Notely
/// database, at `~/.Notely/db/data.sqlite3` unless a test names another
/// file. It knows nothing about notes; subclasses (`NotesRepository`)
/// own their tables and use `execute`, `prepare`, and `transaction`.
open class NotelyRepository {
    /// `~/.Notely`.
    public static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Notely", isDirectory: true)
    }

    /// `~/.Notely/db/data.sqlite3`.
    public static var defaultDatabaseURL: URL {
        homeDirectory
            .appendingPathComponent("db", isDirectory: true)
            .appendingPathComponent("data.sqlite3")
    }

    private var handle: OpaquePointer?

    /// Creates missing folders, then opens the database file, creating it
    /// when it does not exist. Never removes or replaces a file.
    public init(databaseURL: URL = NotelyRepository.defaultDatabaseURL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var opened: OpaquePointer?
        let code = sqlite3_open_v2(databaseURL.path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard code == SQLITE_OK else {
            let message = opened.map { String(cString: sqlite3_errmsg($0)) } ?? "could not open database"
            sqlite3_close_v2(opened)
            throw SQLiteError(code: code, message: message)
        }
        handle = opened
        do {
            try execute("PRAGMA journal_mode=WAL")
            try execute("PRAGMA synchronous=NORMAL")
            try execute("PRAGMA foreign_keys=ON")
        } catch {
            sqlite3_close_v2(handle)
            handle = nil
            throw error
        }
    }

    deinit {
        sqlite3_close_v2(handle)
    }

    private func lastError(_ code: Int32) -> SQLiteError {
        SQLiteError(code: code, message: handle.map { String(cString: sqlite3_errmsg($0)) } ?? "closed")
    }

    /// Runs statements that return no rows.
    public func execute(_ sql: String) throws {
        let code = sqlite3_exec(handle, sql, nil, nil, nil)
        guard code == SQLITE_OK else { throw lastError(code) }
    }

    public func prepare(_ sql: String) throws -> Statement {
        var statement: OpaquePointer?
        let code = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard code == SQLITE_OK, let statement else { throw lastError(code) }
        return Statement(statement, owner: self)
    }

    /// Runs `body` in one transaction: committed when it returns, rolled
    /// back when it throws.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE")
        do {
            let result = try body()
            try execute("COMMIT")
            return result
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    /// The schema version, in `PRAGMA user_version`; 0 for a new file.
    public var userVersion: Int {
        get {
            guard let statement = try? prepare("PRAGMA user_version"),
                  (try? statement.step()) == true else { return 0 }
            return statement.int(at: 0) ?? 0
        }
        set {
            try? execute("PRAGMA user_version = \(newValue)")
        }
    }

    /// One prepared statement, finalized when released.
    public final class Statement {
        private let statement: OpaquePointer
        private let owner: NotelyRepository

        fileprivate init(_ statement: OpaquePointer, owner: NotelyRepository) {
            self.statement = statement
            self.owner = owner
        }

        deinit {
            sqlite3_finalize(statement)
        }

        // Tells SQLite to copy the bound bytes, since Swift's buffer is
        // gone after the call.
        private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

        /// Binds at a 1-based `index`. `nil` binds NULL.
        public func bind(_ value: String?, at index: Int32) {
            if let value {
                sqlite3_bind_text(statement, index, value, -1, Self.transient)
            } else {
                sqlite3_bind_null(statement, index)
            }
        }

        public func bind(_ value: Int?, at index: Int32) {
            if let value {
                sqlite3_bind_int64(statement, index, Int64(value))
            } else {
                sqlite3_bind_null(statement, index)
            }
        }

        /// `true` when a row is ready, `false` when the statement is done.
        @discardableResult
        public func step() throws -> Bool {
            let code = sqlite3_step(statement)
            switch code {
            case SQLITE_ROW: return true
            case SQLITE_DONE: return false
            default: throw owner.lastError(code)
            }
        }

        /// Clears bindings and rewinds, to run again with new values.
        public func reset() {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
        }

        /// Column readers use 0-based indexes; `nil` for NULL.
        public func string(at index: Int32) -> String? {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL,
                  let text = sqlite3_column_text(statement, index) else { return nil }
            return String(cString: text)
        }

        public func int(at index: Int32) -> Int? {
            guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
            return Int(sqlite3_column_int64(statement, index))
        }
    }
}
