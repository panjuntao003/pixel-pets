import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        VStack(spacing: 0) {
            PetDisplayView(viewModel: viewModel)
            Divider()
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(viewModel.visibleClis) { info in CliCardView(info: info) }
                }.padding(12)
            }
            Divider()
            HStack {
                Text("累计 \(fmt(viewModel.totalLifetimeTokens)) tokens")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Button { } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).help("刷新配额")
                Button { } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.frame(width: 360)
    }

    private func fmt(_ n: Int) -> String {
        n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000) : "\(n)"
    }
}
