import Sparkle
import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        QuotaSettingsView()
            .environmentObject(settingsStore)
            .frame(width: 400, height: 400)
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

struct QuotaSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var orderedProviders: [AIProvider] = []

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(orderedProviders, id: \.self) { provider in
                    Toggle(provider.displayName, isOn: Binding(
                        get: { settingsStore.settings.isProviderEnabled(provider) },
                        set: { enabled in
                            settingsStore.update { settings in
                                if enabled {
                                    settings.enabledProviders[provider.rawValue] = true
                                } else {
                                    settings.enabledProviders[provider.rawValue] = false
                                }
                            }
                        }
                    ))
                }
                .onMove { indices, newOffset in
                    orderedProviders.move(fromOffsets: indices, toOffset: newOffset)
                    settingsStore.update { settings in
                        settings.providerOrder = orderedProviders.map(\.rawValue)
                    }
                }
            }

            Section("Thresholds") {
                HStack {
                    Text("Low quota threshold")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.lowQuotaThreshold },
                        set: { newValue in
                            settingsStore.update { settings in
                                settings.lowQuotaThreshold = newValue
                            }
                        }
                    )) {
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("30%").tag(30)
                        Text("50%").tag(50)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
            }

            Section("Refresh") {
                HStack {
                    Text("Auto-refresh interval")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.refreshIntervalSeconds },
                        set: { newValue in
                            settingsStore.update { settings in
                                settings.refreshIntervalSeconds = newValue
                            }
                        }
                    )) {
                        Text("1 min").tag(60)
                        Text("5 min").tag(300)
                        Text("15 min").tag(900)
                        Text("30 min").tag(1800)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }

            Section("Updates") {
                HStack {
                    Text("Automatically check for updates")
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool ?? true },
                        set: { UserDefaults.standard.set($0, forKey: "SUEnableAutomaticChecks") }
                    ))
                }
                HStack {
                    Button("Check for Updates...") {
                        SUUpdater.shared()?.checkForUpdates(nil)
                    }
                    .controlSize(.small)
                    Spacer()
                }
            }

        }
        .formStyle(.grouped)
        .onAppear {
            orderedProviders = settingsStore.settings.providerOrder
                .compactMap(AIProvider.init(rawValue:))
                .filter { $0 != .unknown }
        }
    }
}
