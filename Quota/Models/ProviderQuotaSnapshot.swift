import Foundation

struct ProviderQuotaSnapshot: Codable, Equatable {
    let provider: AIProvider
    var status: QuotaStatus
    var remainingPercent: Double?
    var resetAt: Date?
    let lastCheckedAt: Date
    let lastSuccessfulAt: Date?
    let source: QuotaSource
    var message: String?
    var tiers: [QuotaTier]? = nil

    static func unavailable(provider: AIProvider, message: String) -> ProviderQuotaSnapshot {
        let now = Date()
        return ProviderQuotaSnapshot(
            provider: provider,
            status: .unavailable,
            remainingPercent: nil,
            resetAt: nil,
            lastCheckedAt: now,
            lastSuccessfulAt: nil,
            source: .unknown,
            message: message
        )
    }

    static func unknown(provider: AIProvider) -> ProviderQuotaSnapshot {
        return ProviderQuotaSnapshot(
            provider: provider,
            status: .unknown,
            remainingPercent: nil,
            resetAt: nil,
            lastCheckedAt: Date(),
            lastSuccessfulAt: nil,
            source: .unknown,
            message: nil
        )
    }
}
