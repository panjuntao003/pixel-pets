import Foundation
import SQLite3

private let growthStoreSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class GrowthStore {
    private enum Key {
        static let totalTokens = "totalTokens"
        static let installedAt = "installedAt"
        static let unlockedAccessories = "unlockedAccessories"
    }

    private var db: OpaquePointer?

    convenience init() {
        self.init(dbPath: Self.defaultDBPath())
    }

    init(dbPath: String) {
        let url = URL(fileURLWithPath: dbPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            if db != nil {
                sqlite3_close(db)
                db = nil
            }
            return
        }

        createTables()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    func saveTotalTokens(_ totalTokens: Int) {
        setKV(Key.totalTokens, String(totalTokens))
    }

    func loadTotalTokens() -> Int {
        guard let value = getKV(Key.totalTokens) else { return 0 }
        return Int(value) ?? 0
    }

    func saveInstalledAt(_ date: Date) {
        setKV(Key.installedAt, String(date.timeIntervalSince1970))
    }

    func loadInstalledAt() -> Date? {
        guard let value = getKV(Key.installedAt),
              let timestamp = Double(value) else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }

    func saveUnlockedAccessories(_ accessories: [Accessory]) {
        setKV(Key.unlockedAccessories, accessories.map(\.rawValue).joined(separator: ","))
    }

    func loadUnlockedAccessories() -> [Accessory] {
        guard let value = getKV(Key.unlockedAccessories), !value.isEmpty else { return [] }
        return value.split(separator: ",").compactMap { Accessory(rawValue: String($0)) }
    }

    func saveCursor(path: String, mtime: Double) {
        guard let statement = prepare("INSERT OR REPLACE INTO log_cursor(path, mtime) VALUES(?, ?)") else {
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, path, -1, growthStoreSQLiteTransient)
        sqlite3_bind_double(statement, 2, mtime)
        _ = sqlite3_step(statement)
    }

    func loadCursor(path: String) -> Double {
        guard let statement = prepare("SELECT mtime FROM log_cursor WHERE path=?") else {
            return 0
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, path, -1, growthStoreSQLiteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_double(statement, 0)
    }

    private static func defaultDBPath() -> String {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".pixelpets")
            .appendingPathComponent("pixelpets.db")
            .path
    }

    private func createTables() {
        guard let db else { return }
        _ = sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS kv (key TEXT PRIMARY KEY, value TEXT NOT NULL DEFAULT '')", nil, nil, nil)
        _ = sqlite3_exec(db, "CREATE TABLE IF NOT EXISTS log_cursor (path TEXT PRIMARY KEY, mtime REAL NOT NULL DEFAULT 0)", nil, nil, nil)
    }

    private func setKV(_ key: String, _ value: String) {
        guard let statement = prepare("INSERT OR REPLACE INTO kv(key, value) VALUES(?, ?)") else {
            return
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, growthStoreSQLiteTransient)
        sqlite3_bind_text(statement, 2, value, -1, growthStoreSQLiteTransient)
        _ = sqlite3_step(statement)
    }

    private func getKV(_ key: String) -> String? {
        guard let statement = prepare("SELECT value FROM kv WHERE key=?") else {
            return nil
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, key, -1, growthStoreSQLiteTransient)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0) else {
            return nil
        }
        return String(cString: text)
    }

    private func prepare(_ sql: String) -> OpaquePointer? {
        guard let db else { return nil }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            if statement != nil {
                sqlite3_finalize(statement)
            }
            return nil
        }
        return statement
    }
}
