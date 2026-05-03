import SwiftUI

struct HabitatRenderer: View {
    @ObservedObject var viewModel: PetViewModel
    let currentScene: SceneAsset
    let frame: Int
    let legacyScene: any HabitatScene // Fallback for Phase 1

    var body: some View {
        GeometryReader { geo in
            // 1. Background (Legacy for now, we'll replace later)
            Canvas { ctx, size in
                legacyScene.drawBackground(ctx, size: size, frame: frame)
            }

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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
