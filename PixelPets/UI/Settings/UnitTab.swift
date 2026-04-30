import SwiftUI

struct UnitTab: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var selectedSkin: AgentSkin = .claude

    var body: some View {
        VStack(spacing: 12) {
            skinGrid
            detailCard
        }
        .padding()
        .onAppear {
            selectedSkin = viewModel.activeSkin
        }
        .onReceive(viewModel.$activeSkin) { activeSkin in
            guard settingsStore.settings.skinOverride == nil else { return }
            selectedSkin = activeSkin
        }
    }

    private var skinGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(AgentSkin.allCases, id: \.self) { skin in
                SkinCard(
                    skin: skin,
                    status: skinStatus(skin),
                    isSelected: selectedSkin == skin
                )
                .onTapGesture {
                    selectSkin(skin)
                }
            }
        }
    }

    private var detailCard: some View {
        HStack(spacing: 12) {
            BitBotV2Renderer(skin: selectedSkin, state: .idle, frame: 0, size: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text(selectedSkin.displayName)
                    .font(.headline)
                Text(selectedSkin.personalityTag)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Lv.\(viewModel.level) · \(formatTokens(viewModel.totalLifetimeTokens)) tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if settingsStore.settings.skinOverride != nil {
                HStack(spacing: 8) {
                    if selectedSkin == viewModel.activeSkin {
                        activeIndicator
                    } else if isSelectable(selectedSkin) {
                        setCurrentButton
                    }

                    autoFollowButton
                }
            } else if selectedSkin == viewModel.activeSkin {
                activeIndicator
            } else {
                setCurrentButton
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var activeIndicator: some View {
        Text("使用中")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green.opacity(0.12), in: Capsule())
    }

    private var autoFollowButton: some View {
        Button("自动跟随") {
            settingsStore.update {
                $0.skinOverride = nil
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var setCurrentButton: some View {
        Button("设为当前") {
            viewModel.activeSkin = selectedSkin
            settingsStore.update {
                $0.skinOverride = selectedSkin.rawValue
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func skinStatus(_ skin: AgentSkin) -> SkinStatus {
        guard settingsStore.settings.isEnabled(skin) else {
            return .disabled
        }

        guard viewModel.cliInfos.first(where: { $0.id == skin })?.isDetected == true else {
            return .notFound
        }

        if settingsStore.settings.skinOverride == nil, skin == viewModel.activeSkin {
            return .active
        }

        return .detected
    }

    private func selectSkin(_ skin: AgentSkin) {
        if isSelectable(skin) {
            selectedSkin = skin
        }
    }

    private func isSelectable(_ skin: AgentSkin) -> Bool {
        switch skinStatus(skin) {
        case .active, .detected:
            return true
        case .disabled, .notFound:
            return false
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        }
        if tokens >= 1_000 {
            return String(format: "%.0fK", Double(tokens) / 1_000)
        }
        return "\(tokens)"
    }
}

private enum SkinStatus {
    case active, detected, disabled, notFound

    var label: String {
        switch self {
        case .active: return "● 运行中"
        case .detected: return "○ 已检测"
        case .disabled: return "已停用"
        case .notFound: return "未检测"
        }
    }

    var color: Color {
        switch self {
        case .active: return .green
        case .detected, .disabled: return .secondary
        case .notFound: return .secondary.opacity(0.5)
        }
    }
}

private struct SkinCard: View {
    let skin: AgentSkin
    let status: SkinStatus
    let isSelected: Bool

    private var isUnavailable: Bool {
        status == .disabled || status == .notFound
    }

    var body: some View {
        VStack(spacing: 6) {
            BitBotV2Renderer(skin: skin, state: .idle, frame: 0, size: 36)
                .grayscale(isUnavailable ? 1 : 0)
                .opacity(isUnavailable ? 0.45 : 1)

            Text(skin.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(status.label)
                .font(.caption2)
                .foregroundStyle(status.color)
                .strikethrough(status == .disabled)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 94)
        .padding(8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isUnavailable ? 0.7 : 1)
    }
}
