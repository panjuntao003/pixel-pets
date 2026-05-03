import SwiftUI

struct PetRenderer: View {
    let skin: AgentSkin
    let state: PetState
    let frame: Int
    let size: CGFloat
    let equippedAccessories: [Accessory]

    private var petAsset: PetAsset? {
        let assetID: String = (skin == .claude) ? "nebula_bot" : skin.rawValue
        return AssetRegistry.shared.pets[assetID]
    }

    private var anchors: [AccessoryMountPoint: CGPoint] {
        let baseWidth: CGFloat = getBaseWidth()
        let scale: CGFloat = size / baseWidth
        
        guard let asset = petAsset else {
            return [
                .headTop: CGPoint(x: 12.0 * scale, y: 2.0 * scale),
                .aboveHead: CGPoint(x: 12.0 * scale, y: -4.0 * scale),
                .faceCenter: CGPoint(x: 12.0 * scale, y: 9.0 * scale),
                .chest: CGPoint(x: 12.0 * scale, y: 20.0 * scale),
                .back: CGPoint(x: 20.0 * scale, y: 18.0 * scale),
                .leftSide: CGPoint(x: 0.0 * scale, y: 16.0 * scale),
                .rightSide: CGPoint(x: 24.0 * scale, y: 16.0 * scale)
            ]
        }
        
        var points: [AccessoryMountPoint: CGPoint] = [:]
        for (point, anchor) in asset.anchors {
            let px: CGFloat = CGFloat(anchor.x) * scale
            let py: CGFloat = CGFloat(anchor.y) * scale
            points[point] = CGPoint(x: px, y: py)
        }
        return points
    }

    private func getBaseWidth() -> CGFloat {
        if let asset = petAsset {
            return CGFloat(asset.baseSize.w)
        }
        return 24.0
    }

    private func getBaseHeight() -> CGFloat {
        if let asset = petAsset {
            return CGFloat(asset.baseSize.h)
        }
        return 28.0
    }

    var body: some View {
        let petWidth: CGFloat = getBaseWidth()
        let petHeight: CGFloat = getBaseHeight()
        let ratio: CGFloat = petHeight / petWidth
        let containerHeight: CGFloat = size * ratio
        
        return ZStack {
            renderAccessories(in: .back)
            petBodyView
            renderAccessories(in: .front)
            renderAccessories(in: .floating)
        }
        .frame(width: size, height: containerHeight)
    }

    @ViewBuilder
    private var petBodyView: some View {
        if let asset = petAsset,
           let url = AssetRegistry.shared.assetURL(forPet: asset.id, state: state),
           let image = NSImage(contentsOf: url) {
            let w = CGFloat(asset.baseSize.w)
            let h = CGFloat(asset.baseSize.h)
            let r = h / w
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size * r)
        } else {
            procedureFallback
        }
    }

    private var procedureFallback: some View {
        BitBotV2Renderer(
            skin: skin,
            state: state,
            frame: frame,
            size: size
        )
    }

    @ViewBuilder
    private func renderAccessories(in layer: AccessoryLayer) -> some View {
        let baseW: CGFloat = getBaseWidth()
        let accessoryScale: CGFloat = size / baseW
        let currentAnchors = self.anchors
        
        ForEach(equippedAccessories, id: \.self) { accessory in
            let asset = resolveAccessoryAsset(for: accessory)
            if asset.layer == layer, let anchor = currentAnchors[asset.mountPoint] {
                AccessoryRenderer(
                    accessory: accessory,
                    asset: asset,
                    state: state,
                    frame: frame,
                    scale: accessoryScale
                )
                .position(x: anchor.x, y: anchor.y)
            }
        }
    }

    private func resolveAccessoryAsset(for accessory: Accessory) -> AccessoryAsset {
        if let asset = AssetRegistry.shared.accessories[accessory.rawValue] {
            return asset
        }
        // Fallback mock (kept for transition)
        switch accessory {
        case .halo:
            return AccessoryAsset(id: "halo", name: "Halo", size: IntSize(width: 24, height: 16), mountPoint: .aboveHead, layer: .floating, states: ["normal": "normal.png"])
        case .antenna:
            return AccessoryAsset(id: "antenna", name: "Antenna", size: IntSize(width: 16, height: 24), mountPoint: .headTop, layer: .front, states: ["normal": "normal.png"])
        default:
            return AccessoryAsset(id: "unknown", name: "Unknown", size: IntSize(width: 16, height: 16), mountPoint: .headTop, layer: .front, states: [:])
        }
    }
}

struct AccessoryRenderer: View {
    let accessory: Accessory
    let asset: AccessoryAsset
    let state: PetState
    let frame: Int
    let scale: CGFloat

    var body: some View {
        if let url = AssetRegistry.shared.assetURL(forAccessory: asset.id, state: state),
           let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: CGFloat(asset.size.w) * scale, height: CGFloat(asset.size.h) * scale)
        } else {
            procedureFallback
        }
    }

    private var procedureFallback: some View {
        Canvas { ctx, sz in
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
        .frame(width: CGFloat(asset.size.w) * scale, height: CGFloat(asset.size.h) * scale)
    }
}
