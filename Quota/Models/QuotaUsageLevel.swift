import SwiftUI

enum QuotaUsageLevel: Equatable {
    case normal
    case low
    case exhausted

    init(usedFraction: Double) {
        if usedFraction < 0.6 {
            self = .normal
        } else if usedFraction < 0.9 {
            self = .low
        } else {
            self = .exhausted
        }
    }

    var barColor: Color {
        switch self {
        case .normal: return .green
        case .low: return .yellow
        case .exhausted: return .red
        }
    }
}
