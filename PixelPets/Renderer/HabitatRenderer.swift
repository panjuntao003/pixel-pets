import SwiftUI

struct HabitatRenderer: View {
    @ObservedObject var viewModel: PetViewModel
    let currentScene: SceneAsset
    let frame: Int
    let legacyScene: any HabitatScene // Fallback for Phase 1

    var body: some View {
        let state = viewModel.visualState
        
        GeometryReader { geo in
            // 1. Layered Background
            ZStack {
                renderLayer("bg", in: geo.size, state: state.sceneState)
                renderLayer("mid", in: geo.size, state: state.sceneState)
                
                if state.sceneState == .charging {
                    EnergyFlowFX(frame: frame, intensity: state.intensity)
                }
                
                renderLayer("fxBack", in: geo.size, state: state.sceneState)
            }
            .background(
                // Fallback to legacy if no bg layer found
                Canvas { ctx, size in
                    if AssetRegistry.shared.assetURL(forScene: currentScene.id, layer: "bg", state: state.sceneState) == nil {
                        legacyScene.drawBackground(ctx, size: size, frame: frame)
                    }
                }
            )

            // 2. Derive Pet Position
            let center = legacyScene.robotCenter(for: state.petState, in: geo.size)
            let floatOffset: CGFloat = legacyScene.id == .underwater
                ? 3.0 * sin(Double(frame % 40) / 40 * .pi * 2)
                : 0
            let finalY = center.y + floatOffset

            // 3. Render the pet with its anchors
            PetRenderer(
                skin: viewModel.activeSkin,
                state: state.petState,
                frame: frame,
                size: 60,
                equippedAccessories: viewModel.equippedAccessories
            )
            .position(x: center.x, y: finalY)
            
            // 4. Foreground layers
            ZStack {
                if state.petState == .thinking || state.petState == .typing {
                    TypingSparksFX(frame: frame, intensity: state.intensity)
                }
                
                if state.sceneState == .alert {
                    AlertPulseFX(frame: frame, intensity: state.intensity)
                }
                
                renderLayer("fxFront", in: geo.size, state: state.sceneState)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func renderLayer(_ layer: String, in size: CGSize, state: SceneState) -> some View {
        if let url = AssetRegistry.shared.assetURL(forScene: currentScene.id, layer: layer, state: state),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none) // Keep it pixelated
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
        }
    }
}
