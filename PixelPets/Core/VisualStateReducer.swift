import Foundation

struct VisualStateReducer {
    static func reduce(event: SystemEvent, current: VisualState) -> VisualState {
        switch event {
        case .appIdle:
            return VisualState(petState: PetState.idle, sceneState: SceneState.normal, accessoryState: AccessoryState.normal, intensity: 0.5)
            
        case .userStartedRequest:
            return VisualState(petState: PetState.thinking, sceneState: SceneState.active, accessoryState: AccessoryState.normal, intensity: 0.8)
            
        case .aiThinking:
            return VisualState(petState: PetState.thinking, sceneState: SceneState.active, accessoryState: AccessoryState.active, intensity: 1.0)
            
        case .aiStreaming:
            return VisualState(petState: PetState.typing, sceneState: SceneState.active, accessoryState: AccessoryState.active, intensity: 1.0)
            
        case .requestSucceeded:
            return VisualState(petState: PetState.success, sceneState: SceneState.celebration, accessoryState: AccessoryState.normal, intensity: 1.0)
            
        case .requestFailed:
            return VisualState(petState: PetState.error, sceneState: SceneState.alert, accessoryState: AccessoryState.normal, intensity: 1.0)
            
        case .quotaLow:
            return VisualState(petState: current.petState, sceneState: SceneState.alert, accessoryState: current.accessoryState, intensity: 0.6)
            
        case .quotaResetting:
            return VisualState(petState: PetState.charging, sceneState: SceneState.charging, accessoryState: AccessoryState.normal, intensity: 1.0)
            
        case .quotaRecovered:
            return VisualState(petState: PetState.idle, sceneState: SceneState.normal, accessoryState: AccessoryState.normal, intensity: 1.0)
        }
    }
}
