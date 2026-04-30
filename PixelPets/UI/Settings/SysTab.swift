import SwiftUI

struct SysTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var onRegisterHooks: () -> Void = {}

    @State private var showResetAlert = false

    var body: some View {
        Form {
            Section("AI 工具") {
                ForEach(AgentSkin.allCases, id: \.self) { skin in
                    Toggle(skin.displayName, isOn: Binding(
                        get: {
                            settingsStore.settings.isEnabled(skin)
                        },
                        set: { enabled in
                            settingsStore.update {
                                $0.enabledCLIs[skin.rawValue] = enabled ? nil : false
                                if !enabled, $0.skinOverride == skin.rawValue {
                                    $0.skinOverride = nil
                                }
                            }
                        }
                    ))
                }
            }

            Section("Hook 服务器") {
                HStack {
                    Text("Hook 端口")
                    Spacer()
                    Text("15799")
                        .foregroundStyle(.secondary)
                }

                Button("重新注册 Hook", action: onRegisterHooks)
            }

            Section {
                Button("重置所有设置", role: .destructive) {
                    showResetAlert = true
                }
            }
        }
        .formStyle(.grouped)
        .alert("确定重置？", isPresented: $showResetAlert) {
            Button("重置", role: .destructive) {
                settingsStore.update {
                    $0 = AppSettings()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("所有设置将恢复默认值，不可撤销。")
        }
    }
}
