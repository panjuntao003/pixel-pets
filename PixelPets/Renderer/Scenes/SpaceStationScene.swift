import SwiftUI

struct SpaceStationScene: HabitatScene {
    let id: SceneID = .spaceStation
    let displayName = "太空站"
    let sceneDescription = "默认科技感场景"

    private static let stars: [(x: CGFloat, y: CGFloat, period: Int)] = [
        (0.07, 0.08, 46), (0.16, 0.22, 63), (0.24, 0.12, 74), (0.31, 0.34, 52),
        (0.39, 0.18, 68), (0.46, 0.05, 41), (0.54, 0.28, 79), (0.61, 0.14, 57),
        (0.68, 0.37, 72), (0.74, 0.09, 49), (0.82, 0.24, 66), (0.91, 0.16, 55),
        (0.12, 0.47, 77), (0.28, 0.53, 44), (0.43, 0.43, 61), (0.57, 0.51, 70),
        (0.72, 0.56, 48), (0.87, 0.45, 76), (0.95, 0.32, 59), (0.35, 0.58, 65),
    ]

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: "050510"), Color(hex: "0A1525")]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        for star in Self.stars {
            let phase = frame % star.period
            let alpha = 0.4 + 0.6 * abs(sin(Double(phase) * .pi / Double(star.period)))
            let pt = CGPoint(x: star.x * size.width, y: star.y * size.height)
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - 1, y: pt.y - 1, width: 2, height: 2)),
                with: .color(.white.opacity(alpha))
            )
        }

        let floorY = size.height * 0.72
        drawIsometricFloor(
            ctx,
            size: size,
            floorY: floorY,
            color1: Color(hex: "1A2A4A"),
            color2: Color(hex: "111E35")
        )

        let termX = size.width * 0.08
        let termY = floorY - 50
        ctx.fill(
            Path(CGRect(x: termX, y: termY, width: 60, height: 40)),
            with: .color(Color(hex: "001A3A"))
        )
        ctx.stroke(
            Path(CGRect(x: termX, y: termY, width: 60, height: 40)),
            with: .color(Color(hex: "0066FF").opacity(0.8)),
            lineWidth: 1
        )

        let scroll = (frame / 4) % 8
        for i in 0..<5 {
            let lineY = termY + 6 + CGFloat((i + scroll) % 8) * 5
            guard lineY < termY + 40 else { continue }
            ctx.fill(
                Path(CGRect(x: termX + 4, y: lineY, width: CGFloat([45, 30, 38, 25, 40][i % 5]), height: 2)),
                with: .color(Color(hex: "00AAFF").opacity(0.6))
            )
        }

        let portX = size.width * 0.78
        let portY = floorY - 65
        let portR: CGFloat = 24
        ctx.fill(
            Path(ellipseIn: CGRect(x: portX - portR, y: portY - portR, width: portR * 2, height: portR * 2)),
            with: .color(Color(hex: "000510"))
        )
        ctx.stroke(
            Path(ellipseIn: CGRect(x: portX - portR, y: portY - portR, width: portR * 2, height: portR * 2)),
            with: .color(Color(hex: "223355")),
            lineWidth: 2
        )

        let planetOffset = CGFloat(frame % 300) / 300
        ctx.fill(
            Path(ellipseIn: CGRect(x: portX - 12 + planetOffset * 2, y: portY - 10, width: 20, height: 18)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: "4A90D9"), Color(hex: "1A5FA0")]),
                startPoint: CGPoint(x: portX - 10, y: portY - 10),
                endPoint: CGPoint(x: portX + 10, y: portY + 10)
            )
        )
    }

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        let floorY = size.height * 0.72
        switch state {
        case .typing, .searching, .juggling, .conducting, .fast, .thinking:
            return CGPoint(x: size.width * 0.32, y: floorY - 30)
        case .sleeping:
            return CGPoint(x: size.width * 0.82, y: floorY - 20)
        default:
            return CGPoint(x: size.width * 0.5, y: floorY - 28)
        }
    }

    private func drawIsometricFloor(
        _ ctx: GraphicsContext,
        size: CGSize,
        floorY: CGFloat,
        color1: Color,
        color2: Color
    ) {
        let tileW: CGFloat = 40
        let tileH: CGFloat = 20
        let cols = Int(size.width / tileW) + 2
        for col in -1...cols {
            let x = CGFloat(col) * tileW
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: floorY))
                p.addLine(to: CGPoint(x: x + tileW / 2, y: floorY - tileH / 2))
                p.addLine(to: CGPoint(x: x + tileW, y: floorY))
                p.addLine(to: CGPoint(x: x + tileW / 2, y: floorY + tileH / 2))
                p.closeSubpath()
            }
            ctx.fill(path, with: .color(col % 2 == 0 ? color1 : color2))
            ctx.stroke(path, with: .color(Color(hex: "2A4A6A").opacity(0.5)), lineWidth: 0.5)
        }
    }
}
