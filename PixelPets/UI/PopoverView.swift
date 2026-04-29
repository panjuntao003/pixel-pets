import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    var onRefresh: () -> Void = {}
    var onConfigureHooks: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            HabitatView(viewModel: viewModel)
                .environmentObject(settingsStore)

            Divider()
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 4)

            ScrollView {
                if viewModel.visibleClis.isEmpty {
                    EmptyStateView()
                        .padding(20)
                } else {
                    VStack(spacing: 8) {
                        ForEach(viewModel.visibleClis) { info in
                            CliCardView(info: info)
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            HStack {
                Text("累计 \(fmt(viewModel.totalLifetimeTokens)) tokens")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                Spacer()
                Button {
                    onRefresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).help("刷新配额")
                Button {
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).help("设置")
            }.padding(.horizontal, 12).padding(.vertical, 8)
        }.frame(width: 360)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func fmt(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n)/1_000_000) }
        if n >= 1_000     { return String(format: "%.0fK", Double(n)/1_000) }
        return "\(n)"
    }
}

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "powerplug.portrait")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("所有终端已休眠")
                .font(.system(size: 13, weight: .medium))
            Text("在设置中启用至少一个 CLI")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button("打开设置") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
    }
}
