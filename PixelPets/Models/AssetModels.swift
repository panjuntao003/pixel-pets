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
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    var cgSize: CGSize { CGSize(width: width, height: height) }
}

// MARK: - Scene Asset

struct SceneAsset: Identifiable, Codable {
    let id: String
    let name: String
    let logicalSize: IntSize
    let defaultPetPosition: IntPoint
    let safeArea: EdgeInsets
    let states: [String: String] // Mapping state name to background asset name
    let effects: [String]

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
    let anchors: [AccessoryMountPoint: IntPoint]
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
}
