import SwiftUI

struct CyberpunkLabScene: HabitatScene {
    let id: SceneID = .cyberpunkLab
    let displayName = "赛博朋克实验室"
    let sceneDescription = "高能工作场景"

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "08000F")))

        ctx.drawLayer { inner in
            inner.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "FF00FF").opacity(0.12), .clear]),
                    center: CGPoint(x: size.width * 0.2, y: size.height * 0.5),
                    startRadius: 0,
                    endRadius: size.width * 0.5
                )
            )
            inner.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "00FFFF").opacity(0.10), .clear]),
                    center: CGPoint(x: size.width * 0.8, y: size.height * 0.4),
                    startRadius: 0,
                    endRadius: size.width * 0.4
                )
            )
        }

        let floorY = size.height * 0.74
        drawIsometricFloor(ctx, size: size, floorY: floorY)

        let signX = size.width * 0.06
        let signY = floorY - 55
        let signFlicker = (frame % 47) > 40
        let signColor = signFlicker ? Color(hex: "FF00FF").opacity(0.3) : Color(hex: "FF00FF")
        ctx.stroke(
            Path(CGRect(x: signX, y: signY, width: 55, height: 14)),
            with: .color(signColor),
            lineWidth: 1.5
        )

        let rackX = size.width * 0.78
        let rackY = floorY - 65
        ctx.fill(
            Path(CGRect(x: rackX, y: rackY, width: 30, height: 55)),
            with: .color(Color(hex: "0A0A1A"))
        )
        ctx.stroke(
            Path(CGRect(x: rackX, y: rackY, width: 30, height: 55)),
            with: .color(Color(hex: "00FFFF").opacity(0.2)),
            lineWidth: 0.5
        )

        let indicatorColors = [Color(hex: "00FFFF"), Color(hex: "FF00FF"), Color(hex: "00FFFF")]
        for row in 0..<3 {
            let phase = (frame / 12 + row) % 3
            let y = rackY + 10 + CGFloat(row) * 15
            let color = indicatorColors[row].opacity(phase == 0 ? 1.0 : 0.2)
            ctx.fill(
                Path(ellipseIn: CGRect(x: rackX + 8, y: y, width: 5, height: 5)),
                with: .color(color)
            )
        }

        let diskX = size.width * 0.45
        let diskY = floorY - 8
        let diskPhase = CGFloat(frame % 30) / 30
        let diskAlpha = 0.3 + 0.3 * sin(diskPhase * .pi * 2)
        ctx.stroke(
            Path(ellipseIn: CGRect(x: diskX - 20, y: diskY - 6, width: 40, height: 12)),
            with: .color(Color(hex: "9900FF").opacity(diskAlpha)),
            lineWidth: 1
        )
    }

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        let floorY = size.height * 0.74
        switch state {
        case .typing, .searching, .juggling, .conducting, .fast, .thinking:
            return CGPoint(x: size.width * 0.45, y: floorY - 28)
        case .sleeping:
            return CGPoint(x: size.width * 0.12, y: floorY - 20)
        default:
            return CGPoint(x: size.width * 0.62, y: floorY - 28)
        }
    }

    private func drawIsometricFloor(_ ctx: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let tileW: CGFloat = 36
        let tileH: CGFloat = 18
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
            ctx.fill(path, with: .color(Color(hex: "110018")))
            ctx.stroke(path, with: .color(Color(hex: "440044").opacity(0.6)), lineWidth: 0.5)
        }

        for i in 0..<3 {
            let x = size.width * CGFloat(i + 1) / 4
            ctx.stroke(
                Path { p in
                    p.move(to: CGPoint(x: x - 20, y: floorY - 5))
                    p.addLine(to: CGPoint(x: x + 20, y: floorY + 5))
                },
                with: .color(Color(hex: "FF00FF").opacity(0.08)),
                lineWidth: 1
            )
        }
    }
}
