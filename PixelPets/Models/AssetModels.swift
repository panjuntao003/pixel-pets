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

    // All manifests use "width"/"height". Legacy "w"/"h" is accepted for compatibility.
    // Encoding always produces "width"/"height" so written manifests stay consistent.
    init(from decoder: Decoder) throws {
        enum WidthHeightKeys: String, CodingKey { case width, height }
        enum LegacyKeys: String, CodingKey { case w, h }

        if let c = try? decoder.container(keyedBy: WidthHeightKeys.self),
           let width = try? c.decode(Int.self, forKey: .width),
           let height = try? c.decode(Int.self, forKey: .height) {
            w = width
            h = height
        } else {
            let c = try decoder.container(keyedBy: LegacyKeys.self)
            w = try c.decode(Int.self, forKey: .w)
            h = try c.decode(Int.self, forKey: .h)
        }
    }

    func encode(to encoder: Encoder) throws {
        enum WidthHeightKeys: String, CodingKey { case width, height }
        var c = encoder.container(keyedBy: WidthHeightKeys.self)
        try c.encode(w, forKey: .width)
        try c.encode(h, forKey: .height)
    }
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

    // Swift's JSONDecoder cannot decode [StringEnum: Value] from a JSON object —
    // it treats non-String/Int keyed dictionaries as arrays. We decode anchors as
    // [String: IntPoint] first, then map to the typed enum keys.
    init(from decoder: Decoder) throws {
        enum Keys: String, CodingKey {
            case id, name, baseSize, states, anchors, productionReady
        }
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        baseSize = try c.decode(IntSize.self, forKey: .baseSize)
        states = try c.decode([String: String].self, forKey: .states)
        productionReady = try c.decodeIfPresent(Bool.self, forKey: .productionReady)

        let rawAnchors = try c.decode([String: IntPoint].self, forKey: .anchors)
        anchors = Dictionary(uniqueKeysWithValues: rawAnchors.compactMap { key, point in
            AccessoryMountPoint(rawValue: key).map { ($0, point) }
        })
    }

    func encode(to encoder: Encoder) throws {
        enum Keys: String, CodingKey {
            case id, name, baseSize, states, anchors, productionReady
        }
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(baseSize, forKey: .baseSize)
        try c.encode(states, forKey: .states)
        try c.encodeIfPresent(productionReady, forKey: .productionReady)
        let rawAnchors = Dictionary(uniqueKeysWithValues: anchors.map { ($0.key.rawValue, $0.value) })
        try c.encode(rawAnchors, forKey: .anchors)
    }
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
