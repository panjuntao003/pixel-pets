import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class OpenCodeLogParser {
    private let dbPath: String
    private let installedAt: Date

    init(dbPath: String? = nil, installedAt: Date = .distantPast) {
        self.dbPath = dbPath ?? Self.defaultDatabasePath()
        self.installedAt = installedAt
    }

    func parseAll() -> TokenBatch {
        guard FileManager.default.fileExists(atPath: dbPath) else {
            return TokenBatch()
        }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return TokenBatch()
        }
        defer {
            sqlite3_close(db)
        }

        guard tableExists("part", in: db), columnExists("data", table: "part", in: db) else {
            return TokenBatch()
        }

        let hasTimeCreated = columnExists("time_created", table: "part", in: db)
        var sql = "SELECT data FROM part WHERE data LIKE '%tokens%'"
        if installedAt != .distantPast, hasTimeCreated {
            sql += " AND time_created >= ?"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return TokenBatch()
        }
        defer {
            sqlite3_finalize(statement)
        }

        if installedAt != .distantPast, hasTimeCreated {
            sqlite3_bind_int64(statement, 1, Int64(installedAt.timeIntervalSince1970 * 1_000))
        }

        var batch = TokenBatch()
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else {
                continue
            }

            batch.add(Self.parseTokenJSON(Data(String(cString: text).utf8)))
        }
        return batch
    }

    static func parseTokenJSON(_ data: Data) -> TokenBatch {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let tokens = json["tokens"] as? [String: Any]
        else {
            return TokenBatch()
        }

        var batch = TokenBatch()
        batch.inputTokens = intValue(tokens["input"])
        batch.outputTokens = intValue(tokens["output"])

        if let cache = tokens["cache"] as? [String: Any] {
            batch.cacheReadTokens = intValue(cache["read"])
            batch.cacheWriteTokens = intValue(cache["write"])
        }

        return batch
    }

    private static func defaultDatabasePath() -> String {
        if let dataHome = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !dataHome.isEmpty {
            return URL(fileURLWithPath: dataHome)
                .appendingPathComponent("opencode")
                .appendingPathComponent("opencode.db")
                .path
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let macOSPath = home
            .appendingPathComponent("Library/Application Support/opencode/opencode.db")
            .path
        let xdgPath = home
            .appendingPathComponent(".local/share/opencode/opencode.db")
            .path

        if FileManager.default.fileExists(atPath: macOSPath) {
            return macOSPath
        }
        if FileManager.default.fileExists(atPath: xdgPath) {
            return xdgPath
        }

        return xdgPath
    }

    private func tableExists(_ tableName: String, in db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name=?", -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        sqlite3_bind_text(statement, 1, tableName, -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private func columnExists(_ columnName: String, table: String, in db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        defer {
            sqlite3_finalize(statement)
        }

        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        guard sqlite3_prepare_v2(db, "PRAGMA table_info('\(escapedTable)')", -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 1) else {
                continue
            }

            if String(cString: text) == columnName {
                return true
            }
        }

        return false
    }

    private static func intValue(_ value: Any?) -> Int {
        switch value {
        case _ as Bool:
            return 0
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return 0
        }
    }
}
