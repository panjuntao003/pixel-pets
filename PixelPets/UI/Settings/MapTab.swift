import SwiftUI

struct MapTab: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    @State private var previewSceneID: SceneID = .spaceStation

    private var selectedPreference: ScenePreference {
        settingsStore.settings.scenePreference
    }

    var body: some View {
        VStack(spacing: 12) {
            scenePreview
            sceneGrid
        }
        .padding()
        .onAppear {
            if let id = selectedPreference.sceneID {
                previewSceneID = id
            }
        }
    }

    private var scenePreview: some View {
        VStack(spacing: 0) {
            Canvas { ctx, size in
                let scene = SceneRegistry.scene(for: previewSceneID)
                scene.drawBackground(ctx, size: size, frame: 0)
            }
            .frame(height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    let scene = SceneRegistry.scene(for: previewSceneID)
                    Text(scene.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    Text(scene.sceneDescription)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedPreference.sceneID == previewSceneID || selectedPreference == .random {
                    Text("使用中")
                        .font(.system(size: 9, weight: .medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var sceneGrid: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("全部场景")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                SceneCard(emoji: "🎲", name: "随机", isSelected: selectedPreference == .random)
                    .onTapGesture {
                        settingsStore.update { $0.scenePreference = .random }
                    }

                let productionIDs = AssetRegistry.shared.productionScenes.keys
                ForEach(SceneID.allCases.filter { productionIDs.contains($0.rawValue) }, id: \.self) { sceneID in
                    SceneCard(
                        emoji: sceneID.emoji,
                        name: SceneRegistry.scene(for: sceneID).displayName,
                        isSelected: selectedPreference.sceneID == sceneID
                    )
                    .onTapGesture {
                        previewSceneID = sceneID
                        let pref = ScenePreference.allCases.first { $0.sceneID == sceneID } ?? .random
                        settingsStore.update { $0.scenePreference = pref }
                    }
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct SceneCard: View {
    let emoji: String
    let name: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(emoji).font(.system(size: 16))
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            Spacer()
        }
        .padding(8)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}
