import SwiftUI

enum QuotaUsageLevel: Equatable {
    case normal
    case low
    case exhausted

    static let lowRemainingPercent: Double = 40
    static let exhaustedRemainingPercent: Double = 10

    init(remainingFraction: Double) {
        let remainingPercent = min(max(remainingFraction, 0), 1) * 100.0
        if remainingPercent < Self.exhaustedRemainingPercent {
            self = .exhausted
        } else if remainingPercent < Self.lowRemainingPercent {
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
