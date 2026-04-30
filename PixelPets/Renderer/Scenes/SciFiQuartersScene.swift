import SwiftUI

struct SciFiQuartersScene: HabitatScene {
    let id: SceneID = .sciFiQuarters
    let displayName = "星际生活舱"
    let sceneDescription = "温和休息场景"

    private let nebulaDrift: CGFloat = 0

    func drawBackground(_ ctx: GraphicsContext, size: CGSize, frame: Int) {
        ctx.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [Color(hex: "0A1520"), Color(hex: "060F18")]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: size.height)
            )
        )

        let floorY = size.height * 0.73
        drawIsometricFloor(ctx, size: size, floorY: floorY)

        let winX = size.width * 0.06
        let winY = floorY - 80
        let winW: CGFloat = 90
        let winH: CGFloat = 65
        ctx.fill(
            Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
            with: .color(Color(hex: "001830"))
        )
        ctx.stroke(
            Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
            with: .color(Color(hex: "336699")),
            lineWidth: 1.5
        )

        let drift = CGFloat(frame % 180) / 180
        _ = nebulaDrift
        ctx.drawLayer { inner in
            inner.clip(to: Path(CGRect(x: winX + 1, y: winY + 1, width: winW - 2, height: winH - 2)))
            inner.fill(
                Path(ellipseIn: CGRect(x: winX + 5 + drift * 3, y: winY + 8, width: 40, height: 28)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "FF6B35").opacity(0.7), .clear]),
                    center: CGPoint(x: winX + 25, y: winY + 22),
                    startRadius: 0,
                    endRadius: 25
                )
            )
            inner.fill(
                Path(ellipseIn: CGRect(x: winX + 30, y: winY + 25, width: 28, height: 20)),
                with: .radialGradient(
                    Gradient(colors: [Color(hex: "C0392B").opacity(0.5), .clear]),
                    center: CGPoint(x: winX + 44, y: winY + 35),
                    startRadius: 0,
                    endRadius: 18
                )
            )
        }

        let chargeX = size.width * 0.80
        let chargeY = floorY - 55
        ctx.fill(
            Path(CGRect(x: chargeX, y: chargeY, width: 22, height: 45)),
            with: .color(Color(hex: "0A1830"))
        )
        ctx.stroke(
            Path(CGRect(x: chargeX, y: chargeY, width: 22, height: 45)),
            with: .color(Color(hex: "0066AA")),
            lineWidth: 1
        )

        let breathe = 0.5 + 0.5 * sin(Double(frame) * 0.08)
        ctx.fill(
            Path(ellipseIn: CGRect(x: chargeX + 7, y: chargeY + 6, width: 8, height: 8)),
            with: .color(Color(hex: "00AAFF").opacity(breathe))
        )

        let plantY = floorY - 30 - 2 * sin(Double(frame % 120) / 120 * .pi * 2)
        ctx.fill(
            Path(ellipseIn: CGRect(x: size.width * 0.48, y: plantY - 10, width: 16, height: 12)),
            with: .color(Color(hex: "228B22").opacity(0.8))
        )
        ctx.fill(
            Path(CGRect(x: size.width * 0.50 + 2, y: plantY, width: 3, height: 10)),
            with: .color(Color(hex: "6B8E23"))
        )
    }

    func robotCenter(for state: PetState, in size: CGSize) -> CGPoint {
        let floorY = size.height * 0.73
        switch state {
        case .typing, .searching, .juggling, .conducting, .fast, .thinking:
            return CGPoint(x: size.width * 0.55, y: floorY - 30)
        case .sleeping:
            return CGPoint(x: size.width * 0.82, y: floorY - 22)
        default:
            return CGPoint(x: size.width * 0.22, y: floorY - 28)
        }
    }

    private func drawIsometricFloor(_ ctx: GraphicsContext, size: CGSize, floorY: CGFloat) {
        let tileW: CGFloat = 44
        let tileH: CGFloat = 22
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
            ctx.fill(path, with: .color(Color(hex: "111E2E")))
            ctx.stroke(path, with: .color(Color(hex: "2A4A6A").opacity(0.4)), lineWidth: 0.5)
        }
    }
}
