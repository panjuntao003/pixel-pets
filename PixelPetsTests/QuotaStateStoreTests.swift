import XCTest
@testable import PixelPets

@MainActor
final class QuotaStateStoreTests: XCTestCase {
    var store: QuotaStateStore!

    override func setUp() {
        super.setUp()
        store = QuotaStateStore()
    }

    func test_initialState_emptySnapshots() {
        XCTAssertTrue(store.snapshots.isEmpty)
        XCTAssertNil(store.lastRefreshAt)
    }

    func test_update_storesSnapshot() {
        let snapshot = ProviderQuotaSnapshot(
            provider: .claude, status: .normal, remainingPercent: 65,
            resetAt: nil, lastCheckedAt: Date(), lastSuccessfulAt: Date(),
            source: .providerAPI, message: nil
        )
        store.update(provider: .claude, snapshot: snapshot)
        XCTAssertEqual(store.snapshots[.claude]?.status, .normal)
        XCTAssertEqual(store.snapshots[.claude]?.remainingPercent, 65)
        XCTAssertNotNil(store.lastRefreshAt)
    }

    func test_overallStatus_exhaustedWins() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .normal))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .exhausted))
        store.update(provider: .gemini, snapshot: makeSnapshot(.gemini, .low))
        XCTAssertEqual(store.overallStatus(among: [.claude, .codex, .gemini]), .exhausted)
    }

    func test_overallStatus_lowOverNormal() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .normal))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .low))
        XCTAssertEqual(store.overallStatus(among: [.claude, .codex]), .low)
    }

    func test_overallStatus_allUnavailable_showsUnavailable() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .unavailable))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .unavailable))
        XCTAssertEqual(store.overallStatus(among: [.claude, .codex]), .unavailable)
    }

    func test_overallStatus_disabledProvidersExcluded() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .normal))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .exhausted))
        XCTAssertEqual(store.overallStatus(among: [.claude]), .normal)
    }

    func test_overallStatus_noEnabledProviders_showsUnavailable() {
        XCTAssertEqual(store.overallStatus(among: []), .unavailable)
    }

    func test_overallStatus_partialUnavailable_notAffected() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .normal))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .unavailable))
        XCTAssertEqual(store.overallStatus(among: [.claude, .codex]), .normal)
    }

    func test_primarySnapshot_prefersNormal() {
        store.update(provider: .claude, snapshot: makeSnapshot(.claude, .low))
        store.update(provider: .codex, snapshot: makeSnapshot(.codex, .normal))
        let primary = store.primarySnapshot(among: [.claude, .codex])
        XCTAssertEqual(primary?.provider, .codex)
    }

    private func makeSnapshot(_ prov: AIProvider, _ status: QuotaStatus) -> ProviderQuotaSnapshot {
        ProviderQuotaSnapshot(
            provider: prov, status: status, remainingPercent: status == .normal ? 80 : nil,
            resetAt: nil, lastCheckedAt: Date(), lastSuccessfulAt: status != .unavailable ? Date() : nil,
            source: .providerAPI, message: nil
        )
    }
}
