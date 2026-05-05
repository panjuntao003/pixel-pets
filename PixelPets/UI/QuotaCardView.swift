import SwiftUI

struct QuotaCardView: View {
    let provider: AIProvider
    let snapshot: ProviderQuotaSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            if let snapshot {
                if let percent = snapshot.remainingPercent, snapshot.status != .unavailable {
                    Text("\(Int(percent))% remaining")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                statusLabel(for: snapshot)

                if let resetAt = snapshot.resetAt, snapshot.status != .unavailable {
                    Text(resetAtDisplay(resetAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(timeDisplay(for: snapshot))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Not checked yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusLabel(for snapshot: ProviderQuotaSnapshot) -> some View {
        switch snapshot.status {
        case .normal:
            Text("Normal").font(.system(size: 12)).foregroundStyle(.green)
        case .low:
            Text("Low").font(.system(size: 12)).foregroundStyle(.yellow)
        case .exhausted:
            Text("Exhausted").font(.system(size: 12)).foregroundStyle(.red)
        case .unavailable:
            Text(snapshot.message ?? "Unavailable").font(.system(size: 12)).foregroundStyle(.secondary)
        case .unknown:
            Text("Unknown").font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch snapshot?.status {
        case .normal:    return .green
        case .low:       return .yellow
        case .exhausted: return .red
        case .unavailable: return .gray
        case .unknown, .none: return .gray.opacity(0.5)
        }
    }

    private func resetAtDisplay(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Resetting..." }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h >= 24 { return "Resets in \(h/24)d \(h%24)h" }
        if h > 0 { return "Resets in \(h)h \(m)m" }
        return "Resets in \(m)m"
    }

    private func timeDisplay(for snapshot: ProviderQuotaSnapshot) -> String {
        if let successAt = snapshot.lastSuccessfulAt {
            return "Updated \(relativeTime(from: successAt))"
        } else {
            return "Last checked \(relativeTime(from: snapshot.lastCheckedAt))"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60)) min ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}
