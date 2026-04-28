import XCTest
@testable import PixelPets

final class OpenCodeLogParserTests: XCTestCase {
    var fixturePath: String {
        Bundle(for: Self.self).path(forResource: "opencode_sample", ofType: "json")!
    }

    func test_parseTokenJSONParsesFixture() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: fixturePath))

        let batch = OpenCodeLogParser.parseTokenJSON(data)

        XCTAssertEqual(batch.inputTokens, 12_345)
        XCTAssertEqual(batch.outputTokens, 67_890)
        XCTAssertEqual(batch.cacheReadTokens, 1_000)
        XCTAssertEqual(batch.cacheWriteTokens, 500)
    }

    func test_parseTokenJSONParsesInlineTokens() {
        let data = Data(#"{"tokens":{"input":3,"output":4,"cache":{"read":1,"write":2}}}"#.utf8)

        let batch = OpenCodeLogParser.parseTokenJSON(data)

        XCTAssertEqual(batch.inputTokens, 3)
        XCTAssertEqual(batch.outputTokens, 4)
        XCTAssertEqual(batch.cacheReadTokens, 1)
        XCTAssertEqual(batch.cacheWriteTokens, 2)
    }

    func test_parseTokenJSONSkipsMissingTokens() {
        let batch = OpenCodeLogParser.parseTokenJSON(Data(#"{"message":"hello"}"#.utf8))

        XCTAssertEqual(batch.inputTokens, 0)
        XCTAssertEqual(batch.outputTokens, 0)
    }

    func test_parseAllReturnsZeroWhenDatabaseDoesNotExist() throws {
        let path = try makeTempDirectory().appendingPathComponent("missing.db").path

        let batch = OpenCodeLogParser(dbPath: path).parseAll()

        XCTAssertEqual(batch.totalTokens, 0)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenCodeLogParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
