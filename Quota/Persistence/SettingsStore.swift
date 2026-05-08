import Foundation
import Combine

struct AppSettings: Codable {
    var refreshIntervalSeconds: Int = 300
    var enabledProviders: [String: Bool] = [:]
    var providerOrder: [String] = AIProvider.allCases.filter { $0 != .unknown }.map(\.rawValue)

    init() {}

    enum CodingKeys: String, CodingKey {
        case refreshIntervalSeconds, enabledProviders, providerOrder
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        refreshIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds) ?? 300
        enabledProviders = try container.decodeIfPresent([String: Bool].self, forKey: .enabledProviders) ?? [:]
        providerOrder = try container.decodeIfPresent([String].self, forKey: .providerOrder)
            ?? AIProvider.allCases.filter { $0 != .unknown }.map(\.rawValue)
    }

    func isProviderEnabled(_ provider: AIProvider) -> Bool {
        enabledProviders[provider.rawValue] != false
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var settings = AppSettings()

    private let settingsURL: URL

    init(directory: String? = nil) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.quota.app"
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

    private func load() {
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
