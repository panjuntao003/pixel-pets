import SwiftUI

struct UnitTab: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Text("宠物（开发中）")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
