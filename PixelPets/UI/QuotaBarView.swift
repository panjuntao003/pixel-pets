import SwiftUI

struct QuotaBarView: View {
    let tier: QuotaTier

    private static let green  = Color(hex: "34C759")
    private static let orange = Color(hex: "FF9500")
    private static let red    = Color(hex: "FF3B30")
    private static let track  = Color(hex: "E5E5EA")

    private var barColor: Color {
        let used = tier.utilization
        if used < 0.5 { return Self.green }
        if used < 0.8 { return Self.orange }
        return Self.red
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
                        .fill(Self.track)
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
