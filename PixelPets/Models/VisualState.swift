import Foundation

enum SceneState: String, Codable {
    case normal
    case active
    case dim
    case charging
    case alert
    case celebration
}

enum AccessoryState: String, Codable {
    case normal
    case active
}

struct VisualState: Equatable {
    let petState: PetState
    let sceneState: SceneState
    let accessoryState: AccessoryState
    let intensity: Double // 0.0 to 1.0

    init(petState: PetState, sceneState: SceneState, accessoryState: AccessoryState = AccessoryState.normal, intensity: Double = 1.0) {
        self.petState = petState
        self.sceneState = sceneState
        self.accessoryState = accessoryState
        self.intensity = intensity
    }
}
