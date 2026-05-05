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

            let productionAccs = AssetRegistry.shared.productionAccessories.keys
            let currentPetID = viewModel.activeSkin == .claude ? "nebula_bot" : viewModel.activeSkin.rawValue
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 8) {
                ForEach(Accessory.allCases.filter { productionAccs.contains($0.rawValue) }, id: \.self) { accessory in
                    let asset = AssetRegistry.shared.accessories[accessory.rawValue]
                    let isCompatible = !(asset?.incompatiblePets?.contains(currentPetID) ?? false)
                    
                    AccessoryCell(
                        accessory: accessory,
                        state: accessoryState(accessory),
                        isCompatible: isCompatible,
                        onTap: { 
                            if isCompatible {
                                toggleAccessory(accessory)
                            }
                        }
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

    private func accessoryState(_ accessory: Accessory) -> AccessoryLoadoutState {
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

enum AccessoryLoadoutState {
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
    let state: AccessoryLoadoutState
    let isCompatible: Bool
    let onTap: () -> Void

    private var isLocked: Bool {
        state == .locked
    }

    private var label: String {
        if !isCompatible { return "不兼容" }
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
                .grayscale((isLocked || !isCompatible) ? 1 : 0)
                .opacity((isLocked || !isCompatible) ? 0.4 : 1)

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
        .opacity((isLocked || !isCompatible) ? 0.65 : 1)
        .onTapGesture(perform: onTap)
    }

    private var labelColor: Color {
        if !isCompatible { return .red.opacity(0.8) }
        switch state {
        case .equipped: return .green
        case .unlocked: return .secondary
        case .locked: return .secondary.opacity(0.65)
        }
    }
}
