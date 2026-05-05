import SwiftUI

@MainActor
final class ProceduralSpriteCache {
    static let shared = ProceduralSpriteCache()

    private let cache = NSCache<NSString, NSImage>()

    func cachedImage(for skin: AgentSkin, state: PetState) -> NSImage? {
        let key = cacheKey(skin: skin, state: state) as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let image = renderProceduralSprite(skin: skin, state: state) else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private func cacheKey(skin: AgentSkin, state: PetState) -> String {
        "\(skin.rawValue)/\(state.rawValue)"
    }

    private func renderProceduralSprite(skin: AgentSkin, state: PetState) -> NSImage? {
        let renderSize: CGFloat = 96
        let view = BitBotV2Renderer(skin: skin, state: state, frame: 0, size: renderSize)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0

        guard let cgImage = renderer.cgImage else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: renderSize, height: renderSize * 28.0 / 24.0))
    }
}
