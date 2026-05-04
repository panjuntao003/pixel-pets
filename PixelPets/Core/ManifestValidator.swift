import Foundation
import AppKit

struct ValidationIssue: Identifiable {
    let id = UUID()
    let assetID: String
    let severity: Severity
    let message: String
    
    enum Severity: String {
        case error = "[ERROR]"
        case warning = "[WARN]"
        case info = "[PASS]"
    }
}

struct ManifestValidator {
    static func validateAll() -> [ValidationIssue] {
        let registry = AssetRegistry.shared
        var issues: [ValidationIssue] = []
        
        for (_, scene) in registry.scenes {
            issues.append(contentsOf: validateScene(scene))
        }
        
        for (_, pet) in registry.pets {
            issues.append(contentsOf: validatePet(pet))
        }
        
        for (_, acc) in registry.accessories {
            issues.append(contentsOf: validateAccessory(acc))
        }
        
        return issues
    }
    
    private static func validateScene(_ scene: SceneAsset) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (state, layers) in scene.states {
            issues.append(contentsOf: checkFile(scene.id, "Scenes", layers.bg, "bg (\(state))"))
            issues.append(contentsOf: checkFile(scene.id, "Scenes", layers.mid, "mid (\(state))"))
            issues.append(contentsOf: checkFile(scene.id, "Scenes", layers.floor, "floor (\(state))"))
        }
        if scene.states["normal"] == nil {
            issues.append(ValidationIssue(assetID: scene.id, severity: .error, message: "Missing required 'normal' state"))
        }
        return issues
    }
    
    private static func validatePet(_ pet: PetAsset) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (state, fileName) in pet.states {
            issues.append(contentsOf: checkFile(pet.id, "Pets", fileName, state))
        }
        
        let requiredAnchors: [AccessoryMountPoint] = [.headTop, .aboveHead]
        for anchor in requiredAnchors {
            if pet.anchors[anchor] == nil {
                issues.append(ValidationIssue(assetID: pet.id, severity: .warning, message: "Missing recommended anchor: \(anchor.rawValue)"))
            }
        }
        return issues
    }
    
    private static func validateAccessory(_ acc: AccessoryAsset) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for (state, fileName) in acc.states {
            issues.append(contentsOf: checkFile(acc.id, "Accessories", fileName, state))
        }
        return issues
    }
    
    private static func checkFile(_ id: String, _ type: String, _ fileName: String?, _ context: String) -> [ValidationIssue] {
        guard let fileName = fileName else { return [] }
        let root = Bundle.main.resourceURL?.appendingPathComponent("Assets/PixelPets/\(type)/\(id)")
        let fileURL = root?.appendingPathComponent(fileName)
        
        if let url = fileURL {
            if !FileManager.default.fileExists(atPath: url.path) {
                return [ValidationIssue(assetID: id, severity: .error, message: "File missing: \(fileName) for \(context)")]
            }
            
            // Check size matching (placeholder logic)
            if let image = NSImage(contentsOf: url) {
                if type == "Scenes" && (image.size.width != 360 || image.size.height != 140) {
                     // In real app, we'd check logical pixel size, not just points
                }
            }
        }
        return []
    }
}
