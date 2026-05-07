import Foundation
import Security

final class ClaudeQuotaClient {
    private static let credentialService = "Claude Code-credentials"
    private static let credentialFilePath = ".claude/.credentials.json"
    private static let keychainAccessDeniedMessage = "Keychain access denied - open Keychain Access, find \"Claude Code-credentials\", and re-add Quota.app under Access Control"
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let quotaWindowIDs = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet"]

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func fetch() async -> QuotaFetchResult {
        let credentials = Self.readAccessToken()
        guard let token = credentials.token else {
            return .unavailable(credentials.deniedByKeychain ? Self.keychainAccessDeniedMessage : "Claude credentials not found")
        }

        var request = URLRequest(url: Self.usageURL, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                httpResponse.statusCode == 200,
                (try? JSONSerialization.jsonObject(with: data)) is [String: Any]
            else {
                return .unavailable("Quota API request failed")
            }

            let tiers = Self.parseQuotaTiers(from: data)
            guard !tiers.isEmpty else {
                return .unavailable("No quota data in response")
            }

            return .success(tiers)
        } catch {
            return .unavailable("Quota API request failed")
        }
    }

    static func extractAccessToken(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        for key in ["claudeAiOauth", "claude.ai_oauth"] {
            guard
                let credential = json[key] as? [String: Any],
                let token = credential["accessToken"] as? String,
                !token.isEmpty
            else {
                continue
            }

            return token
        }

        return nil
    }

    static func parseQuotaTiers(from data: Data) -> [QuotaTier] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return []
        }

        return quotaWindowIDs.compactMap { id in
            guard
                let window = json[id] as? [String: Any],
                let utilization = normalizedUtilization(window["utilization"])
            else {
                return nil
            }

            return QuotaTier(
                id: id,
                utilization: utilization,
                resetsAt: date(from: window["resets_at"] as? String),
                isEstimated: false
            )
        }
    }

    private static func readAccessToken() -> (token: String?, deniedByKeychain: Bool) {
        let (keychainData, keychainStatus) = readKeychainCredentialData()
        if let keychainData,
           let token = extractAccessToken(from: keychainData) {
            return (token, false)
        }

        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(credentialFilePath)
        if let fileData = try? Data(contentsOf: credentialURL),
           let token = extractAccessToken(from: fileData) {
            return (token, false)
        }

        return (nil, keychainAccessDenied(status: keychainStatus))
    }

    static func keychainAccessDenied(status: OSStatus) -> Bool {
        status != errSecItemNotFound && status != errSecSuccess
    }

    private static func readKeychainCredentialData() -> (Data?, OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return (nil, status)
        }

        return (item as? Data, status)
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        case let double as Double:
            return double
        case _ as Bool:
            return nil
        default:
            return nil
        }
    }

    private static func normalizedUtilization(_ value: Any?) -> Double? {
        guard let utilization = doubleValue(value) else {
            return nil
        }

        if utilization > 1 {
            return min(1, utilization / 100)
        }
        return max(0, utilization)
    }

    private static func date(from string: String?) -> Date? {
        guard let string else {
            return nil
        }

        return iso8601Formatter.date(from: string) ?? fractionalISO8601Formatter.date(from: string)
    }
}

final class CodexQuotaClient {
    private static let authFilePath = ".codex/auth.json"
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetch() async -> QuotaFetchResult {
        guard let token = Self.readAccessToken() else {
            return .unavailable("Codex credentials not found")
        }

        var request = URLRequest(url: Self.usageURL, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .unavailable("Codex quota API request failed")
            }

            let tiers = Self.parseQuotaTiers(from: data)
            guard !tiers.isEmpty else {
                return .unavailable("No Codex quota data")
            }

            return .success(tiers)
        } catch {
            return .unavailable("Codex quota API request failed")
        }
    }

    static func parseQuotaTiers(from data: Data, now: Date = Date()) -> [QuotaTier] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rateLimit = json["rate_limit"] as? [String: Any]
        else {
            return []
        }

        return [
            quotaTier(id: "five_hour", from: rateLimit["primary_window"], now: now),
            quotaTier(id: "weekly", from: rateLimit["secondary_window"], now: now)
        ].compactMap { $0 }
    }

    private static func quotaTier(id: String, from value: Any?, now: Date) -> QuotaTier? {
        guard
            let window = value as? [String: Any],
            let usedPercent = doubleValue(window["used_percent"])
        else {
            return nil
        }

        return QuotaTier(
            id: id,
            utilization: min(1, max(0, usedPercent / 100)),
            resetsAt: resetDate(from: window, now: now),
            isEstimated: false
        )
    }

    private static func resetDate(from window: [String: Any], now: Date) -> Date? {
        if let resetAt = doubleValue(window["reset_at"]) {
            return Date(timeIntervalSince1970: resetAt)
        }
        if let resetAfter = doubleValue(window["reset_after_seconds"]) {
            return now.addingTimeInterval(resetAfter)
        }
        return nil
    }

    private static func readAccessToken() -> String? {
        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(authFilePath)
        guard let data = try? Data(contentsOf: credentialURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["auth_mode"] as? String == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case _ as Bool:
            return nil
        default:
            return nil
        }
    }
}

final class GeminiQuotaClient {
    private static let oauthFilePath = ".gemini/oauth_creds.json"
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private static let loadCodeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private static let retrieveQuotaURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!
    private static let oauthClientID = "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com"
    private static let oauthClientSecret = "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"
    private static let iso8601Formatter = ISO8601DateFormatter()

    func fetch() async -> QuotaFetchResult {
        guard let token = await Self.readAccessToken() else {
            return .unavailable("Gemini CLI credentials not found")
        }

        do {
            let loadData = try await Self.postJSON(
                url: Self.loadCodeAssistURL,
                token: token,
                body: [
                    "metadata": [
                        "ideType": "IDE_UNSPECIFIED",
                        "platform": "PLATFORM_UNSPECIFIED",
                        "pluginType": "GEMINI"
                    ]
                ]
            )
            guard let project = Self.parseProject(from: loadData) else {
                return .unavailable("No project data in Gemini response")
            }

            let quotaData = try await Self.postJSON(
                url: Self.retrieveQuotaURL,
                token: token,
                body: ["project": project]
            )
            let tiers = Self.parseQuotaTiers(from: quotaData)
            guard !tiers.isEmpty else {
                return .unavailable("No quota data in Gemini response")
            }
            return .success(tiers)
        } catch {
            return .unavailable("Gemini quota API request failed")
        }
    }

    static func parseQuotaTiers(from data: Data) -> [QuotaTier] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let buckets = json["buckets"] as? [[String: Any]]
        else {
            return []
        }

        let proTier      = classTier(id: "pro",        from: buckets) { $0.contains("pro") }
        let flashTier    = classTier(id: "flash",      from: buckets) { $0.contains("flash") && !$0.contains("lite") }
        let flashLiteTier = classTier(id: "flash_lite", from: buckets) { $0.contains("flash") && $0.contains("lite") }

        return [proTier, flashTier, flashLiteTier].compactMap { $0 }
    }

    static func parseProject(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let project = json["cloudaicompanionProject"] as? String, !project.isEmpty {
            return project
        }

        if let project = json["cloudaicompanionProject"] as? [String: Any],
           let id = project["id"] as? String,
           !id.isEmpty {
            return id
        }

        return nil
    }

    private static func classTier(id: String, from buckets: [[String: Any]], matching: (String) -> Bool) -> QuotaTier? {
        let selected = buckets.filter { bucket in
            guard let modelId = bucket["modelId"] as? String else { return false }
            return matching(modelId)
        }
        guard !selected.isEmpty else { return nil }

        // Average remainingFraction across models in this class
        let fractions = selected.compactMap { doubleValue($0["remainingFraction"]) }
        guard !fractions.isEmpty else { return nil }

        let avgRemaining = fractions.reduce(0, +) / Double(fractions.count)

        // Use earliest reset time (most conservative)
        let resetDates = selected.compactMap { bucket -> Date? in
            guard let t = bucket["resetTime"] as? String else { return nil }
            return iso8601Formatter.date(from: t)
        }

        return QuotaTier(
            id: id,
            utilization: min(1, max(0, 1 - avgRemaining)),
            resetsAt: resetDates.min(),
            isEstimated: false
        )
    }

    private static func readAccessToken() async -> String? {
        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(oauthFilePath)
        guard let data = try? Data(contentsOf: credentialURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let token = json["access_token"] as? String,
           !token.isEmpty,
           !isExpired(json["expiry_date"]) {
            return token
        }

        guard let refreshToken = json["refresh_token"] as? String, !refreshToken.isEmpty else {
            return nil
        }

        return await refreshAccessToken(refreshToken: refreshToken)
    }

    private static func refreshAccessToken(refreshToken: String) async -> String? {
        var request = URLRequest(url: tokenURL, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: oauthClientID),
            URLQueryItem(name: "client_secret", value: oauthClientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["access_token"] as? String,
            !token.isEmpty
        else {
            return nil
        }

        return token
    }

    private static func postJSON(url: URL, token: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func isExpired(_ value: Any?) -> Bool {
        guard let expiryMilliseconds = doubleValue(value) else {
            return false
        }
        let expiryDate = Date(timeIntervalSince1970: expiryMilliseconds / 1000)
        return expiryDate.timeIntervalSinceNow < 60
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case _ as Bool:
            return nil
        default:
            return nil
        }
    }
}
