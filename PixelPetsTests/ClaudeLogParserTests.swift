import XCTest
@testable import PixelPets

final class ClaudeLogParserTests: XCTestCase {
    var fixturePath: String {
        Bundle(for: Self.self).path(forResource: "claude_sample", ofType: "jsonl")!
    }

    func test_parsesFixture_returnsNonZeroTokens() {
        let batch = ClaudeLogParser().parse(filePath: fixturePath)

        XCTAssertGreaterThan(
            batch.inputTokens + batch.outputTokens,
            0,
            "Fixture must contain at least one usage entry"
        )
    }

    func test_parsesInlineJSONL() throws {
        let jsonl = "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":100,\"output_tokens\":200,\"cache_read_input_tokens\":50}}}\n"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("t.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 100)
        XCTAssertEqual(batch.outputTokens, 200)
        XCTAssertEqual(batch.cacheReadTokens, 50)
    }

    func test_emptyFile_returnsZero() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("empty.jsonl")
        try "".write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.totalTokens, 0)
    }

    func test_installedAtFilter_excludesOldEntries() throws {
        let future = Date().addingTimeInterval(3600)
        let jsonl = "{\"type\":\"assistant\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)))\",\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":1}}}\n"
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("old.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser(installedAt: future).parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 0, "Entries before installedAt must be excluded")
    }
}
