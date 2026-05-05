import SwiftUI

struct AssetGalleryView: View {
    @State private var selectedTab: AssetType = .scenes
    private let registry = AssetRegistry.shared
    
    enum AssetType: String, CaseIterable {
        case scenes, pets, accessories
    }
    
    var body: some View {
        VStack {
            Picker("Asset Type", selection: $selectedTab) {
                ForEach(AssetType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            ScrollView {
                switch selectedTab {
                case .scenes:
                    renderScenes()
                case .pets:
                    renderPets()
                case .accessories:
                    renderAccessories()
                }
            }
        }
        .frame(minWidth: 400, minHeight: 600)
    }
    
    @ViewBuilder
    private func renderScenes() -> some View {
        VStack(spacing: 20) {
            ForEach(Array(registry.scenes.values)) { scene in
                VStack(alignment: .leading) {
                    HStack {
                        Text(scene.name).font(.headline)
                        Spacer()
                        statusLabel(for: scene.productionReady)
                    }
                    Text("ID: \(scene.id)").font(.caption)
                    
                    HStack {
                        ForEach(Array(scene.states.keys).sorted(), id: \.self) { state in
                            VStack {
                                Text(state).font(.system(size: 8))
                                if let url = registry.assetURL(forScene: scene.id, layer: "bg", state: SceneState(rawValue: state) ?? .normal),
                                   let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 80, height: 31)
                                } else {
                                    Rectangle().fill(Color.gray).frame(width: 80, height: 31)
                                }
                            }
                        }
                    }
                }
                .padding()
                .border(Color.gray.opacity(0.3))
            }
        }
    }
    
    @ViewBuilder
    private func renderPets() -> some View {
        VStack(spacing: 20) {
            ForEach(Array(registry.pets.values)) { pet in
                VStack(alignment: .leading) {
                    HStack {
                        Text(pet.name).font(.headline)
                        Spacer()
                        statusLabel(for: pet.productionReady)
                    }
                    Text("Size: \(pet.baseSize.w)x\(pet.baseSize.h)").font(.caption)
                    
                    HStack {
                        ForEach(Array(pet.states.keys).sorted(), id: \.self) { state in
                            VStack {
                                Text(state).font(.system(size: 8))
                                if let url = registry.assetURL(forPet: pet.id, state: PetState(rawValue: state) ?? .idle),
                                   let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 32, height: 32)
                                }
                            }
                        }
                    }
                    
                    Text("Anchors").font(.caption).bold()
                    Text(pet.anchors.map { "\($0.key.rawValue): (\($0.value.x),\($0.value.y))" }.joined(separator: ", "))
                        .font(.system(size: 8, design: .monospaced))
                }
                .padding()
                .border(Color.gray.opacity(0.3))
            }
        }
    }
    
    @ViewBuilder
    private func renderAccessories() -> some View {
        VStack(spacing: 20) {
            ForEach(Array(registry.accessories.values)) { acc in
                VStack(alignment: .leading) {
                    HStack {
                        Text(acc.name).font(.headline)
                        Spacer()
                        statusLabel(for: acc.productionReady)
                    }
                    Text("Mount: \(acc.mountPoint.rawValue) | Layer: \(acc.layer.rawValue)").font(.caption)
                    
                    HStack {
                        ForEach(Array(acc.states.keys).sorted(), id: \.self) { state in
                            VStack {
                                Text(state).font(.system(size: 8))
                                if let url = registry.assetURL(forAccessory: acc.id, state: .idle),
                                   let image = NSImage(contentsOf: url) {
                                    Image(nsImage: image)
                                        .resizable()
                                        .interpolation(.none)
                                        .frame(width: 24, height: 24)
                                }
                            }
                        }
                    }
                }
                .padding()
                .border(Color.gray.opacity(0.3))
            }
        }
    }

    @ViewBuilder
    private func statusLabel(for ready: Bool?) -> some View {
        let (text, color) = ready == true ? ("Production Ready", Color.green) :
                           ready == false ? ("Debug Only", Color.red) :
                           ("Technical Valid Only", Color.orange)
        
        Text(text)
            .font(.system(size: 8, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.2), lineWidth: 1))
    }
}
