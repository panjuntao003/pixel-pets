import XCTest
@testable import PixelPets

@MainActor
final class AppCoordinatorTests: XCTestCase {

    func test_detectedGeminiPlaceholderWaitsForRealQuota() {
        let result = AppCoordinator.detectedPlaceholderFetchResult(for: .gemini)
        guard case .unavailable(let reason) = result else {
            return XCTFail("Gemini detected placeholder should not expose estimated quota")
        }
        XCTAssertEqual(reason, "正在读取配额")
    }

    func test_detectedOpenCodePlaceholderWaitsForRealQuota() {
        let result = AppCoordinator.detectedPlaceholderFetchResult(for: .opencode)
        guard case .unavailable(let reason) = result else {
            return XCTFail("OpenCode detected placeholder should not expose estimated quota")
        }
        XCTAssertEqual(reason, "正在读取配额")
    }

    func test_allSceneIDs_haveRegisteredScene() {
        for id in SceneID.allCases {
            let scene = SceneRegistry.scene(for: id)
            XCTAssertEqual(scene.id, id, "SceneRegistry missing scene for \(id)")
        }
    }

    func test_randomScene_idBelongsToAllCases() {
        let scene = SceneRegistry.randomScene()
        XCTAssertTrue(SceneID.allCases.contains(scene.id))
    }
}
