import XCTest
@testable import PixelPets

final class GeminiLogParserTests: XCTestCase {
    var fixturePath: String {
        Bundle(for: Self.self).path(forResource: "gemini_sample", ofType: "json")!
    }

    func test_parsesFixtureWithoutUsageMetadataAsZero() {
        let batch = GeminiLogParser().parse(filePath: fixturePath)

        XCTAssertEqual(batch.inputTokens, 0)
        XCTAssertEqual(batch.outputTokens, 0)
    }

    func test_parsesTopLevelArrayUsageMetadata() throws {
        let json = """
        [
          {"timestamp":"2026-04-28T03:18:54.482Z","usageMetadata":{"promptTokenCount":100,"totalTokenCount":140}},
          {"timestamp":"2026-04-28T03:19:54.482Z","usageMetadata":{"promptTokenCount":20,"totalTokenCount":15}}
        ]
        """
        let tmp = try makeTempDirectory().appendingPathComponent("chat.json")
        try json.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = GeminiLogParser().parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 120)
        XCTAssertEqual(batch.outputTokens, 40)
    }

    func test_parsesMessagesAndHistoryObjects() throws {
        let messages = try makeTempDirectory().appendingPathComponent("messages-chat.json")
        try #"{"messages":[{"usageMetadata":{"promptTokenCount":1,"totalTokenCount":3}}]}"#
            .write(to: messages, atomically: true, encoding: .utf8)
        let history = try makeTempDirectory().appendingPathComponent("history-chat.json")
        try #"{"history":[{"usageMetadata":{"promptTokenCount":4,"totalTokenCount":9}}]}"#
            .write(to: history, atomically: true, encoding: .utf8)

        XCTAssertEqual(GeminiLogParser().parse(filePath: messages.path).inputTokens, 1)
        XCTAssertEqual(GeminiLogParser().parse(filePath: messages.path).outputTokens, 2)
        XCTAssertEqual(GeminiLogParser().parse(filePath: history.path).inputTokens, 4)
        XCTAssertEqual(GeminiLogParser().parse(filePath: history.path).outputTokens, 5)
    }

    func test_parseAllIncludesChatJSONFilesOnly() throws {
        let root = try makeTempDirectory()
        let chats = root.appendingPathComponent("session/chats", isDirectory: true)
        try FileManager.default.createDirectory(at: chats, withIntermediateDirectories: true)
        try #"{"messages":[{"usageMetadata":{"promptTokenCount":10,"totalTokenCount":12}}]}"#
            .write(to: chats.appendingPathComponent("session.json"), atomically: true, encoding: .utf8)
        try #"{"messages":[{"usageMetadata":{"promptTokenCount":99,"totalTokenCount":100}}]}"#
            .write(to: root.appendingPathComponent("other.json"), atomically: true, encoding: .utf8)

        let batch = GeminiLogParser(basePath: root.path).parseAll()

        XCTAssertEqual(batch.inputTokens, 10)
        XCTAssertEqual(batch.outputTokens, 2)
    }

    func test_installedAtFilterSkipsMissingOldAndUnparseableTimestamps() throws {
        let installedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let json = """
        [
          {"usageMetadata":{"promptTokenCount":100,"totalTokenCount":101}},
          {"timestamp":"not-a-date","usageMetadata":{"promptTokenCount":100,"totalTokenCount":101}},
          {"timestamp":"2020-01-01T00:00:00Z","usageMetadata":{"promptTokenCount":100,"totalTokenCount":101}},
          {"timestamp":"2023-11-14T22:14:20Z","usageMetadata":{"promptTokenCount":7,"totalTokenCount":11}}
        ]
        """
        let tmp = try makeTempDirectory().appendingPathComponent("scoped-chat.json")
        try json.write(to: tmp, atomically: true, encoding: .utf8)

        let batch = GeminiLogParser(installedAt: installedAt).parse(filePath: tmp.path)

        XCTAssertEqual(batch.inputTokens, 7)
        XCTAssertEqual(batch.outputTokens, 4)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GeminiLogParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
