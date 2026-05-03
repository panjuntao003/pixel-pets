import Foundation

final class AssetRegistry {
    static let shared = AssetRegistry()
    
    private(set) var scenes: [String: SceneAsset] = [:]
    private(set) var pets: [String: PetAsset] = [:]
    private(set) var accessories: [String: AccessoryAsset] = [:]
    
    private let fileManager = FileManager.default
    private let assetsRoot: URL
    
    init() {
        // Assets/PixelPets/
        self.assetsRoot = Bundle.main.resourceURL?
            .appendingPathComponent("Assets/PixelPets") ?? URL(fileURLWithPath: "/tmp")
        loadAll()
    }
    
    func loadAll() {
        loadScenes()
        loadPets()
        loadAccessories()
    }
    
    private func loadScenes() {
        let scenesDir = assetsRoot.appendingPathComponent("Scenes")
        guard let items = try? fileManager.contentsOfDirectory(at: scenesDir, includingPropertiesForKeys: nil) else { return }
        
        for dir in items {
            let manifestURL = dir.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestURL),
               let asset = try? JSONDecoder().decode(SceneAsset.self, from: data) {
                scenes[asset.id] = asset
            }
        }
    }
    
    private func loadPets() {
        let petsDir = assetsRoot.appendingPathComponent("Pets")
        guard let items = try? fileManager.contentsOfDirectory(at: petsDir, includingPropertiesForKeys: nil) else { return }
        
        for dir in items {
            let manifestURL = dir.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestURL),
               let asset = try? JSONDecoder().decode(PetAsset.self, from: data) {
                pets[asset.id] = asset
            }
        }
    }
    
    private func loadAccessories() {
        let accDir = assetsRoot.appendingPathComponent("Accessories")
        guard let items = try? fileManager.contentsOfDirectory(at: accDir, includingPropertiesForKeys: nil) else { return }
        
        for dir in items {
            let manifestURL = dir.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifestURL),
               let asset = try? JSONDecoder().decode(AccessoryAsset.self, from: data) {
                accessories[asset.id] = asset
            }
        }
    }

    // Asset Resolution
    func assetURL(forScene sceneID: String, layer: String, state: SceneState) -> URL? {
        guard let scene = scenes[sceneID] else { return nil }
        
        // Try specific state, then fallback to normal
        let stateKeys = [state.rawValue, "normal"]
        for key in stateKeys {
            if let layers = scene.states[key],
               let fileName = getLayerFileName(layers, layer) {
                return assetsRoot.appendingPathComponent("Scenes/\(sceneID)/\(fileName)")
            }
        }
        return nil
    }

    func assetURL(forPet petID: String, state: PetState) -> URL? {
        guard let pet = pets[petID] else { return nil }
        
        let stateKeys = [state.rawValue, "idle"]
        for key in stateKeys {
            if let fileName = pet.states[key] {
                return assetsRoot.appendingPathComponent("Pets/\(petID)/\(fileName)")
            }
        }
        return nil
    }

    func assetURL(forAccessory accID: String, state: PetState) -> URL? {
        guard let acc = accessories[accID] else { return nil }
        
        // Map pet state to accessory state
        let accState = (state == .thinking || state == .fast) ? "active" : "normal"
        let stateKeys = [accState, "normal"]
        
        for key in stateKeys {
            if let fileName = acc.states[key] {
                return assetsRoot.appendingPathComponent("Accessories/\(accID)/\(fileName)")
            }
        }
        return nil
    }

    private func getLayerFileName(_ layers: SceneLayers, _ layer: String) -> String? {
        switch layer {
        case "bg": return layers.bg
        case "mid": return layers.mid
        case "floor": return layers.floor
        case "fxBack": return layers.fxBack
        case "fxFront": return layers.fxFront
        default: return nil
        }
    }
}
