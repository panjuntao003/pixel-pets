import Foundation
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    let viewModel = PetViewModel()

    private let stateMachine = PetStateMachine()
    private let growthEngine = GrowthEngine()
    private let growthStore = GrowthStore()
    private let hookServer = HookServer()
    private let hookRegistrar = HookRegistrar()
    private let claudeLogEventSource = ClaudeLogEventSource()
    private let openCodeLogEventSource = OpenCodeLogEventSource()
    private let claudeQuotaClient = ClaudeQuotaClient()
    private let codexQuotaClient = CodexQuotaClient()
    private let geminiQuotaClient = GeminiQuotaClient()
    private let openCodeGoQuotaClient = OpenCodeGoQuotaClient()
    let settingsStore = SettingsStore()
    private lazy var logPoller = LogPoller(growthStore: growthStore)

    private var hasStarted = false
    private var logPollTimer: Timer?
    private var quotaTimer: Timer?
    private var evolutionTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var latestClaudeRateLimitResult: QuotaFetchResult?
    private var latestClaudeRateLimitUpdatedAt: Date?

    @Published var hookPermissionOptions: [CLIHookOption] = []
    @Published private(set) var shouldShowHookPermission = false

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        ensureInstalledAt()
        viewModel.enabledCLIFilter = { [weak self] info in
            self?.settingsStore.settings.isEnabled(info.id) ?? true
        }
        settingsStore.$settings
            .sink { [weak self] _ in
                self?.viewModel.objectWillChange.send()
            }
            .store(in: &cancellables)
        restoreGrowth()
        if let override = settingsStore.settings.skinOverride,
           let skin = AgentSkin(rawValue: override) {
            viewModel.activeSkin = skin
        }
        settingsStore.$settings
            .map(\.equippedAccessories)
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                let unlocked = self.viewModel.unlockedAccessories
                let equipped = self.settingsStore.settings.equippedAccessories.compactMap { (_, accRaw) -> Accessory? in
                    guard let acc = Accessory(rawValue: accRaw), unlocked.contains(acc) else { return nil }
                    return acc
                }
                self.viewModel.equippedAccessories = equipped
            }
            .store(in: &cancellables)
        refreshDetectedCLIs()
        configureHooksIfPossible()
        startHookServer()
        ActivityCoordinator.shared.start(sources: [
            claudeLogEventSource,
            openCodeLogEventSource,
            ManualDebugEventSource.shared
        ])
        refreshTokenUsage()
        refreshQuota()
        prepareHookPermissionPromptIfNeeded()

        logPollTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshTokenUsage()
                self?.refreshDetectedCLIs()
            }
        }
        quotaTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshQuota()
            }
        }
    }

    func refresh() {
        refreshTokenUsage()
        refreshDetectedCLIs()
        refreshQuota()
    }

    func refreshQuota() {
        Task {
            await refreshClaudeQuota()
            applyQuotaRecommendation()
        }
    }

    func registerDetectedHooks() {
        configureHooksIfPossible(register: true)
    }

    func confirmHookPermissionSelection() {
        settingsStore.hookPermissionAsked = true
        shouldShowHookPermission = false
        registerSelectedHooks()
    }

    func skipHookPermissionPrompt() {
        settingsStore.hookPermissionAsked = true
        shouldShowHookPermission = false
    }

    private func ensureInstalledAt() {
        if growthStore.loadInstalledAt() == nil {
            growthStore.saveInstalledAt(Date())
        }
    }

    private func restoreGrowth() {
        applyGrowth(totalTokens: growthStore.loadTotalTokens())
    }

    private func startHookServer() {
        hookServer.onEvent = { [weak self] event, payload in
            Task { @MainActor in
                self?.handleHookEvent(event, payload: payload)
            }
        }
        hookServer.start()
    }

    private func handleHookEvent(_ event: String, payload: [String: Any]) {
        claudeLogEventSource.handleHook(event: event, payload: payload)
        stateMachine.handle(event, payload)
        // viewModel.state is now updated via ActivityCoordinator -> viewModel.visualState

        if settingsStore.settings.skinOverride == nil,
           let agent = payload["agent"] as? String,
           let skin = AgentSkin(rawValue: agent),
           settingsStore.settings.isEnabled(skin) {
            viewModel.activeSkin = skin
        }

        if let agent = payload["agent"] as? String, let skin = AgentSkin(rawValue: agent) {
            if skin == .claude, let result = Self.claudeRateLimitFetchResult(from: payload) {
                latestClaudeRateLimitResult = result
                latestClaudeRateLimitUpdatedAt = Date()
                updateCLIInfo(skin: .claude, fetchResult: result, planBadge: "Claude")
            }
        }

        refreshTokenUsage()
    }

    private func refreshTokenUsage() {
        let snapshot = logPoller.poll()
        applyGrowth(totalTokens: max(snapshot.lifetimeTokens, growthStore.loadTotalTokens()))

        for (skin, usage) in snapshot.usageByCLI {
            updateCLIInfo(
                skin: skin,
                fetchResult: estimatedFetchResultIfNeeded(skin: skin, usage: usage),
                todayTokens: usage.todayTokens,
                weekTokens: usage.weekTokens,
                planBadge: skin.displayName
            )
        }
        applyQuotaRecommendation()
    }

    private func applyGrowth(totalTokens: Int) {
        let previous = viewModel.totalLifetimeTokens
        let (level, accessories) = growthEngine.compute(totalTokens: totalTokens)
        viewModel.totalLifetimeTokens = totalTokens
        viewModel.level = level
        viewModel.unlockedAccessories = accessories
        let equipped = settingsStore.settings.equippedAccessories.compactMap { (slotRaw, accRaw) -> Accessory? in
            guard let acc = Accessory(rawValue: accRaw), accessories.contains(acc) else { return nil }
            return acc
        }
        viewModel.equippedAccessories = equipped
        growthStore.saveTotalTokens(totalTokens)
        growthStore.saveUnlockedAccessories(accessories)

        if !growthEngine.newMilestones(from: previous, to: totalTokens).isEmpty {
            stateMachine.forceEvolve()
            viewModel.state = .evolving
            evolutionTimer?.invalidate()
            evolutionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, self.viewModel.state == .evolving else { return }
                    self.stateMachine.handle("SessionEnd", [:])
                    self.viewModel.state = self.stateMachine.currentState
                }
            }
        }
    }

    private func refreshDetectedCLIs() {
        for registration in hookRegistrar.detectAll() {
            setDetected(registration.detected, for: registration.cli)
        }
        validateSkinOverride()
    }

    private func validateSkinOverride() {
        guard let override = settingsStore.settings.skinOverride else {
            return
        }

        guard let skin = AgentSkin(rawValue: override),
              isDetectedAndEnabled(skin) else {
            settingsStore.update {
                $0.skinOverride = nil
            }
            viewModel.activeSkin = fallbackActiveSkin()
            return
        }

        viewModel.activeSkin = skin
    }

    private func fallbackActiveSkin() -> AgentSkin {
        if isDetectedAndEnabled(viewModel.activeSkin) {
            return viewModel.activeSkin
        }

        if let detectedSkin = viewModel.cliInfos.first(where: { info in
            info.isDetected && settingsStore.settings.isEnabled(info.id)
        })?.id {
            return detectedSkin
        }

        return AgentSkin.allCases.first(where: { settingsStore.settings.isEnabled($0) }) ?? .claude
    }

    private func isDetectedAndEnabled(_ skin: AgentSkin) -> Bool {
        settingsStore.settings.isEnabled(skin)
            && viewModel.cliInfos.first(where: { $0.id == skin })?.isDetected == true
    }

    private func configureHooksIfPossible(register: Bool = false) {
        switch NodeGate.detect() {
        case .available(let path):
            hookRegistrar.setNodePath(path)
            viewModel.hooksAvailable = true
            if register {
                for registration in hookRegistrar.detectAll()
                    where registration.detected && registration.canRegister {
                    hookRegistrar.register(cli: registration.cli)
                }
            }
        case .unavailable:
            viewModel.hooksAvailable = false
        }
    }

    private func prepareHookPermissionPromptIfNeeded() {
        guard viewModel.hooksAvailable, !settingsStore.hookPermissionAsked else {
            return
        }

        let options = hookRegistrar.detectAll().map {
            CLIHookOption(
                id: $0.cli,
                configPath: $0.configPath,
                enabled: $0.detected && $0.canRegister,
                detected: $0.detected,
                canRegister: $0.canRegister
            )
        }
        hookPermissionOptions = options
        shouldShowHookPermission = options.contains { $0.detected && $0.canRegister }
    }

    private func registerSelectedHooks() {
        switch NodeGate.detect() {
        case .available(let path):
            hookRegistrar.setNodePath(path)
            for option in hookPermissionOptions where option.enabled && option.detected && option.canRegister {
                hookRegistrar.register(cli: option.id)
            }
        case .unavailable:
            viewModel.hooksAvailable = false
        }
    }

    private func refreshClaudeQuota() async {
        let result = Self.preferredClaudeQuotaFetchResult(
            apiResult: await claudeQuotaClient.fetch(),
            hookResult: latestClaudeRateLimitResult,
            hookUpdatedAt: latestClaudeRateLimitUpdatedAt
        )
        updateCLIInfo(skin: .claude, fetchResult: result, planBadge: "Claude")
        let codexResult = await codexQuotaClient.fetch()
        updateCLIInfo(skin: .codex, fetchResult: codexResult, planBadge: "ChatGPT")
        let geminiResult = await geminiQuotaClient.fetch()
        updateCLIInfo(skin: .gemini, fetchResult: geminiResult, planBadge: "Gemini")
        let openCodeGoResult = await openCodeGoQuotaClient.fetch()
        updateCLIInfo(skin: .opencode, fetchResult: openCodeGoResult, planBadge: "Go")
    }

    private func estimatedFetchResultIfNeeded(skin: AgentSkin, usage: UsageWindow) -> QuotaFetchResult? {
        switch skin {
        case .claude, .codex, .gemini:
            return nil
        case .opencode:
            return nil
        }
    }

    private func applyQuotaRecommendation() {
        let recommendation = QuotaMonitor.recommendation(for: viewModel.cliInfos)
        if recommendation == .sleeping {
            claudeLogEventSource.push(.quotaLow)
        }
        stateMachine.applyQuotaRecommendation(recommendation)
    }

    private func updateCLIInfo(
        skin: AgentSkin,
        fetchResult: QuotaFetchResult? = nil,
        todayTokens: Int? = nil,
        weekTokens: Int? = nil,
        planBadge: String? = nil
    ) {
        if let index = viewModel.cliInfos.firstIndex(where: { $0.id == skin }) {
            if let fetchResult {
                viewModel.cliInfos[index].fetchResult = fetchResult
            }
            if let todayTokens {
                viewModel.cliInfos[index].todayTokens = todayTokens
            }
            if let weekTokens {
                viewModel.cliInfos[index].weekTokens = weekTokens
            }
            if let planBadge {
                viewModel.cliInfos[index].planBadge = planBadge
            }
            return
        }

        viewModel.cliInfos.append(CliQuotaInfo(
            id: skin,
            fetchResult: fetchResult ?? .unavailable("未检测到"),
            todayTokens: todayTokens ?? 0,
            weekTokens: weekTokens ?? 0,
            planBadge: planBadge ?? "",
            isDetected: false
        ))
    }

    private func setDetected(_ detected: Bool, for skin: AgentSkin) {
        updateCLIInfo(skin: skin)
        guard let index = viewModel.cliInfos.firstIndex(where: { $0.id == skin }) else {
            return
        }
        viewModel.cliInfos[index].isDetected = detected
        if detected, viewModel.cliInfos[index].unavailableReason == "未检测到" {
            viewModel.cliInfos[index].fetchResult = Self.detectedPlaceholderFetchResult(for: skin)
        }
    }

    static func detectedPlaceholderFetchResult(for skin: AgentSkin) -> QuotaFetchResult {
        switch skin {
        case .claude, .codex, .gemini:
            return .unavailable("正在读取配额")
        case .opencode:
            return .unavailable("正在读取配额")
        }
    }

    static func claudeRateLimitFetchResult(from payload: [String: Any]) -> QuotaFetchResult? {
        guard let rateLimits = payload["rate_limits"] as? [String: Any] else {
            return nil
        }

        let tiers = [
            claudeRateLimitTier(id: "five_hour", from: rateLimits["five_hour"]),
            claudeRateLimitTier(id: "seven_day", from: rateLimits["seven_day"])
        ].compactMap { $0 }

        return tiers.isEmpty ? nil : .success(tiers)
    }

    static func preferredClaudeQuotaFetchResult(
        apiResult: QuotaFetchResult,
        hookResult: QuotaFetchResult?,
        hookUpdatedAt: Date?,
        now: Date = Date()
    ) -> QuotaFetchResult {
        guard
            let hookResult,
            let hookUpdatedAt,
            now.timeIntervalSince(hookUpdatedAt) <= 10 * 60
        else {
            return apiResult
        }

        return hookResult
    }

    private static func claudeRateLimitTier(id: String, from value: Any?) -> QuotaTier? {
        guard
            let window = value as? [String: Any],
            let usedPercentage = doubleValue(window["used_percentage"])
        else {
            return nil
        }

        return QuotaTier(
            id: id,
            utilization: min(1, max(0, usedPercentage / 100)),
            resetsAt: nil,
            isEstimated: false
        )
    }

    private static func doubleValue(_ value: Any?) -> Double? {
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

struct UsageWindow {
    var todayTokens: Int
    var weekTokens: Int
}

struct LogPollSnapshot {
    var lifetimeTokens: Int
    var usageByCLI: [AgentSkin: UsageWindow]
}

final class LogPoller {
    private let growthStore: GrowthStore
    private let fileManager: FileManager
    private let calendar: Calendar
    private let now: () -> Date

    init(
        growthStore: GrowthStore,
        fileManager: FileManager = .default,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.growthStore = growthStore
        self.fileManager = fileManager
        self.calendar = calendar
        self.now = now
    }

    func poll() -> LogPollSnapshot {
        let installedAt = growthStore.loadInstalledAt() ?? .distantPast
        let startOfToday = calendar.startOfDay(for: now())
        let startOfWeek = calendar.date(byAdding: .day, value: -7, to: now()) ?? startOfToday

        var lifetimeTokens = 0
        var usageByCLI: [AgentSkin: UsageWindow] = [:]

        for skin in AgentSkin.allCases {
            lifetimeTokens += lifetimeTotal(for: skin, installedAt: installedAt)
            let today = parseAll(for: skin, since: maxDate(installedAt, startOfToday)).totalTokens
            let week = parseAll(for: skin, since: maxDate(installedAt, startOfWeek)).totalTokens
            usageByCLI[skin] = UsageWindow(todayTokens: today, weekTokens: week)
        }

        return LogPollSnapshot(lifetimeTokens: lifetimeTokens, usageByCLI: usageByCLI)
    }

    private func lifetimeTotal(for skin: AgentSkin, installedAt: Date) -> Int {
        switch skin {
        case .opencode:
            return lifetimeTotalForSingleStore(path: openCodeDBPath(), skin: skin, installedAt: installedAt)
        case .claude, .gemini, .codex:
            return logFilePaths(for: skin).reduce(0) { total, path in
                total + lifetimeTotalForSingleStore(path: path, skin: skin, installedAt: installedAt)
            }
        }
    }

    private func lifetimeTotalForSingleStore(path: String, skin: AgentSkin, installedAt: Date) -> Int {
        let mtime = modificationTime(path: path)
        guard mtime > 0 else {
            return 0
        }

        let previousMtime = growthStore.loadCursor(path: path)
        if previousMtime == mtime {
            return growthStore.loadCursorTokenTotal(path: path)
        }

        let total = parseFile(path: path, for: skin, since: installedAt).totalTokens
        growthStore.saveCursor(path: path, mtime: mtime, totalTokens: total)
        return total
    }

    private func parseAll(for skin: AgentSkin, since date: Date) -> TokenBatch {
        switch skin {
        case .claude:
            return ClaudeLogParser(installedAt: date).parseAll()
        case .gemini:
            return GeminiLogParser(installedAt: date).parseAll()
        case .codex:
            return CodexLogParser(installedAt: date).parseAll()
        case .opencode:
            return OpenCodeLogParser(installedAt: date).parseAll()
        }
    }

    private func parseFile(path: String, for skin: AgentSkin, since date: Date) -> TokenBatch {
        switch skin {
        case .claude:
            return ClaudeLogParser(installedAt: date).parse(filePath: path)
        case .gemini:
            return GeminiLogParser(installedAt: date).parse(filePath: path)
        case .codex:
            return CodexLogParser(installedAt: date).parse(filePath: path)
        case .opencode:
            return OpenCodeLogParser(dbPath: path, installedAt: date).parseAll()
        }
    }

    private func logFilePaths(for skin: AgentSkin) -> [String] {
        let basePath: String
        switch skin {
        case .claude:
            basePath = fileManager.homeDirectoryForCurrentUser.path + "/.claude/projects"
        case .gemini:
            basePath = fileManager.homeDirectoryForCurrentUser.path + "/.gemini/tmp"
        case .codex:
            basePath = ProcessInfo.processInfo.environment["CODEX_HOME"].map { $0 + "/sessions" }
                ?? (fileManager.homeDirectoryForCurrentUser.path + "/.codex/sessions")
        case .opencode:
            return [openCodeDBPath()]
        }

        guard let enumerator = fileManager.enumerator(atPath: basePath) else {
            return []
        }

        return enumerator.compactMap { item -> String? in
            guard let relativePath = item as? String else {
                return nil
            }

            let searchablePath = relativePath.lowercased()
            switch skin {
            case .claude, .codex:
                guard searchablePath.hasSuffix(".jsonl") else { return nil }
            case .gemini:
                guard searchablePath.hasSuffix(".json"), searchablePath.contains("chat") else { return nil }
            case .opencode:
                return nil
            }

            return URL(fileURLWithPath: basePath).appendingPathComponent(relativePath).path
        }
    }

    private func openCodeDBPath() -> String {
        if let dataHome = ProcessInfo.processInfo.environment["XDG_DATA_HOME"], !dataHome.isEmpty {
            return URL(fileURLWithPath: dataHome)
                .appendingPathComponent("opencode")
                .appendingPathComponent("opencode.db")
                .path
        }

        let home = fileManager.homeDirectoryForCurrentUser
        let macOSPath = home
            .appendingPathComponent("Library/Application Support/opencode/opencode.db")
            .path
        if fileManager.fileExists(atPath: macOSPath) {
            return macOSPath
        }

        return home
            .appendingPathComponent(".local/share/opencode/opencode.db")
            .path
    }

    private func modificationTime(path: String) -> Double {
        guard let attributes = try? fileManager.attributesOfItem(atPath: path),
              let date = attributes[.modificationDate] as? Date else {
            return 0
        }
        return date.timeIntervalSince1970
    }

    private func maxDate(_ left: Date, _ right: Date) -> Date {
        left > right ? left : right
    }
}

enum QuotaMonitor {
    static func recommendation(for infos: [CliQuotaInfo]) -> PetState {
        infos.contains { info in
            guard info.isDetected else { return false }
            return info.tiers.contains { $0.utilization >= 1 }
        } ? .sleeping : .idle
    }

}
