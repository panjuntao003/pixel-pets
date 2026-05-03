import Foundation

enum SceneState: String, Codable {
    case normal
    case active
    case dim
    case charging
    case alert
    case celebration
}

struct VisualState: Equatable {
    let petState: PetState
    let sceneState: SceneState

    init(petState: PetState, sceneState: SceneState) {
        self.petState = petState
        self.sceneState = sceneState
    }
}
