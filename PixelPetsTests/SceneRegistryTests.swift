import XCTest
@testable import PixelPets

final class SceneRegistryTests: XCTestCase {
    func test_allSceneIDsHaveRegisteredScene() {
        let registerable: [ScenePreference] = [
            .spaceStation, .cyberpunkLab, .sciFiQuarters, .underwater
        ]
        for pref in registerable {
            guard let id = pref.sceneID else {
                XCTFail("ScenePreference.\(pref) has no sceneID"); continue
            }
            let scene = SceneRegistry.scene(for: id)
            XCTAssertEqual(scene.id, id, "Scene id mismatch for \(id)")
        }
    }

    func test_randomPreference_returnsNilSceneID() {
        XCTAssertNil(ScenePreference.random.sceneID)
    }

    func test_randomPick_returnsOneOfFourScenes() {
        let picked = SceneRegistry.randomScene()
        let ids = SceneID.allCases
        XCTAssertTrue(ids.contains(picked.id))
    }
}
