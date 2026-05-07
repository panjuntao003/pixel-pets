import Foundation
import Combine

@MainActor
final class QuotaStateStore: ObservableObject {
    @Published var snapshots: [AIProvider: ProviderQuotaSnapshot] = [:]
    @Published var lastRefreshAt: Date?

    func update(provider: AIProvider, snapshot: ProviderQuotaSnapshot) {
        snapshots[provider] = snapshot
        lastRefreshAt = Date()
    }

    func snapshot(for provider: AIProvider) -> ProviderQuotaSnapshot? {
        snapshots[provider]
    }

    func primarySnapshot(among enabledProviders: Set<AIProvider>) -> ProviderQuotaSnapshot? {
        let candidates = enabledProviders.compactMap { snapshots[$0] }
        guard !candidates.isEmpty else { return nil }

        if let normal = candidates.first(where: { $0.status == .normal }) { return normal }
        if let low = candidates.first(where: { $0.status == .low }) { return low }
        return candidates.first
    }

    func overallStatus(among enabledProviders: Set<AIProvider>) -> QuotaStatus {
        guard !enabledProviders.isEmpty else { return .unavailable }

        let candidates = enabledProviders.compactMap { snapshots[$0] }
        guard !candidates.isEmpty else { return .unknown }
        if candidates.count < enabledProviders.count { return .unknown }

        if candidates.contains(where: { $0.status == .exhausted }) { return .exhausted }
        if candidates.contains(where: { $0.status == .low }) { return .low }
        if candidates.contains(where: { $0.status == .normal }) { return .normal }
        if candidates.allSatisfy({ $0.status == .unavailable }) { return .unavailable }
        return .unknown
    }
}
