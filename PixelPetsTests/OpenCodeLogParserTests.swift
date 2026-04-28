import XCTest
import SQLite3
@testable import PixelPets

private let testSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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

    func test_parseAllReadsTokenRowsFromSQLitePartTable() throws {
        let dbPath = try makeTempDirectory().appendingPathComponent("opencode.db").path
        try makeDatabase(at: dbPath) { db in
            try insertPart(data: #"{"tokens":{"input":10,"output":20,"cache":{"read":3,"write":4}}}"#, timeCreated: 1_700_000_001_000, into: db)
            try insertPart(data: #"{"message":"no tokens"}"#, timeCreated: 1_700_000_002_000, into: db)
            try insertPart(data: #"not-json tokens"#, timeCreated: 1_700_000_003_000, into: db)
            try insertPart(data: #"{"tokens":{"input":5,"output":6,"cache":{"read":1,"write":2}}}"#, timeCreated: 1_700_000_004_000, into: db)
        }

        let batch = OpenCodeLogParser(dbPath: dbPath).parseAll()

        XCTAssertEqual(batch.inputTokens, 15)
        XCTAssertEqual(batch.outputTokens, 26)
        XCTAssertEqual(batch.cacheReadTokens, 4)
        XCTAssertEqual(batch.cacheWriteTokens, 6)
    }

    func test_parseAllAppliesInstalledAtMillisecondFilter() throws {
        let dbPath = try makeTempDirectory().appendingPathComponent("opencode.db").path
        let installedAt = Date(timeIntervalSince1970: 1_700_000_000)
        try makeDatabase(at: dbPath) { db in
            try insertPart(data: #"{"tokens":{"input":99,"output":99,"cache":{"read":99,"write":99}}}"#, timeCreated: 1_699_999_999_999, into: db)
            try insertPart(data: #"{"tokens":{"input":7,"output":8,"cache":{"read":2,"write":3}}}"#, timeCreated: 1_700_000_000_000, into: db)
            try insertPart(data: #"{"tokens":{"input":11,"output":13,"cache":{"read":5,"write":6}}}"#, timeCreated: 1_700_000_001_000, into: db)
        }

        let batch = OpenCodeLogParser(dbPath: dbPath, installedAt: installedAt).parseAll()

        XCTAssertEqual(batch.inputTokens, 18)
        XCTAssertEqual(batch.outputTokens, 21)
        XCTAssertEqual(batch.cacheReadTokens, 7)
        XCTAssertEqual(batch.cacheWriteTokens, 9)
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("OpenCodeLogParserTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeDatabase(at path: String, seed: (OpaquePointer) throws -> Void) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(path, &db), SQLITE_OK)
        guard let db else {
            XCTFail("Expected SQLite database to open")
            return
        }
        defer {
            sqlite3_close(db)
        }

        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE part(data TEXT, time_created INTEGER)", nil, nil, nil), SQLITE_OK)
        try seed(db)
    }

    private func insertPart(data: String, timeCreated: Int64, into db: OpaquePointer) throws {
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, "INSERT INTO part(data, time_created) VALUES (?, ?)", -1, &statement, nil), SQLITE_OK)
        guard let statement else {
            XCTFail("Expected insert statement to prepare")
            return
        }
        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_text(statement, 1, data, -1, testSQLiteTransient)
        sqlite3_bind_int64(statement, 2, timeCreated)
        XCTAssertEqual(sqlite3_step(statement), SQLITE_DONE)
    }
}
