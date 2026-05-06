import SwiftUI

struct MenuBarDotView: View {
    let status: QuotaStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }

    var color: Color {
        switch status {
        case .normal:    return .green
        case .low:       return .yellow
        case .exhausted: return .red
        case .unavailable: return .gray
        case .unknown:   return .gray.opacity(0.5)
        }
    }

    var tooltip: String {
        switch status {
        case .normal:    return "All quotas normal"
        case .low:       return "Low quota"
        case .exhausted: return "Quota exhausted"
        case .unavailable: return "No providers available"
        case .unknown:   return "Checking..."
        }
    }
}
