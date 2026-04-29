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

    func test_defaults_scenePreference_isRandom() {
        XCTAssertEqual(store.settings.scenePreference, .random)
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
}
