import SwiftUI

struct LoadoutTab: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject private var settingsStore: SettingsStore
    private let growthEngine = GrowthEngine()

    private var unlockedAccessories: [Accessory] {
        growthEngine.compute(totalTokens: viewModel.totalLifetimeTokens).accessories
    }

    var body: some View {
        VStack(spacing: 12) {
            equippedSlots
            allAccessoriesGrid
        }
        .padding()
    }

    private var equippedSlots: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("已装备")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(AccessorySlot.allCases, id: \.self) { slot in
                    EquippedSlotView(
                        slot: slot,
                        accessory: equippedAccessory(for: slot),
                        onUnequip: { unequip(slot: slot) }
                    )
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var allAccessoriesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("全部配饰")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 8) {
                ForEach(Accessory.allCases, id: \.self) { accessory in
                    AccessoryCell(
                        accessory: accessory,
                        state: accessoryState(accessory),
                        onTap: { toggleAccessory(accessory) }
                    )
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func equippedAccessory(for slot: AccessorySlot) -> Accessory? {
        guard let rawValue = settingsStore.settings.equippedAccessories[slot.rawValue],
              let accessory = Accessory(rawValue: rawValue),
              accessory.slot == slot,
              unlockedAccessories.contains(accessory) else {
            return nil
        }

        return accessory
    }

    private func accessoryState(_ accessory: Accessory) -> AccessoryState {
        guard unlockedAccessories.contains(accessory) else {
            return .locked
        }

        if settingsStore.settings.equippedAccessories[accessory.slot.rawValue] == accessory.rawValue {
            return .equipped
        }

        return .unlocked
    }

    private func toggleAccessory(_ accessory: Accessory) {
        switch accessoryState(accessory) {
        case .equipped:
            settingsStore.update {
                $0.equippedAccessories.removeValue(forKey: accessory.slot.rawValue)
            }
        case .unlocked:
            settingsStore.update {
                $0.equippedAccessories[accessory.slot.rawValue] = accessory.rawValue
            }
        case .locked:
            break
        }
    }

    private func unequip(slot: AccessorySlot) {
        settingsStore.update {
            $0.equippedAccessories.removeValue(forKey: slot.rawValue)
        }
    }
}

enum AccessoryState {
    case equipped, unlocked, locked
}

private struct EquippedSlotView: View {
    let slot: AccessorySlot
    let accessory: Accessory?
    let onUnequip: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(accessory?.emoji ?? "＋")
                .font(.title2)
                .frame(width: 34, height: 34)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))

            Text(slot.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            if let accessory {
                Text(accessory.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("未装备")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86)
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            guard accessory != nil else { return }
            onUnequip()
        }
    }
}

private struct AccessoryCell: View {
    let accessory: Accessory
    let state: AccessoryState
    let onTap: () -> Void

    private var isLocked: Bool {
        state == .locked
    }

    private var label: String {
        switch state {
        case .equipped: return "装备中"
        case .unlocked: return "已解锁"
        case .locked: return thresholdLabel
        }
    }

    private var thresholdLabel: String {
        if accessory.tokenThreshold >= 1_000_000 {
            return String(format: "%.1fM", Double(accessory.tokenThreshold) / 1_000_000)
        }
        if accessory.tokenThreshold >= 1_000 {
            return String(format: "%.0fK", Double(accessory.tokenThreshold) / 1_000)
        }
        return "\(accessory.tokenThreshold)"
    }

    var body: some View {
        VStack(spacing: 5) {
            Text(accessory.emoji)
                .font(.title2)
                .grayscale(isLocked ? 1 : 0)
                .opacity(isLocked ? 0.4 : 1)

            Text(accessory.displayName)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(label)
                .font(.caption2)
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .padding(7)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(state == .equipped ? Color.accentColor : .clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .opacity(isLocked ? 0.65 : 1)
        .onTapGesture(perform: onTap)
    }

    private var labelColor: Color {
        switch state {
        case .equipped: return .green
        case .unlocked: return .secondary
        case .locked: return .secondary.opacity(0.65)
        }
    }
}
