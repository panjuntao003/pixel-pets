import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var onRegisterHooks: () -> Void = {}

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }

            SceneSettingsTab()
                .tabItem {
                    Label("场景", systemImage: "sparkles")
                }

            AdvancedSettingsTab(onRegisterHooks: onRegisterHooks)
                .tabItem {
                    Label("高级", systemImage: "wrench.and.screwdriver")
                }
        }
        .environmentObject(settingsStore)
        .frame(width: 380, height: 280)
    }
}

private struct GeneralSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section("AI 工具") {
                ForEach(AgentSkin.allCases, id: \.self) { skin in
                    Toggle(skin.displayName, isOn: Binding(
                        get: {
                            store.settings.isEnabled(skin)
                        },
                        set: { enabled in
                            store.update {
                                $0.enabledCLIs[skin.rawValue] = enabled ? nil : false
                            }
                        }
                    ))
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct SceneSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var body: some View {
        Form {
            Section("默认场景") {
                Picker("场景偏好", selection: Binding(
                    get: {
                        store.settings.scenePreference
                    },
                    set: { preference in
                        store.update {
                            $0.scenePreference = preference
                        }
                    }
                )) {
                    ForEach(ScenePreference.allCases, id: \.self) { preference in
                        Text(preference.displayName)
                            .tag(preference)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AdvancedSettingsTab: View {
    @EnvironmentObject private var store: SettingsStore

    var onRegisterHooks: () -> Void = {}

    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section("Hook 服务器") {
                HStack {
                    Text("Hook 端口")
                    Spacer()
                    Text("15799")
                        .foregroundStyle(.secondary)
                }

                Text("端口固定为 15799，可变端口支持将在后续版本提供。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("重新注册 Hook", action: onRegisterHooks)
            }

            Section {
                Button("重置所有设置", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("确定重置？", isPresented: $showResetAlert) {
            Button("重置", role: .destructive) {
                store.update {
                    $0 = AppSettings()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有设置将恢复默认值，不可撤销。")
        }
    }
}
