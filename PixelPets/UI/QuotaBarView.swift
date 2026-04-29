import SwiftUI

struct QuotaBarView: View {
    let tier: QuotaTier

    private var barColor: Color {
        let used = tier.utilization
        if used < 0.5 { return AgentPalette.quotaGreen }
        if used < 0.8 { return AgentPalette.quotaOrange }
        return AgentPalette.quotaRed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Text(tier.displayLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
                if tier.isEstimated {
                    Text("~").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AgentPalette.quotaTrack)
                        .frame(height: 4)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(tier.utilization, 1.0), height: 4)
                }
            }
            .frame(height: 4)

            HStack {
                Text("\(Int(tier.utilization * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if tier.resetsAt != nil {
                    Text(tier.resetsInString)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
