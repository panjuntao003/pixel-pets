import Foundation

struct ManifestValidator {
    static func validateAll() {
        let registry = AssetRegistry.shared
        print("--- Manifest Validation Starting ---")
        
        for (_, scene) in registry.scenes {
            validateScene(scene)
        }
        
        for (_, pet) in registry.pets {
            validatePet(pet)
        }
        
        for (_, acc) in registry.accessories {
            validateAccessory(acc)
        }
        
        print("--- Manifest Validation Completed ---")
    }
    
    private static func validateScene(_ scene: SceneAsset) {
        print("Validating Scene: \(scene.id)")
        for (state, layers) in scene.states {
            checkFile(scene.id, "Scenes", layers.bg, "bg (\(state))")
            checkFile(scene.id, "Scenes", layers.mid, "mid (\(state))")
            checkFile(scene.id, "Scenes", layers.floor, "floor (\(state))")
        }
    }
    
    private static func validatePet(_ pet: PetAsset) {
        print("Validating Pet: \(pet.id)")
        for (state, fileName) in pet.states {
            checkFile(pet.id, "Pets", fileName, state)
        }
        
        let requiredAnchors: [AccessoryMountPoint] = [.headTop, .aboveHead]
        for anchor in requiredAnchors {
            if pet.anchors[anchor] == nil {
                print("  [WARN] Missing required anchor: \(anchor.rawValue)")
            }
        }
    }
    
    private static func validateAccessory(_ acc: AccessoryAsset) {
        print("Validating Accessory: \(acc.id)")
        for (state, fileName) in acc.states {
            checkFile(acc.id, "Accessories", fileName, state)
        }
    }
    
    private static func checkFile(_ id: String, _ type: String, _ fileName: String?, _ context: String) {
        guard let fileName = fileName else { return }
        let root = Bundle.main.resourceURL?.appendingPathComponent("Assets/PixelPets/\(type)/\(id)")
        let fileURL = root?.appendingPathComponent(fileName)
        
        if let url = fileURL, !FileManager.default.fileExists(atPath: url.path) {
            print("  [ERROR] File missing: \(fileName) for \(context) at \(url.path)")
        }
    }
}
