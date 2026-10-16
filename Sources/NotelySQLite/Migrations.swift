import Foundation
import NotelyCore

/// One schema step. `version` numbers are consecutive from 1.
struct Migration {
    let version: Int
    let apply: (SQLiteConnection) throws -> Void
}

/// The schema history. Append a `Migration` with the next version for each
/// schema change; never edit one that has shipped.
enum Migrations {
    static let all: [Migration] = [
        Migration(version: 1) { try $0.execute(NotesTable.createSQL) },
    ]

    /// Brings the schema to the last version in `migrations`, applying only
    /// the steps not yet applied, in order. On a new database (version 0),
    /// `seed` runs after the steps. Everything happens in one transaction,
    /// so a failure leaves the database as it was. A database already at a
    /// newer version is left untouched.
    static func run(on connection: SQLiteConnection,
                    migrations: [Migration] = Migrations.all,
                    seed: ((SQLiteConnection) throws -> Void)? = nil) throws {
        let current = try connection.userVersion
        let latest = migrations.map(\.version).max() ?? 0
        guard current < latest else { return }
        let log = Log("sqlite")
        log.info("migrating schema from version \(current) to \(latest)")
        try connection.transaction {
            for migration in migrations where migration.version > current {
                log.debug("applying migration \(migration.version)")
                try migration.apply(connection)
            }
            if current == 0 {
                log.info("new database, importing initial notes")
                try seed?(connection)
            }
            try connection.setUserVersion(latest)
        }
    }
}
