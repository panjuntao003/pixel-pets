import SwiftUI

struct PetRenderer: View {
    let skin: AgentSkin
    let state: PetState
    let frame: Int
    let size: CGFloat
    let equippedAccessories: [Accessory]

    // Default BitBotV2 logical size
    private let logicalW: CGFloat = 24
    private let logicalH: CGFloat = 28

    // Define anchors for the current BitBotV2 body
    private var anchors: [AccessoryMountPoint: CGPoint] {
        let scale = size / logicalW
        return [
            .headTop: CGPoint(x: 12 * scale, y: 2 * scale),
            .aboveHead: CGPoint(x: 12 * scale, y: -4 * scale),
            .faceCenter: CGPoint(x: 12 * scale, y: 9 * scale),
            .chest: CGPoint(x: 12 * scale, y: 20 * scale),
            .back: CGPoint(x: 20 * scale, y: 18 * scale),
            .leftSide: CGPoint(x: 0 * scale, y: 16 * scale),
            .rightSide: CGPoint(x: 24 * scale, y: 16 * scale)
        ]
    }

    var body: some View {
        ZStack {
            // 1. Back Accessories
            renderAccessories(in: .back)

            // 2. Main Pet Body
            BitBotV2Renderer(
                skin: skin,
                state: state,
                frame: frame,
                size: size
            )

            // 3. Front Accessories
            renderAccessories(in: .front)

            // 4. Floating Accessories
            renderAccessories(in: .floating)
        }
        .frame(width: size, height: size * logicalH / logicalW)
    }

    @ViewBuilder
    private func renderAccessories(in layer: AccessoryLayer) -> some View {
        ForEach(equippedAccessories, id: \.self) { accessory in
            let asset = asset(for: accessory)
            if asset.layer == layer, let anchor = anchors[asset.mountPoint] {
                AccessoryRenderer(
                    accessory: accessory,
                    asset: asset,
                    state: state,
                    frame: frame,
                    scale: size / logicalW
                )
                .position(x: anchor.x, y: anchor.y)
            }
        }
    }

    // Temporary mapping to mock assets
    private func asset(for accessory: Accessory) -> AccessoryAsset {
        switch accessory {
        case .halo:
            return AccessoryAsset(id: "halo", name: "Halo", size: IntSize(width: 24, height: 16), mountPoint: .aboveHead, layer: .floating)
        case .antenna:
            return AccessoryAsset(id: "antenna", name: "Antenna", size: IntSize(width: 16, height: 24), mountPoint: .headTop, layer: .front)
        case .sprout:
            return AccessoryAsset(id: "sprout", name: "Sprout", size: IntSize(width: 16, height: 16), mountPoint: .headTop, layer: .front)
        case .battery:
            return AccessoryAsset(id: "battery", name: "Battery", size: IntSize(width: 20, height: 20), mountPoint: .back, layer: .back)
        default:
            return AccessoryAsset(id: "unknown", name: "Unknown", size: IntSize(width: 16, height: 16), mountPoint: .headTop, layer: .front)
        }
    }
}

// Temporary Accessory Renderer
struct AccessoryRenderer: View {
    let accessory: Accessory
    let asset: AccessoryAsset
    let state: PetState
    let frame: Int
    let scale: CGFloat

    var body: some View {
        Canvas { ctx, sz in
            // For now, just draw a placeholder box to verify anchors
            let rect = CGRect(origin: .zero, size: sz)
            
            switch accessory {
            case .halo:
                let floatY = sin(Double(frame) * 0.1) * 2.0
                let path = Path(ellipseIn: CGRect(x: 2, y: 2 + floatY, width: sz.width - 4, height: 8))
                ctx.stroke(path, with: .color(.yellow), lineWidth: 2 * scale)
            case .antenna:
                ctx.fill(Path(CGRect(x: sz.width/2 - 1, y: 0, width: 2, height: sz.height)), with: .color(.gray))
                ctx.fill(Path(ellipseIn: CGRect(x: sz.width/2 - 3, y: 0, width: 6, height: 6)), with: .color(.red))
            case .sprout:
                ctx.fill(Path(CGRect(x: sz.width/2 - 1, y: sz.height - 4, width: 2, height: 4)), with: .color(.green))
                ctx.fill(Path(ellipseIn: CGRect(x: sz.width/2 - 4, y: sz.height - 8, width: 4, height: 4)), with: .color(.green))
                ctx.fill(Path(ellipseIn: CGRect(x: sz.width/2 + 0, y: sz.height - 8, width: 4, height: 4)), with: .color(.green))
            case .battery:
                ctx.fill(Path(CGRect(origin: .zero, size: sz)), with: .color(.gray))
                ctx.fill(Path(CGRect(x: 2, y: 2, width: sz.width - 4, height: sz.height - 4)), with: .color(.green))
            default:
                ctx.fill(Path(rect), with: .color(.purple.opacity(0.5)))
                ctx.stroke(Path(rect), with: .color(.black), lineWidth: 1)
            }
        }
        .frame(width: CGFloat(asset.size.width) * scale, height: CGFloat(asset.size.height) * scale)
    }
}
