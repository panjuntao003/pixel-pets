import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class OpenCodeGoQuotaClient {
    private static let authFilePath = ".local/share/opencode/auth.json"
    private static let probeURL = URL(string: "https://opencode.ai/zen/go/v1/chat/completions")!

    private static let rollingWindowHours: Double = 5
    private static let weeklyDays: Double = 7

    // OpenCode Go Lite plan monthly cost limit in cents ($5 = 500 cents).
    // Tokens are counted in micro-cents server-side; we estimate from local token counts.
    // Rolling limit: $5, Weekly limit: $5, Monthly limit: $5
    // We use approximate cost-per-token to estimate usage percentage.
    private static let estimatedRollingLimitTokens: Int = 2_000_000
    private static let estimatedWeeklyLimitTokens: Int = 5_000_000
    private static let estimatedMonthlyLimitTokens: Int = 15_000_000

    func fetch() async -> QuotaFetchResult {
        guard let apiKey = Self.readApiKey() else {
            return .unavailable("未找到 opencode-go API 密钥")
        }

        let dbPath = Self.defaultDatabasePath()
        let rollingCutoff = Date().addingTimeInterval(-Self.rollingWindowHours * 3600)
        let weeklyCutoff = Calendar.current.date(byAdding: .day, value: -Int(Self.weeklyDays), to: Date()) ?? Date().addingTimeInterval(-Self.weeklyDays * 86400)
        let monthlyCutoff = Self.monthlyCutoffDate()

        let localRolling = Self.countTokens(since: rollingCutoff, dbPath: dbPath)
        let localWeekly = Self.countTokens(since: weeklyCutoff, dbPath: dbPath)
        let localMonthly = Self.countTokens(since: monthlyCutoff, dbPath: dbPath)

        var request = URLRequest(url: Self.probeURL, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let probeBody: [String: Any] = [
            "model": "deepseek-v4-flash",
            "messages": [["role": "user", "content": "hi"]],
            "max_tokens": 1
        ]
        guard let bodyData = try? JSONSerialization.data(withJSONObject: probeBody) else {
            return .unavailable("探测请求序列化失败")
        }
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return .unavailable("无效响应")
            }

            if http.statusCode == 429 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any] {
                    let errorType = error["type"] as? String ?? ""
                    let retryAfterSeconds = Double(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 18000
                    let resetsAt = Date().addingTimeInterval(retryAfterSeconds)

                    if errorType == "SubscriptionUsageLimitError" {
                        let message = error["message"] as? String ?? ""
                        let tiers = Self.parseExhaustedTiers(message: message, retryAfter: retryAfterSeconds)
                        if !tiers.isEmpty {
                            return .success(tiers)
                        }
                        return .success([
                            QuotaTier(id: "rolling", utilization: 1.0, resetsAt: resetsAt, isEstimated: false),
                            QuotaTier(id: "monthly", utilization: 1.0, resetsAt: Self.monthlyResetDate(), isEstimated: false)
                        ])
                    }
                }
                return .unavailable("请求被限流（非配额错误）")
            }

            if (200...299).contains(http.statusCode) {
                let rollingUsage = min(1.0, Double(localRolling) / Double(Self.estimatedRollingLimitTokens))
                let weeklyUsage = min(1.0, Double(localWeekly) / Double(Self.estimatedWeeklyLimitTokens))
                let monthlyUsage = min(1.0, Double(localMonthly) / Double(Self.estimatedMonthlyLimitTokens))

                let rollingReset = Date().addingTimeInterval(Self.rollingWindowHours * 3600)
                let weeklyReset = Self.weeklyResetDate()
                let monthlyReset = Self.monthlyResetDate()

                return .estimated([
                    QuotaTier(id: "rolling", utilization: rollingUsage, resetsAt: rollingReset, isEstimated: true),
                    QuotaTier(id: "weekly", utilization: weeklyUsage, resetsAt: weeklyReset, isEstimated: true),
                    QuotaTier(id: "monthly", utilization: monthlyUsage, resetsAt: monthlyReset, isEstimated: true)
                ])
            }

            return .unavailable("API 返回 \(http.statusCode)")
        } catch {
            return .unavailable("网络请求失败")
        }
    }

    // MARK: - Exhausted tier parsing

    private static func parseExhaustedTiers(message: String, retryAfter: Double) -> [QuotaTier] {
        var tiers: [QuotaTier] = []
        let now = Date()
        let resetsAt = now.addingTimeInterval(retryAfter)

        let lower = message.lowercased()

        if lower.contains("rolling") || lower.contains("5-hour") || lower.contains("5 hour") {
            tiers.append(QuotaTier(id: "rolling", utilization: 1.0, resetsAt: resetsAt, isEstimated: false))
        }
        if lower.contains("weekly") || lower.contains("7-day") || lower.contains("7 day") {
            let weeklyReset = Self.weeklyResetDate()
            tiers.append(QuotaTier(id: "weekly", utilization: 1.0, resetsAt: weeklyReset, isEstimated: false))
        }
        if lower.contains("monthly") || lower.contains("30-day") || lower.contains("30 day") {
            let monthlyReset = Self.monthlyResetDate()
            tiers.append(QuotaTier(id: "monthly", utilization: 1.0, resetsAt: monthlyReset, isEstimated: false))
        }

        if tiers.isEmpty && lower.contains("usage") {
            tiers.append(QuotaTier(id: "rolling", utilization: 1.0, resetsAt: resetsAt, isEstimated: false))
        }

        return tiers
    }

    // MARK: - Reset date calculation

    private static func weeklyResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        guard let nextMonday = calendar.nextDate(after: now, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) else {
            return now.addingTimeInterval(7 * 86400)
        }
        return calendar.startOfDay(for: nextMonday)
    }

    private static func monthlyResetDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.month = (components.month ?? 1) + 1
        components.day = 1
        guard let nextMonth = calendar.date(from: components) else {
            return now.addingTimeInterval(30 * 86400)
        }
        return calendar.startOfDay(for: nextMonth)
    }

    private static func monthlyCutoffDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var components = calendar.dateComponents([.year, .month], from: now)
        components.day = 1
        guard let monthStart = calendar.date(from: components) else {
            return now.addingTimeInterval(-30 * 86400)
        }
        return monthStart
    }

    // MARK: - Local token counting from opencode.db

    private static func countTokens(since cutoff: Date, dbPath: String) -> Int {
        guard FileManager.default.fileExists(atPath: dbPath) else { return 0 }

        var db: OpaquePointer?
        guard sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else { return 0 }
        defer { sqlite3_close(db) }

        guard tableExists("part", in: db) else { return 0 }

        let hasTimeCreated = columnExists("time_created", table: "part", in: db)
        var sql = "SELECT data FROM part WHERE data LIKE '%tokens%'"
        if hasTimeCreated {
            sql += " AND time_created >= ?"
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { return 0 }
        defer { sqlite3_finalize(statement) }

        if hasTimeCreated {
            sqlite3_bind_int64(statement, 1, Int64(cutoff.timeIntervalSince1970 * 1_000))
        }

        var total = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 0) else { continue }
            let batch = parseTokenJSON(Data(String(cString: text).utf8))
            total += batch.totalTokens
        }
        return total
    }

    private static func parseTokenJSON(_ data: Data) -> TokenBatch {
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

    private static func intValue(_ value: Any?) -> Int {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() { return 0 }
            return number.intValue
        case let int as Int:
            return int
        case _ as Bool:
            return 0
        default:
            return 0
        }
    }

    private static func tableExists(_ tableName: String, in db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table' AND name=?", -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        sqlite3_bind_text(statement, 1, tableName, -1, sqliteTransient)
        return sqlite3_step(statement) == SQLITE_ROW
    }

    private static func columnExists(_ columnName: String, table: String, in db: OpaquePointer) -> Bool {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        let escapedTable = table.replacingOccurrences(of: "'", with: "''")
        guard sqlite3_prepare_v2(db, "PRAGMA table_info('\(escapedTable)')", -1, &statement, nil) == SQLITE_OK else {
            return false
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let text = sqlite3_column_text(statement, 1) else { continue }
            if String(cString: text) == columnName { return true }
        }
        return false
    }

    // MARK: - Auth

    static func readApiKey() -> String? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent(authFilePath).path
        guard
            let data = FileManager.default.contents(atPath: path),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let entry = json["opencode-go"] as? [String: Any],
            let key = entry["key"] as? String,
            !key.isEmpty
        else {
            return nil
        }
        return key
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

        if FileManager.default.fileExists(atPath: macOSPath) { return macOSPath }
        if FileManager.default.fileExists(atPath: xdgPath) { return xdgPath }
        return xdgPath
    }
}