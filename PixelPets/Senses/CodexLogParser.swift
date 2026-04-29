import Foundation

final class CodexLogParser {
    private enum UsageRecord {
        case incremental([String: Any])
        case tokenCount(last: [String: Any]?, total: [String: Any]?)
    }

    private let basePath: String
    private let installedAt: Date
    private let newline = Data([0x0A])
    private let iso8601Formatter = ISO8601DateFormatter()
    private let fractionalISO8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(basePath: String? = nil, installedAt: Date = .distantPast) {
        let environmentPath = ProcessInfo.processInfo.environment["CODEX_HOME"]
        self.basePath = basePath ?? environmentPath.map { $0 + "/sessions" } ?? (FileManager.default.homeDirectoryForCurrentUser.path + "/.codex/sessions")
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
        guard let fileHandle = FileHandle(forReadingAtPath: filePath) else {
            return TokenBatch()
        }
        defer {
            fileHandle.closeFile()
        }

        var batch = TokenBatch()
        var buffer = Data()
        var previousTokenCountTotal: TokenBatch?

        while true {
            let chunk = fileHandle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty {
                break
            }

            buffer.append(chunk)
            consumeCompleteLines(from: &buffer, into: &batch, previousTokenCountTotal: &previousTokenCountTotal)
        }

        if !buffer.isEmpty {
            accumulateLine(buffer, into: &batch, previousTokenCountTotal: &previousTokenCountTotal)
        }

        return batch
    }

    private func consumeCompleteLines(from buffer: inout Data, into batch: inout TokenBatch, previousTokenCountTotal: inout TokenBatch?) {
        while let range = buffer.range(of: newline) {
            let line = buffer[..<range.lowerBound]
            accumulateLine(Data(line), into: &batch, previousTokenCountTotal: &previousTokenCountTotal)
            buffer.removeSubrange(..<range.upperBound)
        }
    }

    private func accumulateLine(_ line: Data, into batch: inout TokenBatch, previousTokenCountTotal: inout TokenBatch?) {
        guard let record = usageRecord(from: line) else {
            return
        }

        switch record {
        case let .incremental(usage):
            batch.add(tokenBatch(from: usage))
        case let .tokenCount(last, total):
            if let last {
                batch.add(tokenBatch(from: last))
                if let total {
                    previousTokenCountTotal = tokenBatch(from: total)
                }
            } else if let total {
                let currentTotal = tokenBatch(from: total)
                batch.add(delta(from: previousTokenCountTotal, to: currentTotal))
                previousTokenCountTotal = currentTotal
            }
        }
    }

    private func usageRecord(from line: Data) -> UsageRecord? {
        guard
            !line.isEmpty,
            let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any]
        else {
            return nil
        }

        if installedAt != .distantPast {
            guard
                let timestamp = json["timestamp"] as? String,
                let date = date(from: timestamp),
                date >= installedAt
            else {
                return nil
            }
        }

        switch json["type"] as? String {
        case "response_item":
            guard let usage = responseItemUsage(from: json) else {
                return nil
            }
            return .incremental(usage)
        case "event_msg":
            return tokenCountUsage(from: json)
        default:
            return nil
        }
    }

    private func responseItemUsage(from json: [String: Any]) -> [String: Any]? {
        if
            let response = json["response"] as? [String: Any],
            let usage = response["usage"] as? [String: Any]
        {
            return usage
        }

        if
            let payload = json["payload"] as? [String: Any],
            let response = payload["response"] as? [String: Any],
            let usage = response["usage"] as? [String: Any]
        {
            return usage
        }

        return nil
    }

    private func tokenCountUsage(from json: [String: Any]) -> UsageRecord? {
        guard
            let payload = json["payload"] as? [String: Any],
            payload["type"] as? String == "token_count",
            let info = payload["info"] as? [String: Any]
        else {
            return nil
        }

        let last = info["last_token_usage"] as? [String: Any]
        let total = info["total_token_usage"] as? [String: Any]
        guard last != nil || total != nil else {
            return nil
        }

        return .tokenCount(last: last, total: total)
    }

    private func tokenBatch(from usage: [String: Any]) -> TokenBatch {
        TokenBatch(
            inputTokens: intValue(usage["input_tokens"]),
            outputTokens: intValue(usage["output_tokens"]),
            cacheReadTokens: cacheReadTokens(from: usage),
            cacheWriteTokens: cacheWriteTokens(from: usage)
        )
    }

    private func delta(from previous: TokenBatch?, to current: TokenBatch) -> TokenBatch {
        guard let previous else {
            return current
        }

        return TokenBatch(
            inputTokens: max(0, current.inputTokens - previous.inputTokens),
            outputTokens: max(0, current.outputTokens - previous.outputTokens),
            cacheReadTokens: max(0, current.cacheReadTokens - previous.cacheReadTokens),
            cacheWriteTokens: max(0, current.cacheWriteTokens - previous.cacheWriteTokens)
        )
    }

    private func cacheReadTokens(from usage: [String: Any]) -> Int {
        if let value = firstPositiveInt(
            usage["cache_read_input_tokens"],
            usage["cache_read_tokens"],
            usage["cached_input_tokens"]
        ) {
            return value
        }

        if
            let details = usage["input_token_details"] as? [String: Any],
            let value = firstPositiveInt(details["cached_tokens"])
        {
            return value
        }

        if
            let details = usage["input_tokens_details"] as? [String: Any],
            let value = firstPositiveInt(details["cached_tokens"])
        {
            return value
        }

        return 0
    }

    private func cacheWriteTokens(from usage: [String: Any]) -> Int {
        intValue(usage["cache_creation_input_tokens"]) + intValue(usage["cache_write_input_tokens"])
    }

    private func firstPositiveInt(_ values: Any?...) -> Int? {
        for value in values {
            let int = intValue(value)
            if int > 0 {
                return int
            }
        }
        return nil
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
