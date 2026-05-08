import Foundation

protocol QuotaClient {
    var provider: AIProvider { get }
    func fetchQuota() async -> ProviderQuotaSnapshot
}

func mapQuotaResultToSnapshot(
    provider: AIProvider,
    result: QuotaFetchResult,
    checkedAt: Date
) -> ProviderQuotaSnapshot {
    switch result {
    case .success(let tiers):
        return mapTiersToSnapshot(
            provider: provider,
            tiers: tiers,
            checkedAt: checkedAt,
            source: .providerAPI
        )
    case .estimated(let tiers):
        return mapTiersToSnapshot(
            provider: provider,
            tiers: tiers,
            checkedAt: checkedAt,
            source: .estimated
        )
    case .unavailable(let reason):
        return ProviderQuotaSnapshot.unavailable(provider: provider, message: reason)
    }
}

private func mapTiersToSnapshot(
    provider: AIProvider,
    tiers: [QuotaTier],
    checkedAt: Date,
    source: QuotaSource
) -> ProviderQuotaSnapshot {
    let maxUtilization = tiers.isEmpty ? 0.0 : (tiers.map(\.utilization).max() ?? 0.0)
    let remainingFraction = max(0, 1 - maxUtilization)
    let remaining = remainingFraction * 100.0
    let soonestReset = tiers.compactMap(\.resetsAt).min()

    let status: QuotaStatus
    switch QuotaUsageLevel(remainingFraction: remainingFraction) {
    case .normal:    status = .normal
    case .low:       status = .low
    case .exhausted: status = .exhausted
    }

    return ProviderQuotaSnapshot(
        provider: provider,
        status: status,
        remainingPercent: remaining,
        resetAt: soonestReset,
        lastCheckedAt: checkedAt,
        lastSuccessfulAt: checkedAt,
        source: source,
        message: nil,
        tiers: tiers
    )
}

// MARK: - Adapters wrapping existing quota clients

struct ClaudeQuotaAdapter: QuotaClient {
    let provider: AIProvider = .claude
    private let client = ClaudeQuotaClient()

    func fetchQuota() async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date()
        )
    }
}

struct CodexQuotaAdapter: QuotaClient {
    let provider: AIProvider = .codex
    private let client = CodexQuotaClient()

    func fetchQuota() async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date()
        )
    }
}

struct GeminiQuotaAdapter: QuotaClient {
    let provider: AIProvider = .gemini
    private let client = GeminiQuotaClient()

    func fetchQuota() async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date()
        )
    }
}
