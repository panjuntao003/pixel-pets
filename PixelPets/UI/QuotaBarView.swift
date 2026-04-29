import SwiftUI

struct QuotaBarView: View {
    let tier: QuotaTier

    private var barColor: Color {
        if tier.remaining > 0.40 { return AgentPalette.quotaGreen }
        if tier.remaining > 0.10 { return AgentPalette.quotaYellow }
        return AgentPalette.quotaRed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(tier.displayLabel).font(.system(size: 10, weight: .medium))
                if tier.isEstimated {
                    Text("~").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
            Text(tier.resetsInString).font(.system(size: 9)).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 5)
                        Capsule().fill(barColor)
                            .frame(width: geo.size.width * min(tier.remaining, 1.0), height: 5)
                    }
                }.frame(height: 5)
                Text("\(Int(tier.remaining * 100))%")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary).frame(width: 26, alignment: .trailing)
            }
        }
    }
}
