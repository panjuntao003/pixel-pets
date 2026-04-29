import Foundation

// Probes the opencode-go subscription quota via the /zen/go/v1/chat/completions endpoint.
// When quota is exceeded the server returns HTTP 429 with a `retry-after` header (seconds).
// No usage-percentage API exists server-side; we can only detect exhausted vs. available.
final class OpenCodeGoQuotaClient {
    private static let authFilePath = ".local/share/opencode/auth.json"
    private static let probeURL = URL(string: "https://opencode.ai/zen/go/v1/chat/completions")!

    // Probes the opencode-go API with a minimal (1-token) request.
    // Returns .success([tier]) with resetsAt when quota is exceeded (HTTP 429).
    // Returns .unavailable when the key is missing or the probe fails unexpectedly.
    // Returns .estimated([]) when quota is available but usage % is unknown.
    func fetch() async -> QuotaFetchResult {
        guard let apiKey = Self.readApiKey() else {
            return .unavailable("未找到 opencode-go API 密钥")
        }

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
                // Confirm it's a subscription quota error (not a rate-limit on free models)
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = json["error"] as? [String: Any],
                   let errorType = error["type"] as? String,
                   errorType == "SubscriptionUsageLimitError" {
                    let retryAfterSeconds = Double(http.value(forHTTPHeaderField: "retry-after") ?? "") ?? 3600
                    let resetsAt = Date().addingTimeInterval(retryAfterSeconds)
                    let tier = QuotaTier(
                        id: "rolling",
                        utilization: 1.0,
                        resetsAt: resetsAt,
                        isEstimated: false
                    )
                    return .success([tier])
                }
                return .unavailable("请求被限流（非配额错误）")
            }

            if (200...299).contains(http.statusCode) {
                // Quota available; usage % unknown without a server-side API
                let tier = QuotaTier(
                    id: "rolling",
                    utilization: 0,
                    resetsAt: nil,
                    isEstimated: true
                )
                return .estimated([tier])
            }

            return .unavailable("API 返回 \(http.statusCode)")
        } catch {
            return .unavailable("网络请求失败")
        }
    }

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
}
