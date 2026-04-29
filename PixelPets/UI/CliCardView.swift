import SwiftUI

struct CliCardView: View {
    let info: CliQuotaInfo

    private var displayedTiers: [QuotaTier] {
        let priority = [
            info.tiers.first { ["five_hour", "rolling", "daily"].contains($0.id) },
            info.tiers.first { ["seven_day", "weekly"].contains($0.id) }
        ].compactMap { $0 }

        return priority.isEmpty ? Array(info.tiers.prefix(2)) : priority
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Text(info.id.displayName)
                    .font(.system(size: 12, weight: .semibold))
                if !info.planBadge.isEmpty {
                    Text(info.planBadge)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .separatorColor).opacity(0.5))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            if info.isUnavailable {
                Text(info.unavailableReason ?? "未连接 · 无法读取配额")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(displayedTiers) { tier in
                        QuotaBarView(tier: tier).frame(maxWidth: .infinity)
                    }
                }
            }

            Text("今日 \(fmt(info.todayTokens)) · 本周 \(fmt(info.weekTokens)) tokens")
                .font(.system(size: 9))
                .foregroundStyle(Color(nsColor: .tertiaryLabelColor))
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}
