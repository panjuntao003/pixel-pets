import Foundation

final class CodexLogParser {
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

        while true {
            let chunk = fileHandle.readData(ofLength: 64 * 1024)
            if chunk.isEmpty {
                break
            }

            buffer.append(chunk)
            consumeCompleteLines(from: &buffer, into: &batch)
        }

        if !buffer.isEmpty {
            accumulateLine(buffer, into: &batch)
        }

        return batch
    }

    private func consumeCompleteLines(from buffer: inout Data, into batch: inout TokenBatch) {
        while let range = buffer.range(of: newline) {
            let line = buffer[..<range.lowerBound]
            accumulateLine(Data(line), into: &batch)
            buffer.removeSubrange(..<range.upperBound)
        }
    }

    private func accumulateLine(_ line: Data, into batch: inout TokenBatch) {
        guard let usage = usageObject(from: line) else {
            return
        }

        batch.inputTokens += intValue(usage["input_tokens"])
        batch.outputTokens += intValue(usage["output_tokens"])
        batch.cacheReadTokens += cacheReadTokens(from: usage)
        batch.cacheWriteTokens += cacheWriteTokens(from: usage)
    }

    private func usageObject(from line: Data) -> [String: Any]? {
        guard
            !line.isEmpty,
            let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
            json["type"] as? String == "response_item"
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

    private func cacheReadTokens(from usage: [String: Any]) -> Int {
        let direct = intValue(usage["cache_read_input_tokens"]) + intValue(usage["cache_read_tokens"])
        let details = usage["input_token_details"] as? [String: Any]
        let pluralDetails = usage["input_tokens_details"] as? [String: Any]
        return direct + intValue(details?["cached_tokens"]) + intValue(pluralDetails?["cached_tokens"])
    }

    private func cacheWriteTokens(from usage: [String: Any]) -> Int {
        intValue(usage["cache_creation_input_tokens"]) + intValue(usage["cache_write_input_tokens"])
    }

    private func date(from timestamp: String) -> Date? {
        iso8601Formatter.date(from: timestamp) ?? fractionalISO8601Formatter.date(from: timestamp)
    }

    private func intValue(_ value: Any?) -> Int {
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
