enum AccessorySlot { case top, back, side }

enum Accessory: String, CaseIterable, Codable {
    case sprout, headset, halo, antenna          // top
    case battery, jetpack, cape                  // back
    case minidrone, codecloud                    // side

    var slot: AccessorySlot {
        switch self {
        case .sprout, .headset, .halo, .antenna: return .top
        case .battery, .jetpack, .cape:           return .back
        case .minidrone, .codecloud:              return .side
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
        }
    }
}
