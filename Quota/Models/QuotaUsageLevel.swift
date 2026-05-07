import SwiftUI

enum QuotaUsageLevel: Equatable {
    case normal
    case low
    case exhausted

    init(usedFraction: Double, lowQuotaThreshold: Int) {
        let usedPercent = min(max(usedFraction, 0), 1) * 100.0
        let lowUsagePercent = 100.0 - Double(lowQuotaThreshold)
        if usedPercent >= 100.0 {
            self = .exhausted
        } else if usedPercent + 0.0001 >= lowUsagePercent {
            self = .low
        } else {
            self = .normal
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
