import XCTest
@testable import PixelPets

@MainActor
final class AccessorySlotTests: XCTestCase {
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

    func test_equip_setsSlot() {
        store.update { $0.equippedAccessories[AccessorySlot.top.rawValue] = Accessory.sprout.rawValue }
        XCTAssertEqual(store.settings.equippedAccessories["top"], "sprout")
    }

    func test_unequip_removesSlot() {
        store.update { $0.equippedAccessories["top"] = "sprout" }
        store.update { $0.equippedAccessories.removeValue(forKey: "top") }
        XCTAssertNil(store.settings.equippedAccessories["top"])
    }

    func test_equip_replacesExistingInSameSlot() {
        store.update { $0.equippedAccessories["top"] = "sprout" }
        store.update { $0.equippedAccessories["top"] = "headset" }
        XCTAssertEqual(store.settings.equippedAccessories["top"], "headset")
    }

    func test_equip_multipleSlots() {
        store.update {
            $0.equippedAccessories["top"] = "sprout"
            $0.equippedAccessories["back"] = "battery"
            $0.equippedAccessories["side"] = "minidrone"
        }
        XCTAssertEqual(store.settings.equippedAccessories.count, 3)
    }
}
