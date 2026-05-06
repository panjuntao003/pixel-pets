import XCTest
@testable import PixelPets

@MainActor
final class SettingsStoreTests: XCTestCase {
    private var tempDir: URL!
    private var store: SettingsStore!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hookPermissionAsked")
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        store = SettingsStore(directory: tempDir.path)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "hookPermissionAsked")
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func test_defaults_enabledCLIs_isEmpty() {
        XCTAssertTrue(store.settings.enabledCLIs.isEmpty)
    }

    func test_defaults_hookPort_is15799() {
        XCTAssertEqual(store.settings.hookPort, 15799)
    }

    func test_defaults_scenePreference_isGalaxyObservatory() {
        XCTAssertEqual(store.settings.scenePreference, .galaxyObservatory)
    }

    func test_defaults_equippedAccessories_isEmpty() {
        XCTAssertTrue(store.settings.equippedAccessories.isEmpty)
    }

    func test_defaults_skinOverride_isNil() {
        XCTAssertNil(store.settings.skinOverride)
    }

    func test_update_persistsToDisk() {
        store.update { $0.hookPort = 9000 }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.hookPort, 9000)
    }

    func test_corruptFile_fallsBackToDefaults() {
        let path = tempDir.appendingPathComponent("settings.json").path
        FileManager.default.createFile(atPath: path, contents: Data("CORRUPT".utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.hookPort, 15799)
    }

    func test_enabledCLIs_emptyMeansAllEnabled() {
        for skin in AgentSkin.allCases {
            XCTAssertTrue(store.settings.isEnabled(skin))
        }
    }

    func test_enabledCLIs_explicitFalseDisables() {
        store.update { $0.enabledCLIs[AgentSkin.codex.rawValue] = false }
        XCTAssertFalse(store.settings.isEnabled(.codex))
        XCTAssertTrue(store.settings.isEnabled(.claude))
    }

    func test_hookPermissionAsked_roundtrips() {
        store.update { $0.hookPermissionAsked = true }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertTrue(store2.settings.hookPermissionAsked)
    }

    func test_equippedAccessories_roundtrips() {
        store.update { $0.equippedAccessories["top"] = "sprout" }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.equippedAccessories["top"], "sprout")
    }

    func test_skinOverride_roundtrips() {
        store.update { $0.skinOverride = "claude" }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.skinOverride, "claude")
    }

    func test_skinOverride_nilByDefault_inLegacyJSON() {
        let path = tempDir.appendingPathComponent("settings.json").path
        let json = #"{"hookPort":15799}"#
        FileManager.default.createFile(atPath: path, contents: Data(json.utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertNil(store2.settings.skinOverride)
        XCTAssertTrue(store2.settings.equippedAccessories.isEmpty)
    }

    func test_migratesUserDefaultsHookPermission() {
        UserDefaults.standard.set(true, forKey: "hookPermissionAsked")
        _ = SettingsStore(directory: tempDir.path)
        XCTAssertFalse(
            UserDefaults.standard.bool(forKey: "hookPermissionAsked"),
            "old UserDefaults key should be cleared after migration"
        )
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertTrue(store2.settings.hookPermissionAsked, "migrated value should survive process restart")
    }

    // MARK: - Quota Monitor fields (Phase A)

    func test_defaults_lowQuotaThreshold_is20() {
        XCTAssertEqual(store.settings.lowQuotaThreshold, 20)
    }

    func test_defaults_refreshInterval_is300() {
        XCTAssertEqual(store.settings.refreshIntervalSeconds, 300)
    }

    func test_defaults_enabledProviders_empty_allEnabled() {
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
        XCTAssertTrue(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.gemini))
        XCTAssertTrue(store.settings.isProviderEnabled(.gemini))
    }

    func test_enabledProviders_explicitFalseDisables() {
        store.update { $0.enabledProviders["codex"] = false }
        XCTAssertFalse(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
    }

    func test_lowQuotaThreshold_roundtrips() {
        store.update { $0.lowQuotaThreshold = 30 }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.lowQuotaThreshold, 30)
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

    func test_oldLegacyJSON_loadsWithNewDefaults() {
        let path = tempDir.appendingPathComponent("settings.json").path
        let json = #"{"hookPort":9000,"hookPermissionAsked":true}"#
        _ = FileManager.default.createFile(atPath: path, contents: Data(json.utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        // Old fields preserved
        XCTAssertEqual(store2.settings.hookPort, 9000)
        XCTAssertTrue(store2.settings.hookPermissionAsked)
        // New fields get defaults
        XCTAssertEqual(store2.settings.lowQuotaThreshold, 20)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 300)
    }
}
