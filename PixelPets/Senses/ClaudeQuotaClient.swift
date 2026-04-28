import Foundation
import Security

final class ClaudeQuotaClient {
    private static let credentialService = "Claude Code-credentials"
    private static let credentialFilePath = ".claude/.credentials.json"
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let quotaWindowIDs = ["five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet"]

    private static let iso8601Formatter = ISO8601DateFormatter()
    private static let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func fetch() async -> QuotaFetchResult {
        guard let token = Self.readAccessToken() else {
            return .unavailable("未找到 Claude Code 凭据")
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
                return .unavailable("配额 API 请求失败")
            }

            let tiers = Self.parseQuotaTiers(from: data)
            guard !tiers.isEmpty else {
                return .unavailable("响应中无配额数据")
            }

            return .success(tiers)
        } catch {
            return .unavailable("配额 API 请求失败")
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
                let utilization = doubleValue(window["utilization"])
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

    private static func readAccessToken() -> String? {
        if let keychainData = readKeychainCredentialData(),
           let token = extractAccessToken(from: keychainData) {
            return token
        }

        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(credentialFilePath)
        guard
            let fileData = try? Data(contentsOf: credentialURL),
            let token = extractAccessToken(from: fileData)
        else {
            return nil
        }

        return token
    }

    private static func readKeychainCredentialData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: credentialService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    private static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case _ as Bool:
            return nil
        case let double as Double:
            return double
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }

    private static func date(from string: String?) -> Date? {
        guard let string else {
            return nil
        }

        return iso8601Formatter.date(from: string) ?? fractionalISO8601Formatter.date(from: string)
    }
}
