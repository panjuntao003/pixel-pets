import SwiftUI

enum SceneID: String, CaseIterable, Codable {
    case spaceStation = "space_station"
    case cyberpunkLab = "cyberpunk_lab"
    case sciFiQuarters = "scifi_quarters"
    case underwater = "underwater"
}

extension ScenePreference {
    var sceneID: SceneID? {
        switch self {
        case .random: return nil
        case .spaceStation: return .spaceStation
        case .cyberpunkLab: return .cyberpunkLab
        case .sciFiQuarters: return .sciFiQuarters
        case .underwater: return .underwater
        }
    }
}

protocol HabitatScene {
    var id: SceneID { get }
    var displayName: String { get }
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
        }
    }

    static func randomScene() -> any HabitatScene {
        scene(for: SceneID.allCases.randomElement()!)
    }

    static func scene(for preference: ScenePreference) -> any HabitatScene {
        if let id = preference.sceneID {
            return scene(for: id)
        }
        return randomScene()
    }
}

struct SpaceStationScene: HabitatScene {
    let id: SceneID = .spaceStation
    let displayName = "太空站"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

struct CyberpunkLabScene: HabitatScene {
    let id: SceneID = .cyberpunkLab
    let displayName = "赛博朋克实验室"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

struct SciFiQuartersScene: HabitatScene {
    let id: SceneID = .sciFiQuarters
    let displayName = "星际生活舱"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
}

struct UnderwaterScene: HabitatScene {
    let id: SceneID = .underwater
    let displayName = "像素水族箱"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {}

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width / 2, y: size.height / 2)
    }
}
