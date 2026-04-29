import Foundation

final class GeminiLogParser {
    private let basePath: String
    private let installedAt: Date
    private let iso8601Formatter = ISO8601DateFormatter()
    private let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(basePath: String? = nil, installedAt: Date = .distantPast) {
        self.basePath = basePath ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.gemini/tmp")
        self.installedAt = installedAt
    }

    func parseAll() -> TokenBatch {
        guard let enumerator = FileManager.default.enumerator(atPath: basePath) else {
            return TokenBatch()
        }

        var batch = TokenBatch()
        for case let relativePath as String in enumerator {
            let searchablePath = relativePath.lowercased()
            guard searchablePath.hasSuffix(".json"), searchablePath.contains("chat") else {
                continue
            }

            let filePath = URL(fileURLWithPath: basePath).appendingPathComponent(relativePath).path
            batch.add(parse(filePath: filePath))
        }
        return batch
    }

    func parse(filePath: String) -> TokenBatch {
        guard
            let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
            let json = try? JSONSerialization.jsonObject(with: data)
        else {
            return TokenBatch()
        }

        let messages: [[String: Any]]
        if let array = json as? [[String: Any]] {
            messages = array
        } else if let object = json as? [String: Any] {
            messages = (object["messages"] as? [[String: Any]]) ?? (object["history"] as? [[String: Any]]) ?? []
        } else {
            messages = []
        }

        var batch = TokenBatch()
        for message in messages {
            accumulate(message, into: &batch)
        }
        return batch
    }

    private func accumulate(_ message: [String: Any], into batch: inout TokenBatch) {
        if installedAt != .distantPast {
            guard
                let timestamp = message["timestamp"] as? String,
                let date = date(from: timestamp),
                date >= installedAt
            else {
                return
            }
        }

        guard let usage = message["usageMetadata"] as? [String: Any] else {
            return
        }

        let input = intValue(usage["promptTokenCount"])
        let total = intValue(usage["totalTokenCount"])
        batch.inputTokens += input
        batch.outputTokens += max(0, total - input)
    }

    private func date(from timestamp: String) -> Date? {
        iso8601Formatter.date(from: timestamp) ?? fractionalISO8601Formatter.date(from: timestamp)
    }

    private func intValue(_ value: Any?) -> Int {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return 0
            }
            return number.intValue
        case let int as Int:
            return int
        case _ as Bool:
            return 0
        default:
            return 0
        }
    }
}
