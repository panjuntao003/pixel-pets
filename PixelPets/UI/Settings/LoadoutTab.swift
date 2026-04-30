import SwiftUI

struct LoadoutTab: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Text("装备（开发中）")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
