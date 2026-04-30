import SwiftUI

struct MapTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Text("场景（开发中）")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
