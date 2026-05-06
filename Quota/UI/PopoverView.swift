import AppKit
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @ObservedObject var stateStore: QuotaStateStore
    var onRefresh: () -> Void = {}

    private var enabledProviders: [AIProvider] {
        settingsStore.settings.providerOrder
            .compactMap(AIProvider.init(rawValue:))
            .filter { $0 != .unknown && settingsStore.settings.isProviderEnabled($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Quota Monitor")
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 12)
                .padding(.bottom, 8)

            if enabledProviders.isEmpty {
                noProvidersView
            } else {
                VStack(spacing: 8) {
                    ForEach(enabledProviders, id: \.self) { provider in
                        QuotaCardView(
                            provider: provider,
                            snapshot: stateStore.snapshot(for: provider)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                if let refreshedAt = stateStore.lastRefreshAt {
                    Text("Refreshed \(relativeTime(from: refreshedAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Refresh quotas")
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Settings")

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.system(size: 12))
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Quit Quota")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private var noProvidersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No providers enabled")
                .font(.system(size: 13, weight: .medium))
            Text("Enable at least one provider in Settings")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Button {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(#selector(NSApplication.showSettingsWindow(_:)), to: nil, from: nil)
            } label: {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }

    private func relativeTime(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60)) min ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}
