import SwiftUI

struct CliCardView: View {
    let info: CliQuotaInfo

    private var displayedTiers: [QuotaTier] {
        let prioritized = [
            info.tiers.first { $0.id == "five_hour" || $0.id == "rolling" || $0.id == "daily" },
            info.tiers.first { $0.id == "seven_day" || $0.id == "weekly" }
        ].compactMap { $0 }

        return prioritized.isEmpty ? Array(info.tiers.prefix(2)) : prioritized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(info.id.displayName).font(.system(size: 12, weight: .semibold))
                Spacer()
                if !info.planBadge.isEmpty {
                    Text(info.planBadge)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                }
            }

            if info.isUnavailable {
                Text(info.unavailableReason ?? "未连接 · 无法读取配额")
                    .font(.system(size: 10)).foregroundStyle(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(displayedTiers) { tier in
                        QuotaBarView(tier: tier).frame(maxWidth: .infinity)
                    }
                }
            }

            Text("今日 \(fmt(info.todayTokens)) · 本周 \(fmt(info.weekTokens)) tokens")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}
