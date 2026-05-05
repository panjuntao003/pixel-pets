import Foundation
import CoreGraphics

// MARK: - Core Types

struct IntPoint: Codable, Equatable {
    let x: Int
    let y: Int

    init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

struct IntSize: Codable, Equatable {
    let w: Int
    let h: Int

    init(width: Int, height: Int) {
        self.w = width
        self.h = height
    }

    var cgSize: CGSize { CGSize(width: w, height: h) }
}

// MARK: - Scene Asset

struct SceneLayers: Codable, Equatable {
    let bg: String?
    let mid: String?
    let floor: String?
    let fxBack: String?
    let fxFront: String?
}

struct SceneAsset: Identifiable, Codable {
    let id: String
    let name: String
    let logicalSize: IntSize
    let defaultPetPosition: IntPoint
    let safeArea: EdgeInsets
    let states: [String: SceneLayers] // normal, dim, active, charging, alert
    let productionReady: Bool?
    
    struct EdgeInsets: Codable, Equatable {
        let top, bottom, left, right: Int
    }
}

// MARK: - Pet Asset

enum AccessoryMountPoint: String, Codable {
    case headTop
    case aboveHead
    case faceCenter
    case chest
    case back
    case leftSide
    case rightSide
    case feet
}

struct PetAsset: Identifiable, Codable {
    let id: String
    let name: String
    let baseSize: IntSize
    let states: [String: String] // idle, thinking, charging, error, happy, etc.
    let anchors: [AccessoryMountPoint: IntPoint]
    let productionReady: Bool?
}

// MARK: - Accessory Asset

enum AccessoryLayer: String, Codable {
    case back
    case front
    case floating
}

struct AccessoryAsset: Identifiable, Codable {
    let id: String
    let name: String
    let size: IntSize
    let mountPoint: AccessoryMountPoint
    let layer: AccessoryLayer
    let states: [String: String] // normal, active, etc.
    let productionReady: Bool?
    let incompatiblePets: [String]?
}
