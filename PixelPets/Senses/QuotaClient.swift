import Foundation

protocol QuotaClient {
    var provider: AIProvider { get }
    func fetchQuota(lowQuotaThreshold: Int) async -> ProviderQuotaSnapshot
}

func mapQuotaResultToSnapshot(
    provider: AIProvider,
    result: QuotaFetchResult,
    checkedAt: Date,
    lowQuotaThreshold: Int
) -> ProviderQuotaSnapshot {
    switch result {
    case .success(let tiers):
        return mapTiersToSnapshot(
            provider: provider,
            tiers: tiers,
            checkedAt: checkedAt,
            lowQuotaThreshold: lowQuotaThreshold,
            source: .providerAPI
        )
    case .estimated(let tiers):
        return mapTiersToSnapshot(
            provider: provider,
            tiers: tiers,
            checkedAt: checkedAt,
            lowQuotaThreshold: lowQuotaThreshold,
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
    lowQuotaThreshold: Int,
    source: QuotaSource
) -> ProviderQuotaSnapshot {
    let maxUtilization = tiers.isEmpty ? 0.0 : (tiers.map(\.utilization).max() ?? 0.0)
    let remaining = (1.0 - maxUtilization) * 100.0
    let soonestReset = tiers.compactMap(\.resetsAt).min()

    let status: QuotaStatus
    if maxUtilization >= 1.0 {
        status = .exhausted
    } else if remaining <= Double(lowQuotaThreshold) {
        status = .low
    } else {
        status = .normal
    }

    return ProviderQuotaSnapshot(
        provider: provider,
        status: status,
        remainingPercent: remaining,
        resetAt: soonestReset,
        lastCheckedAt: checkedAt,
        lastSuccessfulAt: checkedAt,
        source: source,
        message: nil
    )
}

// MARK: - Adapters wrapping existing quota clients

struct ClaudeQuotaAdapter: QuotaClient {
    let provider: AIProvider = .claude
    private let client = ClaudeQuotaClient()

    func fetchQuota(lowQuotaThreshold: Int) async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date(),
            lowQuotaThreshold: lowQuotaThreshold
        )
    }
}

struct CodexQuotaAdapter: QuotaClient {
    let provider: AIProvider = .codex
    private let client = CodexQuotaClient()

    func fetchQuota(lowQuotaThreshold: Int) async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date(),
            lowQuotaThreshold: lowQuotaThreshold
        )
    }
}

struct GeminiQuotaAdapter: QuotaClient {
    let provider: AIProvider = .gemini
    private let client = GeminiQuotaClient()

    func fetchQuota(lowQuotaThreshold: Int) async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date(),
            lowQuotaThreshold: lowQuotaThreshold
        )
    }
}

struct OpenCodeQuotaAdapter: QuotaClient {
    let provider: AIProvider = .opencode
    private let client = OpenCodeGoQuotaClient()

    func fetchQuota(lowQuotaThreshold: Int) async -> ProviderQuotaSnapshot {
        let result = await client.fetch()
        return mapQuotaResultToSnapshot(
            provider: provider,
            result: result,
            checkedAt: Date(),
            lowQuotaThreshold: lowQuotaThreshold
        )
    }
}
