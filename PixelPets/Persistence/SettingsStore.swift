import Foundation
import Combine

struct AppSettings: Codable {
    var hookPermissionAsked: Bool = false
    var enabledCLIs: [String: Bool] = [:]
    var hookPort: UInt16 = 15799
    var scenePreference: ScenePreference = .random
    var equippedAccessories: [String: String] = [:]
    var skinOverride: String? = nil

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hookPermissionAsked = try container.decodeIfPresent(Bool.self, forKey: .hookPermissionAsked) ?? false
        enabledCLIs = try container.decodeIfPresent([String: Bool].self, forKey: .enabledCLIs) ?? [:]
        hookPort = try container.decodeIfPresent(UInt16.self, forKey: .hookPort) ?? 15799
        scenePreference = try container.decodeIfPresent(ScenePreference.self, forKey: .scenePreference) ?? .random
        equippedAccessories = try container.decodeIfPresent([String: String].self, forKey: .equippedAccessories) ?? [:]
        skinOverride = try container.decodeIfPresent(String.self, forKey: .skinOverride)
    }

    func isEnabled(_ skin: AgentSkin) -> Bool {
        enabledCLIs[skin.rawValue] != false
    }
}

enum ScenePreference: String, Codable, CaseIterable {
    case random
    case spaceStation = "space_station"
    case cyberpunkLab = "cyberpunk_lab"
    case sciFiQuarters = "scifi_quarters"
    case underwater

    var displayName: String {
        switch self {
        case .random: return "随机"
        case .spaceStation: return "太空站"
        case .cyberpunkLab: return "赛博朋克实验室"
        case .sciFiQuarters: return "星际生活舱"
        case .underwater: return "像素水族箱"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var settings: AppSettings

    private let settingsURL: URL
    private let fileManager: FileManager
    private let hookPermissionAskedKey = "hookPermissionAsked"

    convenience init() {
        let directory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".pixelpets")
            .path
        self.init(directory: directory)
    }

    init(directory: String, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.settingsURL = URL(fileURLWithPath: directory)
            .appendingPathComponent("settings.json")

        self.settings = Self.loadSettings(from: settingsURL)
        migrateHookPermissionAskedIfNeeded()
    }

    func update(_ block: (inout AppSettings) -> Void) {
        block(&settings)
        save()
    }

    var hookPermissionAsked: Bool {
        get { settings.hookPermissionAsked }
        set {
            update { settings in
                settings.hookPermissionAsked = newValue
            }
        }
    }

    private static func loadSettings(from url: URL) -> AppSettings {
        guard let data = try? Data(contentsOf: url),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return AppSettings()
        }
        return settings
    }

    private func migrateHookPermissionAskedIfNeeded() {
        guard UserDefaults.standard.bool(forKey: hookPermissionAskedKey) else {
            return
        }

        settings.hookPermissionAsked = true
        UserDefaults.standard.removeObject(forKey: hookPermissionAskedKey)
        save()
    }

    private func save() {
        do {
            try fileManager.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save settings: \(error)")
        }
    }
}
