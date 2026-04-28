import Foundation
import XCTest
@testable import PixelPets

final class GrowthStoreTests: XCTestCase {
    func test_missingValuesReturnDefaults() throws {
        let store = GrowthStore(dbPath: try makeDBPath())

        XCTAssertTrue(store.isAvailable)
        XCTAssertEqual(store.loadTotalTokens(), 0)
        XCTAssertNil(store.loadInstalledAt())
        XCTAssertTrue(store.loadUnlockedAccessories().isEmpty)
        XCTAssertEqual(store.loadCursor(path: "/tmp/missing.log"), 0)
    }

    func test_saveReopenLoadTotalTokens() throws {
        let path = try makeDBPath()
        GrowthStore(dbPath: path).saveTotalTokens(1_234_567)

        XCTAssertEqual(GrowthStore(dbPath: path).loadTotalTokens(), 1_234_567)
    }

    func test_saveReopenLoadInstalledAt() throws {
        let path = try makeDBPath()
        let installedAt = Date(timeIntervalSince1970: 1_700_123_456.25)
        GrowthStore(dbPath: path).saveInstalledAt(installedAt)

        let loaded = try XCTUnwrap(GrowthStore(dbPath: path).loadInstalledAt())
        XCTAssertEqual(loaded.timeIntervalSince1970, installedAt.timeIntervalSince1970, accuracy: 0.001)
    }

    func test_saveReopenLoadUnlockedAccessoriesPreservesOrder() throws {
        let path = try makeDBPath()
        let accessories: [Accessory] = [.halo, .sprout, .battery]
        GrowthStore(dbPath: path).saveUnlockedAccessories(accessories)

        XCTAssertEqual(GrowthStore(dbPath: path).loadUnlockedAccessories(), accessories)
    }

    func test_saveReopenLoadCursorMtime() throws {
        let path = try makeDBPath()
        GrowthStore(dbPath: path).saveCursor(path: "/tmp/pixelpets.log", mtime: 123.456)

        XCTAssertEqual(GrowthStore(dbPath: path).loadCursor(path: "/tmp/pixelpets.log"), 123.456, accuracy: 0.001)
    }

    func test_badPathMarksStoreUnavailable() throws {
        let directory = try makeTempDirectory()
        let store = GrowthStore(dbPath: directory.path)

        XCTAssertFalse(store.isAvailable)
        XCTAssertNotNil(store.lastError)
        XCTAssertEqual(store.loadTotalTokens(), 0)
    }

    private func makeDBPath() throws -> String {
        try makeTempDirectory().appendingPathComponent("pixelpets.db").path
    }

    private func makeTempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GrowthStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
