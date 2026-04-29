import SwiftUI

struct BitBotV2Renderer: View {
    let skin: AgentSkin
    let state: PetState
    let frame: Int
    let size: CGFloat

    private let faceProvider = BitBotV2FaceProvider()
    private let W = 24
    private let H = 28

    var body: some View {
        Canvas { ctx, sz in
            let scale = sz.width / CGFloat(W)
            drawBody(ctx, scale: scale)
            drawFace(ctx, scale: scale)
            drawFX(ctx, scale: scale)
        }
        .frame(width: size, height: size * CGFloat(H) / CGFloat(W))
    }

    private func drawBody(_ ctx: GraphicsContext, scale: CGFloat) {
        let body = AgentPalette.bodyColor(for: skin)
        let light = AgentPalette.lightColor(for: skin)
        let shadow = AgentPalette.shadowColor(for: skin)
        let antenna = AgentPalette.antenna
        let black = Color.black

        for y in 4...6 {
            ctx.fillPixel(x: 0, y: y, color: antenna, scale: scale)
            ctx.fillPixel(x: 1, y: y, color: antenna, scale: scale)
            ctx.fillPixel(x: 22, y: y, color: antenna, scale: scale)
            ctx.fillPixel(x: 23, y: y, color: antenna, scale: scale)
        }

        for y in 1...17 {
            for x in 2...21 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
        }

        for x in 2...21 {
            ctx.fillPixel(x: x, y: 0, color: black, scale: scale)
            ctx.fillPixel(x: x, y: 17, color: black, scale: scale)
        }
        for y in 1...17 {
            ctx.fillPixel(x: 2, y: y, color: black, scale: scale)
            ctx.fillPixel(x: 21, y: y, color: black, scale: scale)
        }

        for (x, y) in [(3, 2), (4, 2), (3, 3)] {
            ctx.fillPixel(x: x, y: y, color: light, scale: scale)
        }
        for (x, y) in [(19, 15), (20, 14), (20, 15)] {
            ctx.fillPixel(x: x, y: y, color: shadow, scale: scale)
        }

        for x in 3...20 {
            ctx.fillPixel(x: x, y: 3, color: black, scale: scale)
            ctx.fillPixel(x: x, y: 15, color: black, scale: scale)
        }
        for y in 4...14 {
            ctx.fillPixel(x: 3, y: y, color: black, scale: scale)
            ctx.fillPixel(x: 20, y: y, color: black, scale: scale)
        }

        for y in 18...23 {
            for x in 5...18 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
        }
        for x in 5...18 {
            ctx.fillPixel(x: x, y: 23, color: black, scale: scale)
        }
        for y in 18...23 {
            ctx.fillPixel(x: 5, y: y, color: black, scale: scale)
            ctx.fillPixel(x: 18, y: y, color: black, scale: scale)
        }

        for y in 18...21 {
            for x in 2...4 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
            for x in 19...21 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
        }

        for y in 24...27 {
            for x in 7...9 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
            for x in 14...16 {
                ctx.fillPixel(x: x, y: y, color: body, scale: scale)
            }
        }
        for x in 7...9 {
            ctx.fillPixel(x: x, y: 27, color: black, scale: scale)
        }
        for x in 14...16 {
            ctx.fillPixel(x: x, y: 27, color: black, scale: scale)
        }
    }

    private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
        faceProvider.draw(in: ctx, state: state, frame: frame, scale: scale)
    }

    private func drawFX(_ ctx: GraphicsContext, scale: CGFloat) {
        guard state == .success || state == .evolving else { return }

        let phase = frame % 30
        guard phase < 15 else { return }

        let progress = CGFloat(phase) / 15
        let offsets: [(CGFloat, CGFloat)] = [(-3, -1), (3, -1), (-2, -3), (2, -3)]
        for (dx, dy) in offsets {
            let x = Int(12 + dx * progress * 3)
            let y = Int(0 + dy * progress * 2)
            guard x >= 0 && x < W && y >= 0 else { continue }
            ctx.fillPixel(x: x, y: y, color: Color(hex: "FFD700"), scale: scale)
        }
    }
}
