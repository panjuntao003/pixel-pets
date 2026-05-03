import SwiftUI

struct BitBotV2FaceProvider: FaceProvider {
    private static let screenX = 3...20
    private static let screenY = 4...14

    private static let green = Color(hex: "00FF88")
    private static let yellow = Color(hex: "FFD700")
    private static let blue = Color(hex: "5DADE2")
    private static let red = Color(hex: "FF3B30")
    private static let gray = Color(hex: "888888")
    private static let dark = Color(hex: "1A1A2E")

    func draw(in ctx: GraphicsContext, state: PetState, frame: Int, scale: CGFloat) {
        for y in Self.screenY {
            for x in Self.screenX {
                ctx.fillPixel(x: x, y: y, color: Self.dark, scale: scale)
            }
        }

        switch state {
        case .idle:
            drawIdle(ctx, frame: frame, scale: scale)
        case .thinking:
            drawThinking(ctx, frame: frame, scale: scale)
        case .typing, .searching, .juggling, .conducting, .fast:
            drawWorking(ctx, frame: frame, scale: scale)
        case .success, .evolving:
            drawCelebrating(ctx, frame: frame, scale: scale)
        case .error:
            drawError(ctx, frame: frame, scale: scale)
        case .sleeping, .auth:
            drawSleep(ctx, frame: frame, scale: scale)
        case .charging:
            drawWorking(ctx, frame: frame, scale: scale)
        case .quotaLow:
            drawError(ctx, frame: frame, scale: scale) // Use alert/error eyes for now
        }
    }

    private func drawIdle(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let blink = (frame % 60) > 56
        if blink {
            for x in 7...9 {
                ctx.fillPixel(x: x, y: 7, color: Self.yellow, scale: scale)
            }
            for x in 13...15 {
                ctx.fillPixel(x: x, y: 7, color: Self.yellow, scale: scale)
            }
        } else {
            for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
                ctx.fillPixel(x: 7 + dx, y: 6 + dy, color: Self.yellow, scale: scale)
                ctx.fillPixel(x: 14 + dx, y: 6 + dy, color: Self.yellow, scale: scale)
            }
        }

        for x in 9...14 {
            ctx.fillPixel(x: x, y: 11, color: Self.yellow, scale: scale)
        }
        ctx.fillPixel(x: 8, y: 10, color: Self.yellow, scale: scale)
        ctx.fillPixel(x: 15, y: 10, color: Self.yellow, scale: scale)
    }

    private func drawThinking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
            ctx.fillPixel(x: 7 + dx, y: 6 + dy, color: Self.blue, scale: scale)
            ctx.fillPixel(x: 14 + dx, y: 6 + dy, color: Self.blue, scale: scale)
        }

        let dotX = [9, 12, 15]
        for (i, x) in dotX.enumerated() {
            let phase = (frame / 8 + i) % 3
            let alpha = phase == 0 ? 1.0 : (phase == 1 ? 0.5 : 0.2)
            ctx.fillPixel(x: x, y: 11, color: Self.blue.opacity(alpha), scale: scale)
        }
    }

    private func drawWorking(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let pulse = (frame % 16) < 8 ? 1.0 : 0.7
        for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)] {
            ctx.fillPixel(x: 7 + dx, y: 6 + dy, color: Self.green.opacity(pulse), scale: scale)
            ctx.fillPixel(x: 14 + dx, y: 6 + dy, color: Self.green.opacity(pulse), scale: scale)
        }

        let scroll = frame % 12
        for row in 0..<3 {
            let y = 9 + row
            let width = [14, 10, 12][row]
            let offset = (scroll + row * 4) % 6
            for x in (3 + offset)..<(3 + offset + width) where x <= 20 {
                ctx.fillPixel(x: x, y: y, color: Self.green.opacity(0.4), scale: scale)
            }
        }
    }

    private func drawCelebrating(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let starPts1: [(Int, Int)] = [(7, 6), (9, 6), (8, 7), (7, 8), (9, 8)]
        let starPts2: [(Int, Int)] = [(14, 6), (16, 6), (15, 7), (14, 8), (16, 8)]
        for (x, y) in starPts1 {
            ctx.fillPixel(x: x, y: y, color: Self.yellow, scale: scale)
        }
        for (x, y) in starPts2 {
            ctx.fillPixel(x: x, y: y, color: Self.yellow, scale: scale)
        }

        for x in 8...15 {
            ctx.fillPixel(x: x, y: 12, color: Self.yellow, scale: scale)
        }
        ctx.fillPixel(x: 7, y: 11, color: Self.yellow, scale: scale)
        ctx.fillPixel(x: 16, y: 11, color: Self.yellow, scale: scale)
        ctx.fillPixel(x: 7, y: 10, color: Self.yellow, scale: scale)
        ctx.fillPixel(x: 16, y: 10, color: Self.yellow, scale: scale)
    }

    private func drawError(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let color = (frame % 10) < 5 ? Self.red : Self.red.opacity(0.4)
        let x1pts: [(Int, Int)] = [(7, 6), (9, 8), (8, 7), (9, 6), (7, 8)]
        let x2pts: [(Int, Int)] = [(14, 6), (16, 8), (15, 7), (16, 6), (14, 8)]
        for (x, y) in x1pts {
            ctx.fillPixel(x: x, y: y, color: color, scale: scale)
        }
        for (x, y) in x2pts {
            ctx.fillPixel(x: x, y: y, color: color, scale: scale)
        }
    }

    private func drawSleep(_ ctx: GraphicsContext, frame: Int, scale: CGFloat) {
        let dim = Self.gray.opacity(0.7)
        for x in 7...9 {
            ctx.fillPixel(x: x, y: 7, color: dim, scale: scale)
        }
        for x in 13...15 {
            ctx.fillPixel(x: x, y: 7, color: dim, scale: scale)
        }

        let zAlpha = 0.3 + 0.3 * abs(sin(Double(frame) * 0.05))
        ctx.fillPixel(x: 18, y: 5, color: Self.gray.opacity(zAlpha), scale: scale)
        ctx.fillPixel(x: 19, y: 5, color: Self.gray.opacity(zAlpha * 0.7), scale: scale)
    }
}
