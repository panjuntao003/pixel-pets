import SwiftUI

struct CLIHookOption: Identifiable {
    let id: AgentSkin
    let configPath: String
    var enabled: Bool = true
    var detected: Bool
}

struct HookPermissionView: View {
    @Binding var options: [CLIHookOption]
    let onConfirm: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("启用实时 Hook")
                .font(.headline)

            Text("PixelPets 需要在以下 CLI 配置文件中注册 Hook 脚本，以感知实时状态。\n每个配置文件将自动备份为 *.pixelpets.bak。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            ForEach($options) { $option in
                if option.detected {
                    HStack {
                        Toggle("", isOn: $option.enabled)
                            .labelsHidden()

                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.id.displayName)
                                .font(.system(size: 12, weight: .medium))
                            Text(option.configPath)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            HStack {
                Button("跳过") {
                    onSkip()
                }
                Spacer()
                Button("注册选中的 Hook") {
                    onConfirm()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}
