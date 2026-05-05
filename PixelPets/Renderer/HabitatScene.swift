import SwiftUI

enum SceneID: String, CaseIterable, Codable {
    case spaceStation = "space_station"
    case cyberpunkLab = "cyberpunk_lab"
    case sciFiQuarters = "scifi_quarters"
    case underwater = "underwater"
    case galaxyObservatory = "galaxy_observatory"
}

extension ScenePreference {
    var sceneID: SceneID? {
        switch self {
        case .random: return nil
        case .spaceStation: return .spaceStation
        case .cyberpunkLab: return .cyberpunkLab
        case .sciFiQuarters: return .sciFiQuarters
        case .underwater: return .underwater
        case .galaxyObservatory: return .galaxyObservatory
        }
    }
}

extension SceneID {
    var emoji: String {
        switch self {
        case .spaceStation: return "🚀"
        case .cyberpunkLab: return "🔬"
        case .sciFiQuarters: return "🛏"
        case .underwater: return "🐠"
        case .galaxyObservatory: return "🌌"
        }
    }
}

protocol HabitatScene {
    var id: SceneID { get }
    var displayName: String { get }
    var sceneDescription: String { get }
    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int)
    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint
}

struct SceneRegistry {
    static func scene(for id: SceneID) -> any HabitatScene {
        switch id {
        case .spaceStation: return SpaceStationScene()
        case .cyberpunkLab: return CyberpunkLabScene()
        case .sciFiQuarters: return SciFiQuartersScene()
        case .underwater: return UnderwaterScene()
        case .galaxyObservatory: return GalaxyObservatoryScene()
        }
    }

    static func randomScene() -> any HabitatScene {
        let productionIDs = AssetRegistry.shared.productionScenes.keys
        let availableIDs = SceneID.allCases.filter { productionIDs.contains($0.rawValue) }
        
        if let randomID = availableIDs.randomElement() {
            return scene(for: randomID)
        }
        // Fallback to space station if no production scenes found (unlikely)
        return scene(for: SceneID.spaceStation)
    }

    static func scene(for preference: ScenePreference) -> any HabitatScene {
        if let id = preference.sceneID {
            return scene(for: id)
        }
        return randomScene()
    }
}
