import Foundation
import Combine

@MainActor
final class QuotaCoordinator: ObservableObject {
    let stateStore = QuotaStateStore()
    let settingsStore: SettingsStore

    private var clients: [QuotaClient]
    private var timer: Timer?
    private var isRefreshing = false

    init(settingsStore: SettingsStore? = nil, clients: [QuotaClient]? = nil) {
        self.settingsStore = settingsStore ?? SettingsStore()
        let defaultClients: [QuotaClient] = [
            ClaudeQuotaAdapter(),
            CodexQuotaAdapter(),
            GeminiQuotaAdapter()
        ]
        self.clients = clients ?? defaultClients
    }

    var enabledProviders: Set<AIProvider> {
        let settings = settingsStore.settings
        var providers = Set<AIProvider>()
        for provider in [AIProvider.claude, AIProvider.codex, AIProvider.gemini] {
            if settings.isProviderEnabled(provider) {
                providers.insert(provider)
            }
        }
        return providers
    }

    private var clientMap: [AIProvider: QuotaClient] {
        Dictionary(uniqueKeysWithValues: clients.map { ($0.provider, $0) })
    }

    func start() {
        guard timer == nil else { return }

        Task { await refreshAll() }

        let interval = TimeInterval(settingsStore.settings.refreshIntervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshAll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        Task { await refreshAll() }
    }

    func refreshAll() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let enabled = enabledProviders
        let threshold = settingsStore.settings.lowQuotaThreshold
        let map = clientMap

        for provider in AIProvider.allCases {
            guard provider != .unknown else { continue }
            guard enabled.contains(provider) else { continue }
            guard let client = map[provider] else { continue }

            let snapshot = await client.fetchQuota(lowQuotaThreshold: threshold)
            stateStore.update(provider: provider, snapshot: snapshot)
        }
    }

    var overallStatus: QuotaStatus {
        stateStore.overallStatus(among: enabledProviders)
    }

    var primarySnapshot: ProviderQuotaSnapshot? {
        stateStore.primarySnapshot(among: enabledProviders)
    }
}
