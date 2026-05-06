import SwiftUI

struct MenuBarDotView: View {
    let status: QuotaStatus
    @State private var pulse = false

    var body: some View {
        Circle()
            .fill(color)
            .opacity(pulses ? (pulse ? 1.0 : 0.65) : 1.0)
            .frame(width: 12, height: 12)
            .onAppear {
                guard pulses else { return }
                withAnimation(.easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
            .onChange(of: status) { _, newStatus in
                pulse = false
                guard newStatus.pulses else { return }
                withAnimation(.easeInOut(duration: newStatus.pulseDuration).repeatForever(autoreverses: true)) {
                    pulse.toggle()
                }
            }
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

    private var pulses: Bool {
        status.pulses
    }

    private var pulseDuration: Double {
        status.pulseDuration
    }
}

private extension QuotaStatus {
    var pulses: Bool {
        switch self {
        case .normal, .low: return true
        case .exhausted, .unavailable, .unknown: return false
        }
    }

    var pulseDuration: Double {
        switch self {
        case .normal: return 2.0
        case .low: return 1.0
        case .exhausted, .unavailable, .unknown: return 0.0
        }
    }
}
