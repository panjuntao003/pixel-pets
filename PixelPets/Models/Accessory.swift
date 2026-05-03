enum AccessorySlot: String, CaseIterable { case top, back, side }

enum Accessory: String, CaseIterable, Codable {
    case sprout, headset, halo, antenna          // top
    case bubbleHelmet                            // top
    case battery, jetpack, cape                  // back
    case minidrone, codecloud                    // side
    case errorPatch, tokenCube                   // side

    var slot: AccessorySlot {
        switch self {
        case .sprout, .headset, .halo, .antenna, .bubbleHelmet: return .top
        case .battery, .jetpack, .cape:           return .back
        case .minidrone, .codecloud, .errorPatch, .tokenCube: return .side
        }
    }

    var tokenThreshold: Int {
        switch self {
        case .sprout:    return 500_000
        case .battery:   return 2_000_000
        case .minidrone: return 5_000_000
        case .halo:      return 10_000_000
        case .headset:   return 3_000_000
        case .jetpack:   return 8_000_000
        case .cape:      return 15_000_000
        case .antenna:   return 20_000_000
        case .codecloud: return 12_000_000
        case .errorPatch: return 1_000_000
        case .bubbleHelmet: return 4_000_000
        case .tokenCube: return 6_000_000
        }
    }
}

extension AccessorySlot {
    var displayName: String {
        switch self {
        case .top: return "头顶"
        case .back: return "背部"
        case .side: return "旁边"
        }
    }
}

extension Accessory {
    var emoji: String {
        switch self {
        case .sprout: return "🌱"
        case .headset: return "🎧"
        case .halo: return "😇"
        case .antenna: return "📡"
        case .battery: return "🔋"
        case .jetpack: return "🚀"
        case .cape: return "🧣"
        case .minidrone: return "🛸"
        case .codecloud: return "☁️"
        case .errorPatch: return "🩹"
        case .bubbleHelmet: return "🤿"
        case .tokenCube: return "🧊"
        }
    }

    var displayName: String {
        switch self {
        case .sprout: return "Sprout"
        case .headset: return "Headset"
        case .halo: return "Halo"
        case .antenna: return "Antenna"
        case .battery: return "Battery"
        case .jetpack: return "Jetpack"
        case .cape: return "Cape"
        case .minidrone: return "Drone"
        case .codecloud: return "Cloud"
        case .errorPatch: return "Patch"
        case .bubbleHelmet: return "Helmet"
        case .tokenCube: return "Cube"
        }
    }
}
