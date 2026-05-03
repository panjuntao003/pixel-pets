import SwiftUI

struct HabitatView: View {
    @ObservedObject var viewModel: PetViewModel
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var currentSceneID: SceneID = .galaxyObservatory

    private var currentScene: any HabitatScene {
        SceneRegistry.scene(for: currentSceneID)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            AnimationClock(fps: 30) { frame in
                SceneWithRobot(scene: currentScene, viewModel: viewModel, frame: frame)
            }

            SceneDotNav(
                scenes: SceneID.allCases,
                current: currentSceneID,
                onSelect: { switchScene(to: $0) }
            )
            .padding(.trailing, 8)
            .padding(.bottom, 6)
        }
        .frame(height: 140)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -30 {
                        cycleScene(forward: true)
                    } else if value.translation.width > 30 {
                        cycleScene(forward: false)
                    }
                }
        )
        .onAppear { applyScenePreference() }
        .onChange(of: settingsStore.settings.scenePreference) { _, newValue in
            if let id = newValue.sceneID {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentSceneID = id
                }
            }
        }
    }

    private func applyScenePreference() {
        let preference = settingsStore.settings.scenePreference
        if let id = preference.sceneID {
            currentSceneID = id
        } else {
            currentSceneID = SceneID.allCases.randomElement()!
        }
    }

    private func switchScene(to id: SceneID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentSceneID = id
        }
    }

    private func cycleScene(forward: Bool) {
        let allScenes = SceneID.allCases
        guard let index = allScenes.firstIndex(of: currentSceneID) else {
            return
        }

        let next = forward
            ? allScenes[(index + 1) % allScenes.count]
            : allScenes[(index + allScenes.count - 1) % allScenes.count]
        withAnimation(.easeInOut(duration: 0.3)) {
            currentSceneID = next
        }
    }
}

#Preview("Habitat States") {
    VStack(spacing: 0) {
        ForEach([PetState.idle, .thinking, .charging, .error], id: \.self) { state in
            let vm = PetViewModel.mock()
            let _ = { vm.state = state }()
            VStack(alignment: .leading) {
                Text(state.rawValue.capitalized).font(.caption).padding(.leading)
                HabitatView(viewModel: vm)
            }
            .frame(height: 160)
        }
    }
    .frame(width: 360)
}

private struct SceneWithRobot: View {
    let scene: any HabitatScene
    @ObservedObject var viewModel: PetViewModel
    let frame: Int

    var body: some View {
        let mockAsset = SceneAsset(
            id: scene.id.rawValue,
            name: scene.displayName,
            logicalSize: IntSize(width: 360, height: 140),
            defaultPetPosition: IntPoint(x: 180, y: 76),
            safeArea: SceneAsset.EdgeInsets(top: 8, bottom: 12, left: 12, right: 12),
            states: [:]
        )

        HabitatRenderer(
            viewModel: viewModel,
            currentScene: mockAsset,
            frame: frame,
            legacyScene: scene
        )
    }
}

private struct SceneDotNav: View {
    let scenes: [SceneID]
    let current: SceneID
    let onSelect: (SceneID) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(scenes, id: \.self) { id in
                Circle()
                    .fill(id == current ? Color.white : Color.white.opacity(0.35))
                    .frame(width: id == current ? 7 : 5, height: id == current ? 7 : 5)
                    .onTapGesture { onSelect(id) }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.3))
        .clipShape(Capsule())
    }
}
