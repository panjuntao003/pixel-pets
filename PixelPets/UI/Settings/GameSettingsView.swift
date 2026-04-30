import SwiftUI

enum SettingsTab: String, CaseIterable {
    case unit = "UNIT"
    case loadout = "LOADOUT"
    case map = "MAP"
    case sys = "SYS"

    var title: String {
        switch self {
        case .unit: return "宠物"
        case .loadout: return "装备"
        case .map: return "场景"
        case .sys: return "系统"
        }
    }

    var systemImage: String {
        switch self {
        case .unit: return "cpu"
        case .loadout: return "backpack"
        case .map: return "mountain.2"
        case .sys: return "gearshape"
        }
    }
}

struct GameSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @ObservedObject var viewModel: PetViewModel

    var onRegisterHooks: () -> Void = {}

    @State private var selectedTab: SettingsTab = .unit

    var body: some View {
        NavigationSplitView {
            List(SettingsTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.systemImage)
                    .tag(tab)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 140, ideal: 160)
        } detail: {
            detailView
                .environmentObject(settingsStore)
        }
        .frame(width: 520, height: 420)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .unit:
            UnitTab(viewModel: viewModel)
        case .loadout:
            LoadoutTab(viewModel: viewModel)
        case .map:
            MapTab()
        case .sys:
            SysTab(onRegisterHooks: onRegisterHooks)
        }
    }
}
