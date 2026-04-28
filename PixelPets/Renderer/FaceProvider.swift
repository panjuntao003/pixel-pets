import SwiftUI

protocol FaceProvider {
    func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat)
}

extension GraphicsContext {
    func fillPixel(x: Int, y: Int, color: Color, scale: CGFloat) {
        fill(Path(CGRect(x: CGFloat(x)*scale, y: CGFloat(y)*scale,
                         width: scale, height: scale)),
             with: .color(color))
    }
}

struct BitBotFaceProvider: FaceProvider {
    func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat) {
        switch state {
        case .idle:      drawIdle(ctx, frame: frame, scale: scale)
        case .thinking:  drawThinking(ctx, frame: frame, scale: scale)
        case .typing:    drawTyping(ctx, frame: frame, scale: scale)
        case .success:   drawSuccess(ctx, scale: scale)
        case .error:     drawError(ctx, frame: frame, scale: scale)
        case .sleeping:  drawSleeping(ctx, frame: frame, scale: scale)
        case .auth:      drawAuth(ctx, frame: frame, scale: scale)
        default:         drawIdle(ctx, frame: frame, scale: scale)
        }
    }

    private func drawIdle(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let blink = (frame % 60) < 55
        let eye = Color(hex: "333333")
        let y = blink ? 7 : 8
        ctx.fillPixel(x: 5, y: y, color: eye, scale: scale)
        ctx.fillPixel(x: 9, y: y, color: eye, scale: scale)
    }

    private func drawThinking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let col = Color(hex: "4285F4")
        let scan = (frame / 2) % 8
        for x in 0..<8 {
            ctx.fillPixel(x: x+4, y: 7, color: col.opacity(x == scan ? 1.0 : 0.3), scale: scale)
        }
    }

    private func drawTyping(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let col = Color(hex: "333333")
        let shift = (frame / 3) % 3
        for x in [4+shift, 6+shift, 8+shift] where x < 12 {
            ctx.fillPixel(x: x, y: 7, color: col, scale: scale)
            ctx.fillPixel(x: x, y: 8, color: col, scale: scale)
        }
    }

    private func drawSuccess(_ ctx: GraphicsContext, scale: CGFloat) {
        let c = Color(hex: "333333")
        for (x,y) in [(5,6),(9,6),(4,7),(10,7)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
        for x in 5..<10 { ctx.fillPixel(x: x, y: 9, color: c, scale: scale) }
    }

    private func drawError(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let col = (frame%10 < 5) ? Color(hex:"EA4335") : Color(hex:"333333")
        for (x,y) in [(4,6),(6,8),(6,6),(4,8),(8,6),(10,8),(10,6),(8,8)] {
            ctx.fillPixel(x: x, y: y, color: col, scale: scale)
        }
    }

    private func drawSleeping(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let c = Color(hex: "888888")
        for (x,y) in [(4,8),(5,8),(8,8),(9,8)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
    }

    private func drawAuth(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let pulse = 0.6 + 0.4 * abs(sin(Double(frame) * 0.1))
        let c = Color(hex: "FBBC05").opacity(pulse)
        for (x,y) in [(6,5),(7,5),(5,6),(8,6)] { ctx.fillPixel(x: x, y: y, color: c, scale: scale) }
        for y in 7..<10 { for x in 5..<9 { ctx.fillPixel(x: x, y: y, color: c, scale: scale) } }
    }
}
