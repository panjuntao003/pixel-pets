import XCTest
@testable import Quota

// MARK: - Mock Quota Client

private final class MockQuotaClient: QuotaClient {
    let provider: AIProvider
    private let handler: () async -> ProviderQuotaSnapshot

    init(provider: AIProvider, handler: @escaping () async -> ProviderQuotaSnapshot) {
        self.provider = provider
        self.handler = handler
    }

    func fetchQuota() async -> ProviderQuotaSnapshot {
        await handler()
    }
}

// MARK: - Helpers

@MainActor
private func makeTempStore() -> SettingsStore {
    let dir = FileManager.default.temporaryDirectory
        .appendingPathComponent("QuotaCoordinatorTests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return SettingsStore(directory: dir.path)
}

// MARK: - mapQuotaResultToSnapshot Tests

final class QuotaSnapshotMappingTests: XCTestCase {

    func test_mapSuccess_normal() {
        let tier = QuotaTier(id: "test", utilization: 0.3, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .normal)
        XCTAssertEqual(snapshot.remainingPercent ?? 0, 70, accuracy: 0.01)
        XCTAssertEqual(snapshot.source, .providerAPI)
        XCTAssertNotNil(snapshot.lastSuccessfulAt)
    }

    func test_mapSuccess_low() {
        // 0.7 utilization -> 30% remaining (between 10% and 40%) -> low
        let tier = QuotaTier(id: "test", utilization: 0.7, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .codex, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .low)
    }

    func test_mapSuccess_exhausted_under10Percent() {
        // 0.95 utilization -> 5% remaining -> exhausted
        let tier = QuotaTier(id: "test", utilization: 0.95, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
    }

    func test_mapSuccess_exhausted_zeroRemaining() {
        let tier = QuotaTier(id: "test", utilization: 1.0, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
    }

    func test_mapSuccess_usesMaxUtilization() {
        let t1 = QuotaTier(id: "a", utilization: 0.1, resetsAt: nil, isEstimated: false)
        let t2 = QuotaTier(id: "b", utilization: 0.95, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([t1, t2])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
        XCTAssertEqual(snapshot.remainingPercent ?? 0, 5, accuracy: 0.01)
    }

    func test_mapSuccess_usesSoonestReset() {
        let soonest = Date().addingTimeInterval(3600)
        let later = Date().addingTimeInterval(7200)
        let t1 = QuotaTier(id: "a", utilization: 0.1, resetsAt: later, isEstimated: false)
        let t2 = QuotaTier(id: "b", utilization: 0.2, resetsAt: soonest, isEstimated: false)
        let result = QuotaFetchResult.success([t1, t2])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.resetAt, soonest)
    }

    func test_mapSuccess_emptyTiers() {
        let result = QuotaFetchResult.success([])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .normal)
        XCTAssertEqual(snapshot.remainingPercent ?? 0, 100, accuracy: 0.01)
    }

    func test_mapSuccess_just_above_lowThreshold_isNormal() {
        // 41% remaining -> normal (boundary precision tested in QuotaUsageLevelTests)
        let tier = QuotaTier(id: "test", utilization: 0.59, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .normal)
    }

    func test_mapSuccess_just_above_exhaustedThreshold_isLow() {
        // 11% remaining -> low
        let tier = QuotaTier(id: "test", utilization: 0.89, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .low)
    }

    func test_mapUnavailable() {
        let result = QuotaFetchResult.unavailable("Test unavailable")
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.message, "Test unavailable")
        XCTAssertNil(snapshot.lastSuccessfulAt)
        XCTAssertEqual(snapshot.source, .unknown)
    }

    func test_mapEstimated_normal() {
        let tier = QuotaTier(id: "test", utilization: 0, resetsAt: nil, isEstimated: true)
        let result = QuotaFetchResult.estimated([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.source, .estimated)
        XCTAssertEqual(snapshot.status, .normal)
        XCTAssertNotNil(snapshot.lastSuccessfulAt)
    }

    func test_mapEstimated_exhausted() {
        let tier = QuotaTier(id: "test", utilization: 1.0, resetsAt: nil, isEstimated: true)
        let result = QuotaFetchResult.estimated([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
        XCTAssertEqual(snapshot.source, .estimated)
    }

    func test_mapEstimated_low() {
        // 0.7 utilization -> 30% remaining -> low
        let tier = QuotaTier(id: "test", utilization: 0.7, resetsAt: nil, isEstimated: true)
        let result = QuotaFetchResult.estimated([tier])
        let snapshot = mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .low)
        XCTAssertEqual(snapshot.source, .estimated)
    }
}

// MARK: - QuotaCoordinator Tests

@MainActor
final class QuotaCoordinatorTests: XCTestCase {

    func test_refreshAll_updatesOnlyEnabledProviders() async {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        store.update {
            $0.enabledProviders["codex"] = false
            $0.enabledProviders["gemini"] = false
        }
        let enabled = coordinator.enabledProviders
        XCTAssertTrue(enabled.contains(.claude))
        XCTAssertFalse(enabled.contains(.codex))
        XCTAssertFalse(enabled.contains(.gemini))
    }

    func test_refreshAll_disabledProvidersNotRefreshed() async {
        let store = makeTempStore()
        var refreshed: Set<AIProvider> = []
        let mockClient = MockQuotaClient(provider: .codex) {
            refreshed.insert(.codex)
            return ProviderQuotaSnapshot.unknown(provider: .codex)
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])
        store.update { $0.enabledProviders["codex"] = false }

        await coordinator.refreshAll()
        XCTAssertTrue(refreshed.isEmpty, "Disabled provider should not be refreshed")
    }

    func test_refreshAll_enabledProvidersRefreshed() async {
        let store = makeTempStore()
        var refreshed: Set<AIProvider> = []
        let mockClaude = MockQuotaClient(provider: .claude) {
            refreshed.insert(.claude)
            return ProviderQuotaSnapshot.unknown(provider: .claude)
        }
        let mockCodex = MockQuotaClient(provider: .codex) {
            refreshed.insert(.codex)
            return ProviderQuotaSnapshot.unknown(provider: .codex)
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClaude, mockCodex])

        await coordinator.refreshAll()
        XCTAssertTrue(refreshed.contains(.claude))
        XCTAssertTrue(refreshed.contains(.codex))
    }

    func test_refreshAll_unavailableProviderStoresSnapshot() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .claude) {
            ProviderQuotaSnapshot.unavailable(provider: .claude, message: "No credentials")
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])

        await coordinator.refreshAll()
        let snapshot = coordinator.stateStore.snapshot(for: .claude)
        XCTAssertNotNil(snapshot)
        XCTAssertEqual(snapshot?.status, .unavailable)
        XCTAssertEqual(snapshot?.message, "No credentials")
        XCTAssertNotNil(coordinator.stateStore.lastRefreshAt)
    }

    func test_refreshAll_manualRefreshUpdatesLastRefreshAt() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .claude) {
            ProviderQuotaSnapshot.unknown(provider: .claude)
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])

        XCTAssertNil(coordinator.stateStore.lastRefreshAt)
        await coordinator.refreshAll()
        XCTAssertNotNil(coordinator.stateStore.lastRefreshAt)
    }

    func test_refreshAll_noHistoryStored() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .claude) {
            let tier = QuotaTier(id: "test", utilization: 0.3, resetsAt: nil, isEstimated: false)
            let result = QuotaFetchResult.success([tier])
            return mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])

        await coordinator.refreshAll()
        await coordinator.refreshAll()
        await coordinator.refreshAll()

        XCTAssertEqual(coordinator.stateStore.snapshots.count, 1)
    }

    func test_refreshAll_exhaustedMapping() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .claude) {
            let tier = QuotaTier(id: "test", utilization: 1.0, resetsAt: nil, isEstimated: false)
            let result = QuotaFetchResult.success([tier])
            return mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])
        await coordinator.refreshAll()

        let snapshot = coordinator.stateStore.snapshot(for: .claude)
        XCTAssertEqual(snapshot?.status, .exhausted)
    }

    func test_refreshAll_lowMapping() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .claude) {
            // 0.7 utilization -> 30% remaining -> low
            let tier = QuotaTier(id: "test", utilization: 0.7, resetsAt: nil, isEstimated: false)
            let result = QuotaFetchResult.success([tier])
            return mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])
        await coordinator.refreshAll()

        let snapshot = coordinator.stateStore.snapshot(for: .claude)
        XCTAssertEqual(snapshot?.status, .low)
    }

    func test_refreshAll_geminiUnavailableNoErrorState() async {
        let store = makeTempStore()
        store.update {
            $0.enabledProviders["claude"] = false
            $0.enabledProviders["codex"] = false
        }
        let mockClient = MockQuotaClient(provider: .gemini) {
            ProviderQuotaSnapshot.unavailable(provider: .gemini, message: "No API key")
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])

        await coordinator.refreshAll()

        let snapshot = coordinator.stateStore.snapshot(for: .gemini)
        XCTAssertEqual(snapshot?.status, .unavailable)
        XCTAssertEqual(snapshot?.message, "No API key")
        let overall = coordinator.overallStatus
        XCTAssertEqual(overall, .unavailable)
    }

    func test_overallStatus_aggregatesProviders() async {
        let store = makeTempStore()
        store.update { $0.enabledProviders["gemini"] = false }
        let mockClaude = MockQuotaClient(provider: .claude) {
            let tier = QuotaTier(id: "test", utilization: 0.1, resetsAt: nil, isEstimated: false)
            let result = QuotaFetchResult.success([tier])
            return mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        }
        let mockCodex = MockQuotaClient(provider: .codex) {
            ProviderQuotaSnapshot.unavailable(provider: .codex, message: "No credentials")
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClaude, mockCodex])

        await coordinator.refreshAll()

        let overall = coordinator.overallStatus
        XCTAssertEqual(overall, .normal, "One normal provider should yield normal overall")
    }

    func test_overallStatus_noEnabledProviders_isUnavailable() async {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        store.update {
            $0.enabledProviders["claude"] = false
            $0.enabledProviders["codex"] = false
            $0.enabledProviders["gemini"] = false
            $0.enabledProviders["gemini"] = false
        }
        await coordinator.refreshAll()
        XCTAssertEqual(coordinator.overallStatus, .unavailable)
    }

    func test_start_setsTimer() {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        store.update { $0.refreshIntervalSeconds = 300 }
        coordinator.start()
        coordinator.stop()
    }

    func test_start_skipsIfAlreadyStarted() {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        coordinator.start()
        coordinator.start()
        coordinator.stop()
    }

    func test_start_refreshIntervalChangeUsesNewInterval() async {
        let store = makeTempStore()
        store.update {
            $0.enabledProviders["codex"] = false
            $0.enabledProviders["gemini"] = false
            $0.refreshIntervalSeconds = 60
        }

        var refreshCount = 0
        let mockClient = MockQuotaClient(provider: .claude) {
            refreshCount += 1
            return ProviderQuotaSnapshot.unknown(provider: .claude)
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])

        coordinator.start()
        defer { coordinator.stop() }

        let didRunInitialRefresh = await waitUntil { refreshCount >= 1 }
        XCTAssertTrue(didRunInitialRefresh, "Initial refresh should run")

        store.update { $0.refreshIntervalSeconds = 1 }

        let didUseNewInterval = await waitUntil(timeout: 2.5) { refreshCount >= 3 }
        XCTAssertTrue(didUseNewInterval, "Timer should be recreated with the new interval")
    }

    func test_refreshAll_unknownProvider_skipped() async {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        await coordinator.refreshAll()
        XCTAssertTrue(coordinator.stateStore.snapshots.isEmpty)
    }

    func test_refreshAll_noClientsForProvider_skipsGracefully() async {
        let store = makeTempStore()
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [])
        await coordinator.refreshAll()
        XCTAssertNil(coordinator.stateStore.snapshot(for: .claude))
    }

    func test_refreshAll_estimatedSourcePreserved() async {
        let store = makeTempStore()
        let mockClient = MockQuotaClient(provider: .gemini) {
            let tier = QuotaTier(id: "test", utilization: 0.3, resetsAt: nil, isEstimated: true)
            let result = QuotaFetchResult.estimated([tier])
            return mapQuotaResultToSnapshot(provider: .gemini, result: result, checkedAt: Date())
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClient])
        await coordinator.refreshAll()

        let snapshot = coordinator.stateStore.snapshot(for: .gemini)
        XCTAssertEqual(snapshot?.source, .estimated)
        XCTAssertEqual(snapshot?.status, .normal)
    }

    func test_refreshAll_primarySnapshotAvailable() async {
        let store = makeTempStore()
        let mockClaude = MockQuotaClient(provider: .claude) {
            let tier = QuotaTier(id: "test", utilization: 0.5, resetsAt: nil, isEstimated: false)
            let result = QuotaFetchResult.success([tier])
            return mapQuotaResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        }
        let coordinator = QuotaCoordinator(settingsStore: store, clients: [mockClaude])
        await coordinator.refreshAll()

        let primary = coordinator.primarySnapshot
        XCTAssertNotNil(primary)
        XCTAssertEqual(primary?.provider, .claude)
    }

    private func waitUntil(
        timeout: TimeInterval = 1.0,
        pollInterval: TimeInterval = 0.05,
        condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            try? await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        return condition()
    }
}
