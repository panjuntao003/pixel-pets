import Foundation
import Combine

struct AppSettings: Codable {
    var hookPermissionAsked: Bool = false
    var enabledCLIs: [String: Bool] = [:]
    var hookPort: UInt16 = 15799
    var scenePreference: ScenePreference = .galaxyObservatory
    var equippedAccessories: [String: String] = [:]
    var skinOverride: String? = nil

    // Phase 5 Productization Settings
    var isPixelPetEnabled: Bool = true
    var animationIntensity: AnimationIntensity = .medium
    var lowDistractionMode: Bool = false
    var reduceMotion: Bool = false
    var enableQuotaAlerts: Bool = true
    var enabledEventSources: [AIProvider: Bool] = [
        .claude: true, .opencode: true, .codex: true, .gemini: true
    ]

    init() {}

    enum CodingKeys: String, CodingKey {
        case hookPermissionAsked, enabledCLIs, hookPort, scenePreference, equippedAccessories, skinOverride
        case isPixelPetEnabled, animationIntensity, lowDistractionMode, reduceMotion, enableQuotaAlerts, enabledEventSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hookPermissionAsked = try container.decodeIfPresent(Bool.self, forKey: .hookPermissionAsked) ?? false
        enabledCLIs = try container.decodeIfPresent([String: Bool].self, forKey: .enabledCLIs) ?? [:]
        hookPort = try container.decodeIfPresent(UInt16.self, forKey: .hookPort) ?? 15799
        scenePreference = try container.decodeIfPresent(ScenePreference.self, forKey: .scenePreference) ?? .random
        equippedAccessories = try container.decodeIfPresent([String: String].self, forKey: .equippedAccessories) ?? [:]
        skinOverride = try container.decodeIfPresent(String.self, forKey: .skinOverride)
        
        // Phase 5 fields
        isPixelPetEnabled = try container.decodeIfPresent(Bool.self, forKey: .isPixelPetEnabled) ?? true
        animationIntensity = try container.decodeIfPresent(AnimationIntensity.self, forKey: .animationIntensity) ?? .medium
        lowDistractionMode = try container.decodeIfPresent(Bool.self, forKey: .lowDistractionMode) ?? false
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        enableQuotaAlerts = try container.decodeIfPresent(Bool.self, forKey: .enableQuotaAlerts) ?? true
        enabledEventSources = try container.decodeIfPresent([AIProvider: Bool].self, forKey: .enabledEventSources) ?? [
            .claude: true, .opencode: true, .codex: true, .gemini: true
        ]
    }

    func isEnabled(_ skin: AgentSkin) -> Bool {
        enabledCLIs[skin.rawValue] != false
    }
}

enum AnimationIntensity: String, Codable, CaseIterable {
    case low, medium, high
}

enum ScenePreference: String, Codable, CaseIterable {
    case random
    case spaceStation = "space_station"
    case cyberpunkLab = "cyberpunk_lab"
    case sciFiQuarters = "scifi_quarters"
    case underwater
    case galaxyObservatory = "galaxy_observatory"

    var displayName: String {
        switch self {
        case .random: return "随机"
        case .spaceStation: return "太空站"
        case .cyberpunkLab: return "赛博朋克实验室"
        case .sciFiQuarters: return "星际生活舱"
        case .underwater: return "像素水族箱"
        case .galaxyObservatory: return "银河观测站"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings = AppSettings()
    
    private let settingsURL: URL
    
    init(directory: String? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.google.pixelpets"
        let baseFolder = directory.map { URL(fileURLWithPath: $0) } ?? appSupport.appendingPathComponent(bundleID)
        
        try? FileManager.default.createDirectory(at: baseFolder, withIntermediateDirectories: true)
        settingsURL = baseFolder.appendingPathComponent("settings.json")
        load()
    }
    
    func update(_ transform: (inout AppSettings) -> Void) {
        var newSettings = settings
        transform(&newSettings)
        settings = newSettings
        save()
    }
    
    var hookPermissionAsked: Bool {
        get { settings.hookPermissionAsked }
        set { update { $0.hookPermissionAsked = newValue } }
    }
    
    private func load() {
        if !FileManager.default.fileExists(atPath: settingsURL.path) {
            // Migrate legacy key
            let key = "hookPermissionAsked"
            if UserDefaults.standard.object(forKey: key) != nil {
                settings.hookPermissionAsked = UserDefaults.standard.bool(forKey: key)
                UserDefaults.standard.removeObject(forKey: key)
                save()
                return
            }
        }

        guard let data = try? Data(contentsOf: settingsURL) else { return }
        do {
            settings = try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            print("Failed to load settings: \(error)")
        }
    }
    
    private func save() {
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save settings: \(error)")
        }
    }
}
