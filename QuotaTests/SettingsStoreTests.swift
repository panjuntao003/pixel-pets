import XCTest
@testable import Quota

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = SettingsStore(directory: tempDir.path)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_defaults_refreshInterval_is300() {
        XCTAssertEqual(store.settings.refreshIntervalSeconds, 300)
    }

    func test_defaults_enabledProviders_empty_allEnabled() {
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
        XCTAssertTrue(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.gemini))
    }

    func test_enabledProviders_explicitFalseDisables() {
        store.update { $0.enabledProviders["codex"] = false }
        XCTAssertFalse(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
    }

    func test_refreshInterval_roundtrips() {
        store.update { $0.refreshIntervalSeconds = 900 }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 900)
    }

    func test_enabledProviders_roundtrips() {
        store.update { $0.enabledProviders["gemini"] = false }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertFalse(store2.settings.isProviderEnabled(.gemini))
    }

    func test_corruptFile_fallsBackToDefaults() {
        let path = tempDir.appendingPathComponent("settings.json").path
        FileManager.default.createFile(atPath: path, contents: Data("CORRUPT".utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 300)
    }

    func test_oldLegacyJSON_loadsWithNewDefaults() {
        let path = tempDir.appendingPathComponent("settings.json").path
        let json = #"{"hookPort":9000,"hookPermissionAsked":true,"lowQuotaThreshold":50}"#
        FileManager.default.createFile(atPath: path, contents: Data(json.utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 300)
    }
}
