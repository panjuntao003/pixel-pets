import SwiftUI

struct UnderwaterScene: HabitatScene {
    let id: SceneID = .underwater
    let displayName = "像素水族箱"

    private let corals: [(x: CGFloat, height: CGFloat, color: String)] = [
        (0.06, 0.28, "E17055"), (0.10, 0.20, "FD79A8"), (0.14, 0.35, "00B894"),
        (0.72, 0.22, "A29BFE"), (0.78, 0.32, "00CEC9"), (0.85, 0.18, "FDCB6E"),
        (0.24, 0.15, "FF7675"), (0.62, 0.25, "6C5CE7"),
    ]

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: "4ECDC4"), Color(hex: "2D8A80"), Color(hex: "1A5F58")]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        for i in 0..<3 {
            let offset = CGFloat((frame + i * 20) % 40) * 0.5
            let y = CGFloat(i + 1) * size.height * 0.08
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: offset, y: y))
                    p.addLine(to: CGPoint(x: size.width * 0.6 + offset, y: y + 4))
                },
                with: .color(.white.opacity(0.12)),
                lineWidth: 1
            )
        }

        for i in 0..<4 {
            let bubbleSeed = i * 73 + 17
            let xFrac = CGFloat(bubbleSeed % 60 + 20) / 100
            let period = 90 + i * 20
            let progress = CGFloat((frame + i * (period / 4)) % period) / CGFloat(period)
            let bubbleY = size.height * (0.9 - progress * 0.9)
            let alpha = 0.3 + 0.4 * (1 - progress)
            let r: CGFloat = i % 2 == 0 ? 3 : 2
            ctx.fill(
                Path(ellipseIn: CGRect(x: xFrac * size.width - r, y: bubbleY - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(alpha))
            )
        }

        let fishProgress = CGFloat(frame % 200) / 200
        if fishProgress < 0.7 {
            let fishX = size.width * (1.1 - fishProgress * 1.4)
            let fishY = size.height * 0.35
            drawPixelFish(ctx, x: fishX, y: fishY)
        }

        ctx.fill(
            Path(CGRect(x: 0, y: size.height * 0.85, width: size.width, height: size.height * 0.15)),
            with: .color(Color(hex: "C4956A").opacity(0.6))
        )

        for coral in corals {
            let x = coral.x * size.width
            let h = coral.height * size.height
            let y = size.height * 0.85 - h
            ctx.fill(
                Path(CGRect(x: x, y: y, width: 6, height: h)),
                with: .color(Color(hex: coral.color))
            )
        }
    }

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        switch state {
        case .typing, .searching, .juggling, .conducting, .fast, .thinking:
            return CGPoint(x: size.width * 0.4, y: size.height * 0.55)
        case .sleeping:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.75)
        default:
            return CGPoint(x: size.width * 0.5, y: size.height * 0.45)
        }
    }

    private func drawPixelFish(_ ctx: GraphicsContext, x: CGFloat, y: CGFloat) {
        let c = Color(hex: "FF9F43")
        ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 14, height: 8)), with: .color(c))
        ctx.fill(
            Path { p in
                p.move(to: CGPoint(x: x + 14, y: y + 4))
                p.addLine(to: CGPoint(x: x + 20, y: y))
                p.addLine(to: CGPoint(x: x + 20, y: y + 8))
                p.closeSubpath()
            },
            with: .color(c)
        )
        ctx.fill(
            Path(ellipseIn: CGRect(x: x + 2, y: y + 2, width: 3, height: 3)),
            with: .color(.black.opacity(0.7))
        )
    }
}
