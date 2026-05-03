import SwiftUI

struct HabitatRenderer: View {
    @ObservedObject var viewModel: PetViewModel
    let currentScene: SceneAsset
    let frame: Int
    let legacyScene: any HabitatScene // Fallback for Phase 1

    var body: some View {
        GeometryReader { geo in
            // 1. Layered Background
            ZStack {
                renderLayer("bg", in: geo.size)
                renderLayer("mid", in: geo.size)
                renderLayer("fxBack", in: geo.size)
            }
            .background(
                // Fallback to legacy if no bg layer found
                Canvas { ctx, size in
                    if AssetRegistry.shared.assetURL(forScene: currentScene.id, layer: "bg", state: sceneState) == nil {
                        legacyScene.drawBackground(ctx, size: size, frame: frame)
                    }
                }
            )

            // 2. Derive Pet Position
            let center = legacyScene.robotCenter(for: viewModel.state, in: geo.size)
            let floatOffset: CGFloat = legacyScene.id == .underwater
                ? 3.0 * sin(Double(frame % 40) / 40 * .pi * 2)
                : 0
            let finalY = center.y + floatOffset

            // 3. Render the pet with its anchors
            PetRenderer(
                skin: viewModel.activeSkin,
                state: viewModel.state,
                frame: frame,
                size: 60,
                equippedAccessories: viewModel.equippedAccessories
            )
            .position(x: center.x, y: finalY)
            
            // 4. Foreground layers
            ZStack {
                renderLayer("fxFront", in: geo.size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var sceneState: SceneState {
        // Derive scene state from pet state for now
        switch viewModel.state {
        case .sleeping: return .dim
        case .error: return .alert
        case .thinking, .typing, .searching: return .active
        default: return .normal
        }
    }
    
    @ViewBuilder
    private func renderLayer(_ layer: String, in size: CGSize) -> some View {
        if let url = AssetRegistry.shared.assetURL(forScene: currentScene.id, layer: layer, state: sceneState),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none) // Keep it pixelated
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        }
    }
}
