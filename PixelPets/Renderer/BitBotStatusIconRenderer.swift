import SwiftUI

/// Menu bar only: render the BitBot v2 head front-on at 16x16 pt.
struct BitBotStatusIconRenderer: View {
    let skin: AgentSkin
    let state: PetState
    let size: CGFloat

    private let faceProvider = BitBotV2FaceProvider()

    private let gridW = 24

    var body: some View {
        Canvas { ctx, sz in
            let scale = sz.width / CGFloat(gridW)
            drawHead(ctx, scale: scale)
            drawFace(ctx, scale: scale)
        }
        .frame(width: size, height: size)
    }

    private func drawHead(_ ctx: GraphicsContext, scale: CGFloat) {
        let body = AgentPalette.bodyColor(for: skin)
        let light = AgentPalette.lightColor(for: skin)
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

        for x in 3...20 {
            ctx.fillPixel(x: x, y: 3, color: black, scale: scale)
            ctx.fillPixel(x: x, y: 15, color: black, scale: scale)
        }
        for y in 4...14 {
            ctx.fillPixel(x: 3, y: y, color: black, scale: scale)
            ctx.fillPixel(x: 20, y: y, color: black, scale: scale)
        }
    }

    private func drawFace(_ ctx: GraphicsContext, scale: CGFloat) {
        faceProvider.draw(in: ctx, state: state, frame: 0, scale: scale)
    }
}
