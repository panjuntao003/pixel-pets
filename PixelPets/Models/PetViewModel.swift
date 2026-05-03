import Foundation
import Combine

struct CliQuotaInfo: Identifiable {
    let id: AgentSkin
    var fetchResult: QuotaFetchResult = .unavailable("未检测到")
    var todayTokens: Int = 0
    var weekTokens: Int = 0
    var planBadge: String = ""
    var isDetected: Bool = false

    init(
        id: AgentSkin,
        fetchResult: QuotaFetchResult = .unavailable("未检测到"),
        todayTokens: Int = 0,
        weekTokens: Int = 0,
        planBadge: String = "",
        isDetected: Bool = false
    ) {
        self.id = id
        self.fetchResult = fetchResult
        self.todayTokens = todayTokens
        self.weekTokens = weekTokens
        self.planBadge = planBadge
        self.isDetected = isDetected
    }

    var tiers: [QuotaTier] {
        switch fetchResult {
        case .success(let t), .estimated(let t): return t
        case .unavailable: return []
        }
    }
    var isUnavailable: Bool {
        if case .unavailable = fetchResult { return true }
        return false
    }

    var unavailableReason: String? {
        if case .unavailable(let reason) = fetchResult {
            return reason
        }
        return nil
    }
}

final class PetViewModel: ObservableObject {
    @Published var state: PetState = .idle
    @Published var activeSkin: AgentSkin = .claude
    @Published var level: Int = 1
    @Published var unlockedAccessories: [Accessory] = []
    @Published var equippedAccessories: [Accessory] = []
    @Published var cliInfos: [CliQuotaInfo] = []
    @Published var totalLifetimeTokens: Int = 0
    @Published var hooksAvailable: Bool = false   // false if node missing

    var enabledCLIFilter: ((CliQuotaInfo) -> Bool) = { _ in true }

    var visibleClis: [CliQuotaInfo] {
        cliInfos.filter { $0.isDetected && enabledCLIFilter($0) }
    }

    static func mock() -> PetViewModel {
        let vm = PetViewModel()
        vm.state = .idle
        vm.activeSkin = .claude
        vm.hooksAvailable = true
        vm.unlockedAccessories = [.sprout, .battery, .headset, .minidrone, .jetpack, .halo, .codecloud, .cape, .antenna]
        vm.equippedAccessories = [.sprout, .battery, .halo, .antenna]
        vm.cliInfos = [
            CliQuotaInfo(
                id: .claude,
                fetchResult: .success([
                    QuotaTier(id: "five_hour", utilization: 0.33,
                              resetsAt: Date().addingTimeInterval(4940), isEstimated: false),
                    QuotaTier(id: "seven_day", utilization: 0.34,
                              resetsAt: Date().addingTimeInterval(432000), isEstimated: false)
                ]),
                todayTokens: 2_300_000, weekTokens: 8_100_000,
                planBadge: "Pro", isDetected: true
            ),
            CliQuotaInfo(
                id: .opencode,
                fetchResult: .estimated([
                    QuotaTier(id: "rolling", utilization: 0.07,
                              resetsAt: Date().addingTimeInterval(8520), isEstimated: true),
                    QuotaTier(id: "weekly", utilization: 0.50,
                              resetsAt: Date().addingTimeInterval(504000), isEstimated: true)
                ]),
                todayTokens: 1_100_000, weekTokens: 4_200_000,
                planBadge: "Go", isDetected: true
            )
        ]
        vm.totalLifetimeTokens = 42_100_000
        return vm
    }
}
