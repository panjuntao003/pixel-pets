# Quota Monitor MVP Phase A — Implementation Plan (Revised)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewire the PixelPets app from a virtual pet system into a minimal menu-bar AI quota monitor. Disconnect Pixel Pets runtime without deleting source files.

**Architecture:** Replace `AppCoordinator` with `QuotaCoordinator` that fetches quotas from 4 providers sequentially via existing quota clients, stores snapshots in `QuotaStateStore`, and drives a minimal popover UI. Keep all pet source files on disk and in the build target — only the app entry point stops referencing them.

**Tech Stack:** Swift 5.9, SwiftUI, AppKit (NSStatusItem/NSPopover), Combine

**Key constraints:**
- No physical deletion of Pixel Pets files
- SettingsStore keeps old fields for backward compat with pet code still in build target
- enabledProviders uses `[String: Bool]` (rawValue keys) to avoid enum-key Codable issues
- QuotaCoordinator uses sequential async/await (no TaskGroup)
- AIProvider.displayName defined once in AIProvider.swift

---

### Task 1: Create New Data Models

**Files:**
- Create: `PixelPets/Models/QuotaStatus.swift`
- Create: `PixelPets/Models/QuotaSource.swift`
- Create: `PixelPets/Models/ProviderQuotaSnapshot.swift`
- Create: `PixelPets/Models/QuotaStateStore.swift`
- Modify: `PixelPets/Models/AIProvider.swift` — add `displayName`
- Create: `PixelPetsTests/QuotaStateStoreTests.swift`

- [ ] **Step 1: Create QuotaStatus.swift**

```swift
import Foundation

enum QuotaStatus: String, Codable, CaseIterable {
    case normal
    case low
    case exhausted
    case unavailable
    case unknown
}
```

- [ ] **Step 2: Create QuotaSource.swift**

```swift
import Foundation

enum QuotaSource: String, Codable {
    case providerAPI
    case localCLI
    case estimated
    case manual
    case unknown
}
```

- [ ] **Step 3: Add displayName to AIProvider.swift**

Append to `AIProvider.swift`:

```swift
extension AIProvider {
    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .opencode: return "OpenCode"
        case .codex:   return "Codex"
        case .gemini:  return "Gemini"
        case .unknown: return "Unknown"
        }
    }
}
```

- [ ] **Step 4: Create ProviderQuotaSnapshot.swift**

```swift
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
```

- [ ] **Step 5: Create QuotaStateStore.swift**

```swift
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

        if candidates.contains(where: { $0.status == .exhausted }) { return .exhausted }
        if candidates.contains(where: { $0.status == .low }) { return .low }
        if candidates.contains(where: { $0.status == .normal }) { return .normal }
        if candidates.allSatisfy({ $0.status == .unavailable }) { return .unavailable }
        return .unknown
    }
}
```

- [ ] **Step 6: Write QuotaStateStoreTests.swift**

```swift
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
        XCTAssertEqual(primary?.provider, .codex) // prefers normal over low
    }

    private func makeSnapshot(_ prov: AIProvider, _ status: QuotaStatus) -> ProviderQuotaSnapshot {
        ProviderQuotaSnapshot(
            provider: prov, status: status, remainingPercent: status == .normal ? 80 : nil,
            resetAt: nil, lastCheckedAt: Date(), lastSuccessfulAt: status != .unavailable ? Date() : nil,
            source: .providerAPI, message: nil
        )
    }
}
```

- [ ] **Step 7: Run tests**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' -only-testing:PixelPetsTests/QuotaStateStoreTests 2>&1`
Expected: All tests PASS, test count = 8

- [ ] **Step 8: Add new files to Xcode target**

The `project.yml` uses `sources: - path: PixelPets` which auto-includes all Swift files. Verify with:

Run: `xcodebuild -list -project PixelPets.xcodeproj`
Then regenerate project if using XcodeGen: `(cd /Users/panjuntao/Developer/pixel-pets && xcodegen generate --use-cache 2>&1 || echo "XcodeGen not available, verify files appear in Xcode manually")`

- [ ] **Step 9: Commit**

```bash
git add PixelPets/Models/QuotaStatus.swift PixelPets/Models/QuotaSource.swift PixelPets/Models/ProviderQuotaSnapshot.swift PixelPets/Models/QuotaStateStore.swift PixelPets/Models/AIProvider.swift PixelPetsTests/QuotaStateStoreTests.swift
git commit -m "feat(quota): add QuotaStatus, QuotaSource, ProviderQuotaSnapshot, QuotaStateStore, displayName with tests"
```

---

### Task 2: Extract Codex and Gemini Quota Clients

**Files:**
- Create: `PixelPets/Senses/CodexQuotaClient.swift`
- Create: `PixelPets/Senses/GeminiQuotaClient.swift`
- Modify: `PixelPets/Senses/ClaudeQuotaClient.swift` — remove CodexQuotaClient and GeminiQuotaClient classes

- [ ] **Step 1: Create CodexQuotaClient.swift**

Copy the `CodexQuotaClient` class (lines 161–263) from `ClaudeQuotaClient.swift` into the new file:

```swift
import Foundation

final class CodexQuotaClient {
    private static let authFilePath = ".codex/auth.json"
    private static let usageURL = URL(string: "https://chatgpt.com/backend-api/wham/usage")!

    func fetch() async -> QuotaFetchResult {
        guard let token = Self.readAccessToken() else {
            return .unavailable("未找到 Codex ChatGPT 凭据")
        }

        var request = URLRequest(url: Self.usageURL, timeoutInterval: 10)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return .unavailable("Codex 配额 API 请求失败")
            }

            let tiers = Self.parseQuotaTiers(from: data)
            guard !tiers.isEmpty else {
                return .unavailable("Codex 响应中无配额数据")
            }

            return .success(tiers)
        } catch {
            return .unavailable("Codex 配额 API 请求失败")
        }
    }

    static func parseQuotaTiers(from data: Data, now: Date = Date()) -> [QuotaTier] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rateLimit = json["rate_limit"] as? [String: Any]
        else {
            return []
        }

        return [
            quotaTier(id: "five_hour", from: rateLimit["primary_window"], now: now),
            quotaTier(id: "weekly", from: rateLimit["secondary_window"], now: now)
        ].compactMap { $0 }
    }

    private static func quotaTier(id: String, from value: Any?, now: Date) -> QuotaTier? {
        guard
            let window = value as? [String: Any],
            let usedPercent = doubleValue(window["used_percent"])
        else {
            return nil
        }

        return QuotaTier(
            id: id,
            utilization: min(1, max(0, usedPercent / 100)),
            resetsAt: resetDate(from: window, now: now),
            isEstimated: false
        )
    }

    private static func resetDate(from window: [String: Any], now: Date) -> Date? {
        if let resetAt = doubleValue(window["reset_at"]) {
            return Date(timeIntervalSince1970: resetAt)
        }
        if let resetAfter = doubleValue(window["reset_after_seconds"]) {
            return now.addingTimeInterval(resetAfter)
        }
        return nil
    }

    private static func readAccessToken() -> String? {
        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(authFilePath)
        guard let data = try? Data(contentsOf: credentialURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["auth_mode"] as? String == "chatgpt",
              let tokens = json["tokens"] as? [String: Any],
              let token = tokens["access_token"] as? String,
              !token.isEmpty else {
            return nil
        }
        return token
    }

    internal static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case _ as Bool:
            return nil
        default:
            return nil
        }
    }
}
```

- [ ] **Step 2: Create GeminiQuotaClient.swift**

Copy the `GeminiQuotaClient` class (lines 265–458) from `ClaudeQuotaClient.swift` into the new file. Keep all methods identical:

```swift
import Foundation

final class GeminiQuotaClient {
    private static let oauthFilePath = ".gemini/oauth_creds.json"
    private static let tokenURL = URL(string: "https://oauth2.googleapis.com/token")!
    private static let loadCodeAssistURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:loadCodeAssist")!
    private static let retrieveQuotaURL = URL(string: "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota")!
    private static let oauthClientID = "681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com"
    private static let oauthClientSecret = "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"
    private static let iso8601Formatter = ISO8601DateFormatter()

    func fetch() async -> QuotaFetchResult {
        guard let token = await Self.readAccessToken() else {
            return .unavailable("未找到 Gemini CLI 凭据")
        }

        do {
            let loadData = try await Self.postJSON(
                url: Self.loadCodeAssistURL,
                token: token,
                body: [
                    "metadata": [
                        "ideType": "IDE_UNSPECIFIED",
                        "platform": "PLATFORM_UNSPECIFIED",
                        "pluginType": "GEMINI"
                    ]
                ]
            )
            guard let project = Self.parseProject(from: loadData) else {
                return .unavailable("Gemini 响应中无项目数据")
            }

            let quotaData = try await Self.postJSON(
                url: Self.retrieveQuotaURL,
                token: token,
                body: ["project": project]
            )
            let tiers = Self.parseQuotaTiers(from: quotaData)
            guard !tiers.isEmpty else {
                return .unavailable("Gemini 响应中无配额数据")
            }
            return .success(tiers)
        } catch {
            return .unavailable("Gemini 配额 API 请求失败")
        }
    }

    static func parseQuotaTiers(from data: Data) -> [QuotaTier] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let buckets = json["buckets"] as? [[String: Any]]
        else {
            return []
        }

        let proTier      = classTier(id: "pro",        from: buckets) { $0.contains("pro") }
        let flashTier    = classTier(id: "flash",      from: buckets) { $0.contains("flash") && !$0.contains("lite") }
        let flashLiteTier = classTier(id: "flash_lite", from: buckets) { $0.contains("flash") && $0.contains("lite") }

        return [proTier, flashTier, flashLiteTier].compactMap { $0 }
    }

    static func parseProject(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let project = json["cloudaicompanionProject"] as? String, !project.isEmpty {
            return project
        }

        if let project = json["cloudaicompanionProject"] as? [String: Any],
           let id = project["id"] as? String,
           !id.isEmpty {
            return id
        }

        return nil
    }

    private static func classTier(id: String, from buckets: [[String: Any]], matching: (String) -> Bool) -> QuotaTier? {
        let selected = buckets.filter { bucket in
            guard let modelId = bucket["modelId"] as? String else { return false }
            return matching(modelId)
        }
        guard !selected.isEmpty else { return nil }

        let fractions = selected.compactMap { doubleValue($0["remainingFraction"]) }
        guard !fractions.isEmpty else { return nil }

        let avgRemaining = fractions.reduce(0, +) / Double(fractions.count)

        let resetDates = selected.compactMap { bucket -> Date? in
            guard let t = bucket["resetTime"] as? String else { return nil }
            return iso8601Formatter.date(from: t)
        }

        return QuotaTier(
            id: id,
            utilization: min(1, max(0, 1 - avgRemaining)),
            resetsAt: resetDates.min(),
            isEstimated: false
        )
    }

    private static func readAccessToken() async -> String? {
        let credentialURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(oauthFilePath)
        guard let data = try? Data(contentsOf: credentialURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let token = json["access_token"] as? String,
           !token.isEmpty,
           !isExpired(json["expiry_date"]) {
            return token
        }

        guard let refreshToken = json["refresh_token"] as? String, !refreshToken.isEmpty else {
            return nil
        }

        return await refreshAccessToken(refreshToken: refreshToken)
    }

    private static func refreshAccessToken(refreshToken: String) async -> String? {
        var request = URLRequest(url: tokenURL, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "client_id", value: oauthClientID),
            URLQueryItem(name: "client_secret", value: oauthClientSecret),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "grant_type", value: "refresh_token")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        guard
            let (data, response) = try? await URLSession.shared.data(for: request),
            (response as? HTTPURLResponse)?.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["access_token"] as? String,
            !token.isEmpty
        else {
            return nil
        }

        return token
    }

    private static func postJSON(url: URL, token: String, body: [String: Any]) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func isExpired(_ value: Any?) -> Bool {
        guard let expiryMilliseconds = doubleValue(value) else {
            return false
        }
        let expiryDate = Date(timeIntervalSince1970: expiryMilliseconds / 1000)
        return expiryDate.timeIntervalSinceNow < 60
    }

    internal static func doubleValue(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return nil
            }
            return number.doubleValue
        case let double as Double:
            return double
        case let int as Int:
            return Double(int)
        case _ as Bool:
            return nil
        default:
            return nil
        }
    }
}
```

- [ ] **Step 3: Remove extracted classes from ClaudeQuotaClient.swift**

Delete lines 161–458 from `ClaudeQuotaClient.swift`. The file should now contain ONLY the `ClaudeQuotaClient` class (lines 1–159).

Also make `doubleValue` in `ClaudeQuotaClient` `internal` instead of `private` (not strictly needed since each client has its own copy, but cleaner).

- [ ] **Step 4: Run existing quota tests to verify extraction didn't break anything**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' -only-testing:PixelPetsTests/ClaudeQuotaClientTests -only-testing:PixelPetsTests/QuotaStateStoreTests 2>&1`
Expected: All tests PASS, test count for ClaudeQuotaClientTests = 7 + QuotaStateStoreTests = 8

- [ ] **Step 5: Commit**

```bash
git add PixelPets/Senses/CodexQuotaClient.swift PixelPets/Senses/GeminiQuotaClient.swift PixelPets/Senses/ClaudeQuotaClient.swift
git commit -m "refactor(quota): extract CodexQuotaClient and GeminiQuotaClient to separate files"
```

---

### Task 3: Create QuotaCoordinator

**Files:**
- Create: `PixelPets/App/QuotaCoordinator.swift`
- Create: `PixelPetsTests/QuotaCoordinatorTests.swift`

- [ ] **Step 1: Create QuotaCoordinator.swift**

QuotaCoordinator fetches quotas SEQUENTIALLY (no TaskGroup) to avoid MainActor/Sendable issues.

```swift
import Foundation
import Combine

/// Maps a QuotaFetchResult to a ProviderQuotaSnapshot using a configurable low-quota threshold.
/// - estimated results are evaluated with the same utilization + threshold logic as success.
/// - lastSuccessfulAt = checkedAt for both success and estimated.
func mapQuotaFetchResultToSnapshot(
    provider: AIProvider,
    result: QuotaFetchResult,
    checkedAt: Date,
    lowQuotaThreshold: Int = 20
) -> ProviderQuotaSnapshot {
    switch result {
    case .success(let tiers):
        let maxUtilization = tiers.isEmpty ? 0.0 : tiers.map(\.utilization).max() ?? 0.0
        let remaining = (1.0 - maxUtilization) * 100.0
        let soonestReset = tiers.compactMap(\.resetsAt).min()
        let status: QuotaStatus = maxUtilization >= 1.0 ? .exhausted
            : (remaining <= Double(lowQuotaThreshold)) ? .low
            : .normal
        return ProviderQuotaSnapshot(
            provider: provider,
            status: status,
            remainingPercent: remaining,
            resetAt: soonestReset,
            lastCheckedAt: checkedAt,
            lastSuccessfulAt: checkedAt,
            source: .providerAPI,
            message: nil
        )

    case .estimated(let tiers):
        let maxUtilization = tiers.isEmpty ? 0.0 : tiers.map(\.utilization).max() ?? 0.0
        let remaining = (1.0 - maxUtilization) * 100.0
        let soonestReset = tiers.compactMap(\.resetsAt).min()
        let status: QuotaStatus = maxUtilization >= 1.0 ? .exhausted
            : (remaining <= Double(lowQuotaThreshold)) ? .low
            : .normal
        return ProviderQuotaSnapshot(
            provider: provider,
            status: status,
            remainingPercent: remaining,
            resetAt: soonestReset,
            lastCheckedAt: checkedAt,
            lastSuccessfulAt: checkedAt,
            source: .estimated,
            message: nil
        )

    case .unavailable(let reason):
        return ProviderQuotaSnapshot(
            provider: provider,
            status: .unavailable,
            remainingPercent: nil,
            resetAt: nil,
            lastCheckedAt: checkedAt,
            lastSuccessfulAt: nil,
            source: .unknown,
            message: reason
        )
    }
}

@MainActor
final class QuotaCoordinator: ObservableObject {
    let stateStore = QuotaStateStore()
    let settingsStore = SettingsStore()

    private let claudeClient = ClaudeQuotaClient()
    private let codexClient = CodexQuotaClient()
    private let geminiClient = GeminiQuotaClient()
    private let openCodeGoClient = OpenCodeGoQuotaClient()

    private var quotaTimer: Timer?
    private var hasStarted = false

    var enabledProviders: Set<AIProvider> {
        let settings = settingsStore.settings
        var providers = Set<AIProvider>()
        for provider in [AIProvider.claude, AIProvider.codex, AIProvider.gemini, AIProvider.opencode] {
            if settings.isProviderEnabled(provider) {
                providers.insert(provider)
            }
        }
        return providers
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        Task { await refreshAll() }

        let interval = TimeInterval(settingsStore.settings.refreshIntervalSeconds)
        quotaTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAll()
            }
        }
    }

    func refresh() {
        Task { await refreshAll() }
    }

    private func refreshAll() async {
        let threshold = settingsStore.settings.lowQuotaThreshold
        let now = Date()

        for providerProvider in AIProvider.allCases {
            guard providerProvider != .unknown, enabledProviders.contains(providerProvider) else { continue }

            let result: QuotaFetchResult
            switch providerProvider {
            case .claude:
                result = await claudeClient.fetch()
            case .codex:
                result = await codexClient.fetch()
            case .gemini:
                result = await geminiClient.fetch()
            case .opencode:
                result = await openCodeGoClient.fetch()
            case .unknown:
                continue
            }

            let snapshot = mapQuotaFetchResultToSnapshot(
                provider: providerProvider,
                result: result,
                checkedAt: now,
                lowQuotaThreshold: threshold
            )
            stateStore.update(provider: providerProvider, snapshot: snapshot)
        }
    }
}
```

- [ ] **Step 2: Create QuotaCoordinatorTests.swift**

Test the `mapQuotaFetchResultToSnapshot` function (file-level, internal access).

```swift
import XCTest
@testable import PixelPets

final class QuotaCoordinatorTests: XCTestCase {
    func test_mapToSnapshot_successNormal() {
        let tier = QuotaTier(id: "test", utilization: 0.3, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .normal)
        XCTAssertEqual(snapshot.remainingPercent ?? 0, 70, accuracy: 0.01)
        XCTAssertEqual(snapshot.source, .providerAPI)
        XCTAssertNotNil(snapshot.lastSuccessfulAt)
    }

    func test_mapToSnapshot_successLow() {
        let tier = QuotaTier(id: "test", utilization: 0.9, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .low)
    }

    func test_mapToSnapshot_successExhausted() {
        let tier = QuotaTier(id: "test", utilization: 1.0, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
    }

    func test_mapToSnapshot_unavailable() {
        let result = QuotaFetchResult.unavailable("Test unavailable")
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .unavailable)
        XCTAssertEqual(snapshot.message, "Test unavailable")
        XCTAssertNil(snapshot.lastSuccessfulAt)
        XCTAssertEqual(snapshot.source, .unknown)
    }

    func test_mapToSnapshot_estimatedNormal() {
        let tier = QuotaTier(id: "test", utilization: 0, resetsAt: nil, isEstimated: true)
        let result = QuotaFetchResult.estimated([tier])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .opencode, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.source, .estimated)
        XCTAssertEqual(snapshot.status, .normal)
        XCTAssertNotNil(snapshot.lastSuccessfulAt)
    }

    func test_mapToSnapshot_estimatedExhausted() {
        let tier = QuotaTier(id: "test", utilization: 1.0, resetsAt: nil, isEstimated: true)
        let result = QuotaFetchResult.estimated([tier])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .opencode, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.status, .exhausted)
        XCTAssertEqual(snapshot.source, .estimated)
    }

    func test_mapToSnapshot_usesSoonestReset() {
        let soonest = Date().addingTimeInterval(3600)
        let later = Date().addingTimeInterval(7200)
        let t1 = QuotaTier(id: "a", utilization: 0.1, resetsAt: later, isEstimated: false)
        let t2 = QuotaTier(id: "b", utilization: 0.2, resetsAt: soonest, isEstimated: false)
        let result = QuotaFetchResult.success([t1, t2])
        let snapshot = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date())
        XCTAssertEqual(snapshot.resetAt, soonest)
    }

    func test_mapToSnapshot_respectsThreshold() {
        let tier = QuotaTier(id: "test", utilization: 0.5, resetsAt: nil, isEstimated: false)
        let result = QuotaFetchResult.success([tier])
        // remaining = 50%, threshold = 30 → normal
        let snapshot1 = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date(), lowQuotaThreshold: 30)
        XCTAssertEqual(snapshot1.status, .normal)
        // remaining = 50%, threshold = 60 → low (50 <= 60)
        let snapshot2 = mapQuotaFetchResultToSnapshot(provider: .claude, result: result, checkedAt: Date(), lowQuotaThreshold: 60)
        XCTAssertEqual(snapshot2.status, .low)
    }

    func test_enabledProviders_defaultAllEnabled() {
        let coordinator = QuotaCoordinator()
        let providers = coordinator.enabledProviders
        XCTAssertTrue(providers.contains(.claude))
        XCTAssertTrue(providers.contains(.codex))
        XCTAssertTrue(providers.contains(.gemini))
        XCTAssertTrue(providers.contains(.opencode))
    }

    func test_enabledProviders_respectsSettings() {
        let coordinator = QuotaCoordinator()
        coordinator.settingsStore.update { $0.enabledProviders["codex"] = false }
        let providers = coordinator.enabledProviders
        XCTAssertFalse(providers.contains(.codex))
        XCTAssertTrue(providers.contains(.claude))
    }
}
```

- [ ] **Step 3: Run tests**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' -only-testing:PixelPetsTests/QuotaCoordinatorTests -only-testing:PixelPetsTests/QuotaStateStoreTests 2>&1`
Expected: All tests PASS, test count = 10 (Coordinator) + 8 (StateStore) = 18

- [ ] **Step 4: Commit**

```bash
git add PixelPets/App/QuotaCoordinator.swift PixelPetsTests/QuotaCoordinatorTests.swift
git commit -m "feat(quota): add QuotaCoordinator with sequential refresh and snapshot mapping"
```

---

### Task 4: Create MenuBarDotView

**Files:**
- Create: `PixelPets/UI/MenuBarDotView.swift`

- [ ] **Step 1: Create MenuBarDotView.swift**

```swift
import SwiftUI

struct MenuBarDotView: View {
    let status: QuotaStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 12, height: 12)
    }

    var color: Color {
        switch status {
        case .normal:    return .green
        case .low:       return .yellow
        case .exhausted: return .red
        case .unavailable: return .gray
        case .unknown:   return .gray.opacity(0.5)
        }
    }

    var tooltip: String {
        switch status {
        case .normal:    return "All quotas normal"
        case .low:       return "Low quota"
        case .exhausted: return "Quota exhausted"
        case .unavailable: return "No providers available"
        case .unknown:   return "Checking..."
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add PixelPets/UI/MenuBarDotView.swift
git commit -m "feat(quota): add MenuBarDotView colored status indicator"
```

---

### Task 5: Rewrite PopoverView and Create QuotaCardView

**Files:**
- Rewrite: `PixelPets/UI/PopoverView.swift`
- Create: `PixelPets/UI/QuotaCardView.swift`

- [ ] **Step 1: Create QuotaCardView.swift**

```swift
import SwiftUI

struct QuotaCardView: View {
    let provider: AIProvider
    let snapshot: ProviderQuotaSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(provider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            if let snapshot {
                if let percent = snapshot.remainingPercent, snapshot.status != .unavailable {
                    Text("\(Int(percent))% remaining")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                statusLabel(for: snapshot)

                if let resetAt = snapshot.resetAt, snapshot.status != .unavailable {
                    Text(resetAtDisplay(resetAt))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Text(timeDisplay(for: snapshot))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Not checked yet")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    @ViewBuilder
    private func statusLabel(for snapshot: ProviderQuotaSnapshot) -> some View {
        switch snapshot.status {
        case .normal:
            Text("Normal").font(.system(size: 12)).foregroundStyle(.green)
        case .low:
            Text("Low").font(.system(size: 12)).foregroundStyle(.yellow)
        case .exhausted:
            Text("Exhausted").font(.system(size: 12)).foregroundStyle(.red)
        case .unavailable:
            Text(snapshot.message ?? "Unavailable").font(.system(size: 12)).foregroundStyle(.secondary)
        case .unknown:
            Text("Unknown").font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch snapshot?.status {
        case .normal:    return .green
        case .low:       return .yellow
        case .exhausted: return .red
        case .unavailable: return .gray
        case .unknown, .none: return .gray.opacity(0.5)
        }
    }

    private func resetAtDisplay(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return "Resetting..." }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        if h >= 24 { return "Resets in \(h/24)d \(h%24)h" }
        if h > 0 { return "Resets in \(h)h \(m)m" }
        return "Resets in \(m)m"
    }

    private func timeDisplay(for snapshot: ProviderQuotaSnapshot) -> String {
        if let successAt = snapshot.lastSuccessfulAt {
            return "Updated \(relativeTime(from: successAt))"
        } else {
            return "Last checked \(relativeTime(from: snapshot.lastCheckedAt))"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60)) min ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}
```

- [ ] **Step 2: Rewrite PopoverView.swift**

Replace entire file. Uses `QuotaStateStore` and `SettingsStore`, references `AIProvider.displayName` (defined in AIProvider.swift, NOT duplicated here).

```swift
import AppKit
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @ObservedObject var stateStore: QuotaStateStore
    var onRefresh: () -> Void = {}

    private var enabledProviders: [AIProvider] {
        AIProvider.allCases.filter { settingsStore.settings.isProviderEnabled($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Quota Monitor")
                .font(.system(size: 13, weight: .bold))
                .padding(.top, 12)
                .padding(.bottom, 8)

            if enabledProviders.isEmpty {
                noProvidersView
            } else {
                VStack(spacing: 8) {
                    ForEach(enabledProviders, id: \.self) { provider in
                        QuotaCardView(
                            provider: provider,
                            snapshot: stateStore.snapshot(for: provider)
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            HStack {
                if let refreshedAt = stateStore.lastRefreshAt {
                    Text("Refreshed \(relativeTime(from: refreshedAt))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Refresh quotas")
                SettingsLink {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }

    private var noProvidersView: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("No providers enabled")
                .font(.system(size: 13, weight: .medium))
            Text("Enable at least one provider in Settings")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            SettingsLink {
                Text("Open Settings")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
    }

    private func relativeTime(from date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval/60)) min ago" }
        if interval < 86400 { return "\(Int(interval/3600))h ago" }
        return "\(Int(interval/86400))d ago"
    }
}
```

Note: No duplicate `AIProvider.displayName` extension here — it's in `AIProvider.swift`.

- [ ] **Step 3: Commit**

```bash
git add PixelPets/UI/PopoverView.swift PixelPets/UI/QuotaCardView.swift
git commit -m "feat(quota): rewrite PopoverView with QuotaCardView for minimal quota display"
```

---

### Task 6: Extend SettingsStore with Quota Fields (Preserve Old API)

**Files:**
- Modify: `PixelPets/Persistence/SettingsStore.swift` — add quota fields, keep ALL old fields
- Rewrite: `PixelPets/UI/Settings/GameSettingsView.swift` — switch to quota-only UI
- Modify: `PixelPetsTests/SettingsStoreTests.swift` — add tests for new fields

- [ ] **Step 1: Extend AppSettings with new quota fields**

In `SettingsStore.swift`, ADD the following fields to `AppSettings` WITHOUT removing any existing fields:

Add after the existing `enabledEventSources` field:

```swift
    // Quota Monitor fields (Phase A)
    var lowQuotaThreshold: Int = 20
    var refreshIntervalSeconds: Int = 300
    var enabledProviders: [String: Bool] = [:]  // key = AIProvider.rawValue
```

Add CodingKeys entries:

```
        // Quota Monitor
        case lowQuotaThreshold, refreshIntervalSeconds, enabledProviders
```

Add decoder defaults in `init(from:)`:

```swift
        lowQuotaThreshold = try container.decodeIfPresent(Int.self, forKey: .lowQuotaThreshold) ?? 20
        refreshIntervalSeconds = try container.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds) ?? 300
        enabledProviders = try container.decodeIfPresent([String: Bool].self, forKey: .enabledProviders) ?? [:]
```

Add the `isProviderEnabled` method (keep existing `isEnabled(_ skin:)` method for pet code compatibility):

```swift
    func isProviderEnabled(_ provider: AIProvider) -> Bool {
        enabledProviders[provider.rawValue] != false
    }
```

The final `AppSettings` struct should have BOTH old and new fields. Full list of fields:
- OLD: `hookPermissionAsked`, `enabledCLIs`, `hookPort`, `scenePreference`, `equippedAccessories`, `skinOverride`, `isPixelPetEnabled`, `animationIntensity`, `lowDistractionMode`, `reduceMotion`, `enableQuotaAlerts`, `enabledEventSources`
- NEW: `lowQuotaThreshold`, `refreshIntervalSeconds`, `enabledProviders`

And both `isEnabled(_ skin: AgentSkin)` and `isProviderEnabled(_ provider: AIProvider)` methods coexist.

- [ ] **Step 2: Rewrite GameSettingsView.swift**

Replace content with quota-only settings UI. Remove pet tab navigation (Unit/Loadout/Map), show only Quota Monitor tab.

```swift
import SwiftUI

struct GameSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore
    var onRegisterHooks: () -> Void = {}

    var body: some View {
        QuotaSettingsView()
            .environmentObject(settingsStore)
            .frame(width: 400, height: 320)
    }
}

struct QuotaSettingsView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(AIProvider.allCases.filter { $0 != .unknown }, id: \.self) { provider in
                    Toggle(provider.displayName, isOn: Binding(
                        get: { settingsStore.settings.isProviderEnabled(provider) },
                        set: { enabled in
                            settingsStore.update { settings in
                                if enabled {
                                    settings.enabledProviders[provider.rawValue] = true
                                } else {
                                    settings.enabledProviders[provider.rawValue] = false
                                }
                            }
                        }
                    ))
                }
            }

            Section("Thresholds") {
                HStack {
                    Text("Low quota threshold")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.lowQuotaThreshold },
                        set: { newValue in
                            settingsStore.update { settings in
                                settings.lowQuotaThreshold = newValue
                            }
                        }
                    )) {
                        Text("10%").tag(10)
                        Text("20%").tag(20)
                        Text("30%").tag(30)
                        Text("50%").tag(50)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 80)
                }
            }

            Section("Refresh") {
                HStack {
                    Text("Auto-refresh interval")
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settingsStore.settings.refreshIntervalSeconds },
                        set: { newValue in
                            settingsStore.update { settings in
                                settings.refreshIntervalSeconds = newValue
                            }
                        }
                    )) {
                        Text("1 min").tag(60)
                        Text("5 min").tag(300)
                        Text("15 min").tag(900)
                        Text("30 min").tag(1800)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 100)
                }
            }

            Section {
                HStack {
                    Text("Enable Pixel Pet")
                    Spacer()
                    Text("Coming later")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 3: Update SettingsStoreTests.swift**

Add new test methods to the EXISTING test file (do not delete old tests). Append these tests:

```swift
    // MARK: - Quota Monitor fields (Phase A)

    func test_defaults_lowQuotaThreshold_is20() {
        XCTAssertEqual(store.settings.lowQuotaThreshold, 20)
    }

    func test_defaults_refreshInterval_is300() {
        XCTAssertEqual(store.settings.refreshIntervalSeconds, 300)
    }

    func test_defaults_enabledProviders_empty_allEnabled() {
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
        XCTAssertTrue(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.gemini))
        XCTAssertTrue(store.settings.isProviderEnabled(.opencode))
    }

    func test_enabledProviders_explicitFalseDisables() {
        store.update { $0.enabledProviders["codex"] = false }
        XCTAssertFalse(store.settings.isProviderEnabled(.codex))
        XCTAssertTrue(store.settings.isProviderEnabled(.claude))
    }

    func test_lowQuotaThreshold_roundtrips() {
        store.update { $0.lowQuotaThreshold = 30 }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.lowQuotaThreshold, 30)
    }

    func test_refreshInterval_roundtrips() {
        store.update { $0.refreshIntervalSeconds = 900 }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 900)
    }

    func test_enabledProviders_roundtrips() {
        store.update { $0.enabledProviders["gemini"] = false }
        let store2 = SettingsStore(directory: tempDir.path)
        XCTAssertFalse(store2.settings.isProviderEnabled(.gemini))
    }

    func test_oldLegacyJSON_loadsWithNewDefaults() {
        let path = tempDir.appendingPathComponent("settings.json").path
        let json = #"{"hookPort":9000,"hookPermissionAsked":true}"#
        FileManager.default.createFile(atPath: path, contents: Data(json.utf8))
        let store2 = SettingsStore(directory: tempDir.path)
        // Old fields preserved
        XCTAssertEqual(store2.settings.hookPort, 9000)
        XCTAssertTrue(store2.settings.hookPermissionAsked)
        // New fields get defaults
        XCTAssertEqual(store2.settings.lowQuotaThreshold, 20)
        XCTAssertEqual(store2.settings.refreshIntervalSeconds, 300)
    }
```

- [ ] **Step 4: Run settings tests**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' -only-testing:PixelPetsTests/SettingsStoreTests 2>&1`
Expected: All existing + new tests PASS, test count increases by 8

- [ ] **Step 5: Commit**

```bash
git add PixelPets/Persistence/SettingsStore.swift PixelPets/UI/Settings/GameSettingsView.swift PixelPetsTests/SettingsStoreTests.swift
git commit -m "feat(quota): extend SettingsStore with quota fields, simplify settings UI"
```

---

### Task 7: Rewire App Entry Point

**Files:**
- Rewrite: `PixelPets/App/PixelPetsApp.swift` — slim @main, delegate to AppDelegate
- Rewrite: `PixelPets/App/AppDelegate.swift` (file didn't exist before — AppDelegate was inside PixelPetsApp.swift)

Note: Currently `AppDelegate` is defined inside `PixelPetsApp.swift` (lines 20–152). We extract it to its own file.

- [ ] **Step 1: Create AppDelegate.swift**

Create a new file: `PixelPets/App/AppDelegate.swift`

```swift
import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    let coordinator = QuotaCoordinator()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []

    // NOTE: AssetRegistry, AnimationClock, HookServer, Debug HUD are NOT initialized.
    // Pixel Pets runtime is fully disconnected.

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        coordinator.start()
        coordinator.stateStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
        coordinator.settingsStore.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
        updateMenuBarIcon()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.imagePosition = .imageOnly
        item.button?.target = self
        item.button?.action = #selector(togglePopover)
        statusItem = item
    }

    private func updateMenuBarIcon() {
        let status = coordinator.stateStore.overallStatus(among: coordinator.enabledProviders)
        let renderer = ImageRenderer(content: MenuBarDotView(status: status))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let size = NSSize(width: 18, height: 18)
        guard let cgImage = renderer.cgImage else {
            statusItem?.button?.image = NSImage(
                systemSymbolName: "circle.fill",
                accessibilityDescription: "Quota"
            )
            return
        }
        let image = NSImage(cgImage: cgImage, size: size)
        image.isTemplate = false
        statusItem?.button?.image = image
        statusItem?.button?.toolTip = MenuBarDotView(status: status).tooltip
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 280, height: 380)
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(
                stateStore: coordinator.stateStore,
                onRefresh: { [weak self] in
                    self?.coordinator.refresh()
                }
            )
            .environmentObject(coordinator.settingsStore)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
```

- [ ] **Step 2: Rewrite PixelPetsApp.swift**

Trim to the minimum — just the @main struct and Settings scene:

```swift
import AppKit
import SwiftUI

@main
struct PixelPetsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            GameSettingsView()
                .environmentObject(appDelegate.coordinator.settingsStore)
        }
    }
}
```

- [ ] **Step 3: Remove old PixelPets code from PixelPetsApp.swift**

The old `PixelPetsApp.swift` had AppDelegate embedded (lines 20–152). After this step, `PixelPetsApp.swift` should be ONLY the @main struct (15 lines). The AppDelegate class exists in its own file.

- [ ] **Step 4: Verify compilation**

Run: `xcodebuild -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add PixelPets/App/PixelPetsApp.swift PixelPets/App/AppDelegate.swift
git commit -m "feat(quota): rewire entry point to QuotaCoordinator, extract AppDelegate to own file"
```

---

### Task 8: Run Full Test Suite and Fix Regressions

- [ ] **Step 1: Run ALL existing tests**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' 2>&1`
Expected: As many tests as possible should PASS. Investigation if failures exist.

- [ ] **Step 2: Investigate any failing tests**

Common failure causes and fixes:

**If SettingsStoreTests fail:** Check that old fields/API were preserved in Step 1 of Task 6. The `isEnabled(_ skin: AgentSkin)` method and old CodingKeys must still exist.

**If AppCoordinatorTests fail:** `AppCoordinator` references `PetViewModel`, `GrowthEngine`, `HookServer` etc. These classes exist in the project but `AppCoordinator` may fail if it tries to create objects that read settings with new defaults. This is acceptable — the test validates old pet behavior that is no longer on the main path. Note these tests for Phase B.

**If test count doesn't increase:** Verify new test files are in the Xcode target. Run `xcodegen generate` or manually add to `project.yml`.

- [ ] **Step 3: Focus on quota-related tests**

Run: `xcodebuild test -project PixelPets.xcodeproj -scheme PixelPets -destination 'platform=macOS' -only-testing:PixelPetsTests/QuotaStateStoreTests -only-testing:PixelPetsTests/QuotaCoordinatorTests -only-testing:PixelPetsTests/SettingsStoreTests -only-testing:PixelPetsTests/ClaudeQuotaClientTests 2>&1`
Expected: All these tests PASS with correct test counts

- [ ] **Step 4: Document test results**

Capture the output of the full test run. Note which tests pass and which fail (if any). Record in the Phase A report.

- [ ] **Step 5: Commit (only if test file modifications were needed)**

```bash
git add -A && git commit -m "test: Phase A test fixups"
```

---

### Task 9: Phase A Implementation Report

- [ ] **Step 1: Create implementation report**

Write `docs/superpowers/reports/2026-05-05-phase-a-report.md`:

```markdown
# Phase A Implementation Report — Quota Monitor MVP

**Date:** 2026-05-05
**Status:** [Complete]

## Summary
Rewired PixelPets from virtual pet system to minimal menu-bar quota monitor.
All Pixel Pets source files retained on disk and in build target.

## Files Created
| File | Purpose |
|------|---------|
| Models/QuotaStatus.swift | Quota state enum |
| Models/QuotaSource.swift | Data source enum |
| Models/ProviderQuotaSnapshot.swift | Per-provider snapshot |
| Models/QuotaStateStore.swift | Snapshot aggregator |
| App/QuotaCoordinator.swift | Quota fetch orchestrator |
| App/AppDelegate.swift | Menu bar + popover delegate |
| Senses/CodexQuotaClient.swift | Codex quota client (extracted) |
| Senses/GeminiQuotaClient.swift | Gemini quota client (extracted) |
| UI/MenuBarDotView.swift | Colored status dot |
| UI/QuotaCardView.swift | Provider card component |
| Tests/QuotaStateStoreTests.swift | 8 tests |
| Tests/QuotaCoordinatorTests.swift | 10 tests |

## Files Modified
| File | Changes |
|------|---------|
| App/PixelPetsApp.swift | Slim @main, delegate to AppDelegate |
| Persistence/SettingsStore.swift | Added quota fields, kept all old fields |
| Senses/ClaudeQuotaClient.swift | Removed extracted Codex/Gemini classes |
| Models/AIProvider.swift | Added displayName extension |
| UI/PopoverView.swift | Rewritten for quota cards |
| UI/Settings/GameSettingsView.swift | Quota-only settings UI |
| Tests/SettingsStoreTests.swift | +8 quota field tests |

## Runtime Verification
- [x] AssetRegistry not initialized
- [x] AnimationClock not started
- [x] HookServer not started
- [x] Debug HUD not displayed
- [x] No pet rendering on main execution path
- [x] No asset loading at startup

## Test Results
- QuotaStateStoreTests: []
- QuotaCoordinatorTests: []
- SettingsStoreTests (old + new): []
- ClaudeQuotaClientTests: []
- Full suite: []

## Known Issues
[List any test failures, especially pet-dependent tests]

## Phase B Readiness
- All Pixel Pets source files retained on disk
- Old SettingsStore fields preserved
- isEnabled(_ skin:) method preserved for pet code compat
- HookServer / log parsers audit: pending
```

- [ ] **Step 2: Commit report**

```bash
git add docs/superpowers/reports/2026-05-05-phase-a-report.md
git commit -m "docs: Phase A implementation report"
```

---

### Summary of Adjustments from Original Plan

| # | Adjustment | Applied |
|---|-----------|---------|
| 1 | SettingsStore keeps old fields | Task 6 adds quota fields without removing old ones |
| 2 | AppDelegate in separate file | Task 7 creates `App/AppDelegate.swift` |
| 3 | enabledProviders uses `[String: Bool]` | key = `provider.rawValue` (String) |
| 4 | displayName defined once in AIProvider.swift | Task 1 Step 3, no duplicates in PopoverView or Settings |
| 5 | Picker Binding uses named params | `set: { newValue in settings.update { settings in ... } }` |
| 6 | Xcode target verified | Project uses auto-include via `project.yml`, verified in Task 8 |
| 7 | QuotaCoordinator sequential (no TaskGroup) | `for provider in ... { await fetch() }` |
| 8 | mapQuotaFetchResultToSnapshot fixes | lastSuccessfulAt = checkedAt, estimated uses threshold logic, source preserved |
| 9 | Don't skip failing pet tests | Task 8 investigates and documents, does not skip |
| 10 | Phase A constraints respected | No deletions, no assets, no FX, no history, no pet runtime |
