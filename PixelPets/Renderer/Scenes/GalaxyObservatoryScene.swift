import SwiftUI

struct GalaxyObservatoryScene: HabitatScene {
    let id: SceneID = .galaxyObservatory
    let displayName = "银河观测站"
    let sceneDescription = "深空观测与科研场景"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
        // This is handled by HabitatRenderer now, 
        // but we can add a fallback or procedural elements here if we want.
    }

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        // x: 180/360, y: 76/140 -> 0.5, 0.54
        return CGPoint(x: size.width * 0.5, y: size.height * 0.54)
    }
}
