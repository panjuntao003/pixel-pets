import AppKit
import SwiftUI

@main
struct PixelPetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            GameSettingsView()
                .environmentObject(appDelegate.coordinator.settingsStore)
        }
    }
}
