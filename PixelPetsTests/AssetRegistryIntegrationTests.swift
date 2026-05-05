import XCTest
@testable import PixelPets

/// Integration tests that load the real Assets/PixelPets bundle and verify
/// manifest decoding, production filtering, and file resolution all work
/// end-to-end after the IntSize CodingKeys fix.
///
/// These tests use AssetRegistry.shared, which uses Bundle.main. In the test
/// host context Bundle.main is the PixelPets.app bundle, so real assets are
/// accessible with no stubs needed.
final class AssetRegistryIntegrationTests: XCTestCase {

    // Use the singleton so we test the exact production code path.
    private var registry: AssetRegistry { AssetRegistry.shared }

    // MARK: - Counts

    func test_scenesLoad_atLeastTwoEntries() {
        XCTAssertGreaterThanOrEqual(registry.scenes.count, 2,
            "Expected ≥2 scenes (rooftop_server_garden, underwater_aquarium at minimum)")
    }

    func test_petsLoad_atLeastTwoEntries() {
        XCTAssertGreaterThanOrEqual(registry.pets.count, 2,
            "Expected ≥2 pets (neural_jellyfish, opencode_terminal_bot at minimum)")
    }

    func test_accessoriesLoad_atLeastTwoEntries() {
        XCTAssertGreaterThanOrEqual(registry.accessories.count, 2,
            "Expected ≥2 accessories (halo, code_cloud at minimum)")
    }

    // MARK: - Production filtering (productionReady != false)

    func test_productionScenes_countIsPositive() {
        XCTAssertGreaterThan(registry.productionScenes.count, 0,
            "productionScenes must be non-empty — rooftop_server_garden is productionReady:true")
    }

    func test_productionPets_countIsPositive() {
        XCTAssertGreaterThan(registry.productionPets.count, 0,
            "productionPets must be non-empty — neural_jellyfish is productionReady:true")
    }

    func test_productionAccessories_countIsPositive() {
        XCTAssertGreaterThan(registry.productionAccessories.count, 0,
            "productionAccessories must be non-empty — halo is productionReady:true")
    }

    func test_explicitlyFalseAssetsExcludedFromProduction() {
        XCTAssertNil(registry.productionScenes["repair_workshop"],
                     "repair_workshop is productionReady:false — must not appear in production")
        XCTAssertNil(registry.productionPets["cactus_sprite"],
                     "cactus_sprite is productionReady:false — must not appear in production")
        XCTAssertNil(registry.productionAccessories["battery_backpack"],
                     "battery_backpack is productionReady:false — must not appear in production")
        XCTAssertNil(registry.productionAccessories["retro_antenna"],
                     "retro_antenna is productionReady:false — must not appear in production")
        XCTAssertNil(registry.productionAccessories["sidekick_drone"],
                     "sidekick_drone is productionReady:false — must not appear in production")
    }

    // MARK: - Known production assets resolve correctly

    func test_rooftopServerGarden_loadsByID() {
        XCTAssertNotNil(registry.scenes["rooftop_server_garden"],
                        "rooftop_server_garden (productionReady:true) must be in registry")
    }

    func test_underwaterAquarium_loadsByID() {
        XCTAssertNotNil(registry.scenes["underwater_aquarium"],
                        "underwater_aquarium (productionReady:true) must be in registry")
    }

    func test_neuralJellyfish_loadsByID() {
        XCTAssertNotNil(registry.pets["neural_jellyfish"],
                        "neural_jellyfish (productionReady:true) must be in registry")
    }

    func test_opencodeTerminalBot_loadsByID() {
        XCTAssertNotNil(registry.pets["opencode_terminal_bot"],
                        "opencode_terminal_bot (productionReady:true) must be in registry")
    }

    func test_halo_loadsByID() {
        XCTAssertNotNil(registry.accessories["halo"],
                        "halo (productionReady:true) must be in registry")
    }

    func test_codeCloud_loadsByID() {
        XCTAssertNotNil(registry.accessories["code_cloud"],
                        "code_cloud (productionReady:true) must be in registry")
    }

    // MARK: - Logical sizes decoded correctly (validates IntSize fix)

    func test_rooftopServerGarden_hasCorrectLogicalSize() {
        let scene = registry.scenes["rooftop_server_garden"]
        XCTAssertEqual(scene?.logicalSize.w, 360)
        XCTAssertEqual(scene?.logicalSize.h, 140)
    }

    func test_neuralJellyfish_hasCorrectBaseSize() {
        let pet = registry.pets["neural_jellyfish"]
        XCTAssertEqual(pet?.baseSize.w, 32)
        XCTAssertEqual(pet?.baseSize.h, 32)
    }

    func test_halo_hasCorrectSize() {
        let acc = registry.accessories["halo"]
        XCTAssertEqual(acc?.size.w, 24)
        XCTAssertEqual(acc?.size.h, 16)
    }

    // MARK: - Asset URL resolution (productionReady:true assets only)

    func test_productionScenes_bgURL_resolvesForNormalState() {
        for (id, _) in registry.productionScenes where registry.scenes[id]?.productionReady == true {
            let url = registry.assetURL(forScene: id, layer: "bg", state: .normal)
            XCTAssertNotNil(url, "\(id): bg/normal URL must resolve")
            if let url = url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                              "\(id): bg/normal file missing at \(url.path)")
            }
        }
    }

    func test_productionPets_idleURL_resolves() {
        for (id, _) in registry.productionPets where registry.pets[id]?.productionReady == true {
            let url = registry.assetURL(forPet: id, state: .idle)
            XCTAssertNotNil(url, "\(id): idle URL must resolve")
            if let url = url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                              "\(id): idle file missing at \(url.path)")
            }
        }
    }

    func test_productionAccessories_normalURL_resolves() {
        for (id, _) in registry.productionAccessories where registry.accessories[id]?.productionReady == true {
            let url = registry.assetURL(forAccessory: id, state: .idle)
            XCTAssertNotNil(url, "\(id): normal URL must resolve")
            if let url = url {
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                              "\(id): normal file missing at \(url.path)")
            }
        }
    }

    // MARK: - productionReady:true assets have no declared-but-missing files

    func test_productionScenes_allDeclaredStateFilesExist() {
        for (_, scene) in registry.scenes where scene.productionReady == true {
            for (state, layers) in scene.states {
                for (layer, file) in [("bg", layers.bg), ("floor", layers.floor),
                                      ("mid", layers.mid), ("fxBack", layers.fxBack),
                                      ("fxFront", layers.fxFront)] {
                    guard let file else { continue }
                    let url = Bundle.main.resourceURL?
                        .appendingPathComponent("Assets/PixelPets/Scenes/\(scene.id)/\(file)")
                    if let url = url {
                        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                                      "\(scene.id) [\(state)] \(layer): \(file) missing")
                    }
                }
            }
        }
    }

    func test_productionPets_allDeclaredStateFilesExist() {
        for (_, pet) in registry.pets where pet.productionReady == true {
            for (state, fileName) in pet.states {
                let url = Bundle.main.resourceURL?
                    .appendingPathComponent("Assets/PixelPets/Pets/\(pet.id)/\(fileName)")
                if let url = url {
                    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                                  "\(pet.id) [\(state)]: \(fileName) missing")
                }
            }
        }
    }

    func test_productionAccessories_allDeclaredStateFilesExist() {
        for (_, acc) in registry.accessories where acc.productionReady == true {
            for (state, fileName) in acc.states {
                let url = Bundle.main.resourceURL?
                    .appendingPathComponent("Assets/PixelPets/Accessories/\(acc.id)/\(fileName)")
                if let url = url {
                    XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                                  "\(acc.id) [\(state)]: \(fileName) missing")
                }
            }
        }
    }

    // MARK: - productionReady:true scenes have all required visual states (no fallback)

    func test_productionScenes_haveNormalDimAlert() {
        for (_, scene) in registry.scenes where scene.productionReady == true {
            XCTAssertNotNil(scene.states["normal"],
                            "\(scene.id): production scene must have 'normal' state")
            XCTAssertNotNil(scene.states["dim"],
                            "\(scene.id): production scene must have 'dim' state — fallback not acceptable")
            XCTAssertNotNil(scene.states["alert"],
                            "\(scene.id): production scene must have 'alert' state — fallback not acceptable")
        }
    }

    func test_productionPets_haveAllFourStates() {
        for (_, pet) in registry.pets where pet.productionReady == true {
            for required in ["idle", "thinking", "charging", "error"] {
                XCTAssertNotNil(pet.states[required],
                                "\(pet.id): production pet must have '\(required)' state")
            }
        }
    }
}
