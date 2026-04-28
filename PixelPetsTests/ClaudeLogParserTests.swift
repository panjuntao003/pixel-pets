import XCTest
@testable import PixelPets

final class ClaudeLogParserTests: XCTestCase {
    var fixturePath: String {
        Bundle(for: Self.self).path(forResource: "claude_sample", ofType: "jsonl")!
    }

    func test_parsesFixture_returnsExpectedTokenTotals() {
        let batch = ClaudeLogParser().parse(filePath: fixturePath)

        XCTAssertEqual(batch.inputTokens, 11)
        XCTAssertEqual(batch.outputTokens, 1_026)
        XCTAssertEqual(batch.cacheReadTokens, 133_455)
        XCTAssertEqual(batch.cacheWriteTokens, 32_120)
    }

    func test_parsesInlineJSONL() throws {
        let jsonl = "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":100,\"output_tokens\":200,\"cache_read_input_tokens\":50,\"cache_creation_input_tokens\":25}}}\n"
        let tmp = try makeTempDirectory().appendingPathComponent("inline.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 100)
        XCTAssertEqual(batch.outputTokens, 200)
        XCTAssertEqual(batch.cacheReadTokens, 50)
        XCTAssertEqual(batch.cacheWriteTokens, 25)
    }

    func test_emptyFile_returnsZero() throws {
        let tmp = try makeTempDirectory().appendingPathComponent("empty.jsonl")
        try "".write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.totalTokens, 0)
    }

    func test_installedAtFilter_excludesOldEntries() throws {
        let future = Date().addingTimeInterval(3600)
        let jsonl = "{\"type\":\"assistant\",\"timestamp\":\"\(ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200)))\",\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":1}}}\n"
        let tmp = try makeTempDirectory().appendingPathComponent("old.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser(installedAt: future).parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 0, "Entries before installedAt must be excluded")
    }

    func test_malformedLineIsSkippedWhileValidLinesCount() throws {
        let jsonl = """
        not-json
        {"type":"assistant","message":{"usage":{"input_tokens":12,"output_tokens":34}}}
        {"type":"assistant","message":{"usage":{"input_tokens":true,"output_tokens":5}}}

        """
        let tmp = try makeTempDirectory().appendingPathComponent("malformed.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 12)
        XCTAssertEqual(batch.outputTokens, 39)
    }

    func test_parseAllRecursivelyIncludesJSONLAndExcludesOtherFiles() throws {
        let root = try makeTempDirectory()
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "{\"message\":{\"usage\":{\"input_tokens\":1,\"output_tokens\":2}}}\n"
            .write(to: root.appendingPathComponent("root.jsonl"), atomically: true, encoding: .utf8)
        try "{\"message\":{\"usage\":{\"input_tokens\":3,\"output_tokens\":4}}}\n"
            .write(to: nested.appendingPathComponent("nested.jsonl"), atomically: true, encoding: .utf8)
        try "{\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":999}}}\n"
            .write(to: nested.appendingPathComponent("ignored.txt"), atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser(basePath: root.path).parseAll()

        XCTAssertEqual(batch.inputTokens, 4)
        XCTAssertEqual(batch.outputTokens, 6)
    }

    func test_installedAtFilterSkipsMissingTimestampWhenScoped() throws {
        let jsonl = "{\"type\":\"assistant\",\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":1}}}\n"
        let tmp = try makeTempDirectory().appendingPathComponent("missing-timestamp.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser(installedAt: Date()).parse(filePath: tmp.path)

        XCTAssertEqual(batch.totalTokens, 0)
    }

    func test_installedAtFilterSkipsUnparseableTimestampWhenScoped() throws {
        let jsonl = "{\"type\":\"assistant\",\"timestamp\":\"not-a-date\",\"message\":{\"usage\":{\"input_tokens\":999,\"output_tokens\":1}}}\n"
        let tmp = try makeTempDirectory().appendingPathComponent("bad-timestamp.jsonl")
        try jsonl.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = ClaudeLogParser(installedAt: Date()).parse(filePath: tmp.path)

        XCTAssertEqual(batch.totalTokens, 0)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClaudeLogParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
