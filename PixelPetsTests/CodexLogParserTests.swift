import XCTest
@testable import PixelPets

final class CodexLogParserTests: XCTestCase {
    var fixturePath: String {
        Bundle(for: Self.self).path(forResource: "codex_sample", ofType: "jsonl")!
    }

    func test_parsesFixtureTokenCountEvents() {
        let batch = CodexLogParser().parse(filePath: fixturePath)

        XCTAssertEqual(batch.inputTokens, 14_776)
        XCTAssertEqual(batch.outputTokens, 519)
        XCTAssertEqual(batch.cacheReadTokens, 13_696)
        XCTAssertEqual(batch.cacheWriteTokens, 0)
    }

    func test_parsesPayloadResponseUsage() throws {
        let jsonl = """
        {"timestamp":"2026-04-20T06:05:51.702Z","type":"response_item","payload":{"response":{"usage":{"input_tokens":100,"output_tokens":25,"input_token_details":{"cached_tokens":10},"cache_creation_input_tokens":5}}}}
        {"timestamp":"2026-04-20T06:05:52.702Z","type":"event_msg","payload":{"response":{"usage":{"input_tokens":999,"output_tokens":999}}}}
        not-json

        """
        let tmp = try makeTempDirectory().appendingPathComponent("session.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = CodexLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 100)
        XCTAssertEqual(batch.outputTokens, 25)
        XCTAssertEqual(batch.cacheReadTokens, 10)
        XCTAssertEqual(batch.cacheWriteTokens, 5)
    }

    func test_parsesTopLevelResponseUsageAndCacheReadInputTokens() throws {
        let jsonl = """
        {"timestamp":"2026-04-20T06:05:51.702Z","type":"response_item","response":{"usage":{"input_tokens":11,"output_tokens":22,"cache_read_input_tokens":3,"cache_creation_input_tokens":4}}}
        """
        let tmp = try makeTempDirectory().appendingPathComponent("session.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = CodexLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 11)
        XCTAssertEqual(batch.outputTokens, 22)
        XCTAssertEqual(batch.cacheReadTokens, 3)
        XCTAssertEqual(batch.cacheWriteTokens, 4)
    }

    func test_parsesTokenCountLastUsageWithoutDoubleCountingTotalUsage() throws {
        let jsonl = """
        {"timestamp":"2026-04-20T06:05:51.702Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":999,"cached_input_tokens":888,"output_tokens":777},"last_token_usage":{"input_tokens":12,"cached_input_tokens":3,"output_tokens":4,"reasoning_output_tokens":5}}}}
        """
        let tmp = try makeTempDirectory().appendingPathComponent("token-count.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = CodexLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 12)
        XCTAssertEqual(batch.outputTokens, 4)
        XCTAssertEqual(batch.cacheReadTokens, 3)
    }

    func test_parsesTokenCountTotalUsageWhenLastUsageMissing() throws {
        let jsonl = """
        {"timestamp":"2026-04-20T06:05:51.702Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":21,"cached_input_tokens":8,"output_tokens":13}}}}
        """
        let tmp = try makeTempDirectory().appendingPathComponent("token-count-total.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = CodexLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 21)
        XCTAssertEqual(batch.outputTokens, 13)
        XCTAssertEqual(batch.cacheReadTokens, 8)
    }

    func test_parseAllRecursivelyIncludesJSONLFiles() throws {
        let root = try makeTempDirectory()
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try #"{"type":"response_item","response":{"usage":{"input_tokens":1,"output_tokens":2}}}"#
            .write(to: root.appendingPathComponent("root.jsonl"), atomically: true, encoding: .utf8)
        try #"{"type":"response_item","response":{"usage":{"input_tokens":3,"output_tokens":4}}}"#
            .write(to: nested.appendingPathComponent("nested.jsonl"), atomically: true, encoding: .utf8)
        try #"{"type":"response_item","response":{"usage":{"input_tokens":99,"output_tokens":99}}}"#
            .write(to: nested.appendingPathComponent("ignored.txt"), atomically: true, encoding: .utf8)

        let batch = CodexLogParser(basePath: root.path).parseAll()

        XCTAssertEqual(batch.inputTokens, 4)
        XCTAssertEqual(batch.outputTokens, 6)
    }

    func test_installedAtFilterSkipsMissingOldAndUnparseableTimestamps() throws {
        let installedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let jsonl = """
        {"type":"response_item","response":{"usage":{"input_tokens":100,"output_tokens":1}}}
        {"timestamp":"not-a-date","type":"response_item","response":{"usage":{"input_tokens":100,"output_tokens":1}}}
        {"timestamp":"2020-01-01T00:00:00Z","type":"response_item","response":{"usage":{"input_tokens":100,"output_tokens":1}}}
        {"timestamp":"2023-11-14T22:14:20Z","type":"response_item","response":{"usage":{"input_tokens":8,"output_tokens":9}}}
        """
        let tmp = try makeTempDirectory().appendingPathComponent("scoped.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = CodexLogParser(installedAt: installedAt).parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 8)
        XCTAssertEqual(batch.outputTokens, 9)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("CodexLogParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
