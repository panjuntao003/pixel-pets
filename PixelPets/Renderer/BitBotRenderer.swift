import SwiftUI

struct BitBotRenderer: View {
    @ObservedObject var viewModel: PetViewModel
    let size: CGFloat
    let frame: Int
    var faceProvider: FaceProvider = BitBotFaceProvider()

    var body: some View {
        Canvas { ctx, sz in
            let scale = sz.width / 16.0
            drawSkin(ctx, scale: scale)
            drawShading(ctx, scale: scale)
            drawBody(ctx, scale: scale)
            drawFace(ctx, scale: scale)
            drawAccessories(ctx, scale: scale)
            drawFX(ctx, scale: scale)
        }
        .frame(width: size, height: size)
    }

    // Layer 1: Agent skin fill
    private func drawSkin(_ ctx: GraphicsContext, scale: CGFloat) {
        let color: Color
        switch viewModel.activeSkin {
        case .claude:   color = AgentPalette.claude
        case .opencode: color = AgentPalette.opencode
        case .gemini:   color = AgentPalette.claude    // P1: proper gradient
        case .codex:    color = AgentPalette.codexTop  // P1: proper gradient
        }
        for y in 0..<16 { for x in 0..<16 {
            guard isBody(x: x, y: y) else { continue }
            ctx.fillPixel(x: x, y: y, color: color, scale: scale)
        }}
    }

    // Layer 2: Shading (1px highlight top-left, shadow bottom-right)
    private func drawShading(_ ctx: GraphicsContext, scale: CGFloat) {
        for (x,y) in [(2,2),(3,2),(2,3)] {
            ctx.fillPixel(x: x, y: y, color: .white.opacity(0.2), scale: scale)
        }
        for (x,y) in [(12,13),(13,12),(13,13)] {
            ctx.fillPixel(x: x, y: y, color: .black.opacity(0.2), scale: scale)
        }
    }

    // Layer 3: Outline + screen border + legs
    private func drawBody(_ ctx: GraphicsContext, scale: CGFloat) {
        let c = AgentPalette.outline
        for x in 1..<15 { ctx.fillPixel(x: x, y: 0, color: c, scale: scale)
                           ctx.fillPixel(x: x, y: 15, color: c, scale: scale) }
        for y in 1..<15 { ctx.fillPixel(x: 0, y: y, color: c, scale: scale)
                           ctx.fillPixel(x: 15, y: y, color: c, scale: scale) }
        // Screen border rows 5–10, cols 3–12
        for x in 3..<13 { ctx.fillPixel(x: x, y: 5, color: c, scale: scale)
                           ctx.fillPixel(x: x, y: 10, color: c, scale: scale) }
        for y in 6..<10 { ctx.fillPixel(x: 3, y: y, color: c, scale: scale)
                           ctx.fillPixel(x: 12, y: y, color: c, scale: scale) }
        // Legs
        ctx.fillPixel(x: 5, y: 14, color: c, scale: scale)
        ctx.fillPixel(x: 10, y: 14, color: c, scale: scale)
    }

    // Layer 4: Face (screen content)
    private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
        // Screen fill
        for y in 6..<10 { for x in 4..<12 {
            ctx.fillPixel(x: x, y: y, color: AgentPalette.screen, scale: scale)
        }}
        faceProvider.draw(in: ctx, state: viewModel.state, frame: frame, scale: scale)
    }

    // Layer 5: Accessories
    private func drawAccessories(_ ctx: GraphicsContext, scale: CGFloat) {
        if viewModel.accessories.contains(.sprout) { drawSprout(ctx, scale: scale) }
    }

    private func drawSprout(_ ctx: GraphicsContext, scale: CGFloat) {
        ctx.fillPixel(x: 8, y: 1, color: Color(hex: "5A8A2A"), scale: scale)
        ctx.fillPixel(x: 7, y: 0, color: Color(hex: "34A853"), scale: scale)
    }

    // Layer 6: FX (placeholder, P1)
    private func drawFX(_ ctx: GraphicsContext, scale: CGFloat) { }

    private func isBody(x: Int, y: Int) -> Bool {
        !((x == 0 || x == 15) && (y == 0 || y == 15))
    }
}
