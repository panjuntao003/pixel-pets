import Foundation

struct TokenBatch {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0

    var totalTokens: Int {
        inputTokens + outputTokens
    }

    mutating func add(_ other: TokenBatch) {
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        cacheReadTokens += other.cacheReadTokens
        cacheWriteTokens += other.cacheWriteTokens
    }
}

final class ClaudeLogParser {
    private let basePath: String
    private let installedAt: Date
    private let iso8601Formatter = ISO8601DateFormatter()
    private let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(basePath: String? = nil, installedAt: Date = .distantPast) {
        self.basePath = basePath ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.claude/projects")
        self.installedAt = installedAt
    }

    func parseAll() -> TokenBatch {
        guard let enumerator = FileManager.default.enumerator(atPath: basePath) else {
            return TokenBatch()
        }

        var batch = TokenBatch()
        for case let relativePath as String in enumerator where relativePath.hasSuffix(".jsonl") {
            let filePath = URL(fileURLWithPath: basePath).appendingPathComponent(relativePath).path
            batch.add(parse(filePath: filePath))
        }
        return batch
    }

    func parse(filePath: String) -> TokenBatch {
        guard let contents = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return TokenBatch()
        }

        var batch = TokenBatch()
        for line in contents.split(whereSeparator: \.isNewline) {
            guard let usage = usageObject(from: String(line)) else {
                continue
            }

            batch.inputTokens += intValue(usage["input_tokens"])
            batch.outputTokens += intValue(usage["output_tokens"])
            batch.cacheReadTokens += intValue(usage["cache_read_input_tokens"])
            batch.cacheWriteTokens += intValue(usage["cache_creation_input_tokens"])
        }
        return batch
    }

    private func usageObject(from line: String) -> [String: Any]? {
        guard
            let data = line.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        if let timestamp = json["timestamp"] as? String,
           let date = date(from: timestamp),
           date < installedAt {
            return nil
        }

        guard
            let message = json["message"] as? [String: Any],
            let usage = message["usage"] as? [String: Any]
        else {
            return nil
        }

        return usage
    }

    private func date(from timestamp: String) -> Date? {
        iso8601Formatter.date(from: timestamp) ?? fractionalISO8601Formatter.date(from: timestamp)
    }

    private func intValue(_ value: Any?) -> Int {
        switch value {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        default:
            return 0
        }
    }
}
