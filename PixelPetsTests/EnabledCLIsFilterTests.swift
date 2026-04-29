import XCTest
@testable import PixelPets

@MainActor
final class EnabledCLIsFilterTests: XCTestCase {
    private func makeInfo(_ skin: AgentSkin, detected: Bool = true) -> CliQuotaInfo {
        CliQuotaInfo(id: skin, isDetected: detected)
    }

    private func visibleClis(
        settings: AppSettings,
        infos: [CliQuotaInfo]
    ) -> [CliQuotaInfo] {
        let viewModel = PetViewModel()
        viewModel.cliInfos = infos
        viewModel.enabledCLIFilter = { settings.isEnabled($0.id) }
        return viewModel.visibleClis
    }

    func test_emptyEnabledCLIs_showsAllDetected() {
        let settings = AppSettings()
        let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
        let visible = visibleClis(settings: settings, infos: all)
        XCTAssertEqual(visible.count, AgentSkin.allCases.count)
    }

    func test_explicitFalse_hidesOneCLI() {
        var settings = AppSettings()
        settings.enabledCLIs[AgentSkin.codex.rawValue] = false
        let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
        let visible = visibleClis(settings: settings, infos: all)
        XCTAssertEqual(visible.count, AgentSkin.allCases.count - 1)
        XCTAssertFalse(visible.contains(where: { $0.id == .codex }))
    }

    func test_allDisabled_returnsEmpty() {
        var settings = AppSettings()
        for skin in AgentSkin.allCases { settings.enabledCLIs[skin.rawValue] = false }
        let all: [CliQuotaInfo] = AgentSkin.allCases.map { makeInfo($0) }
        let visible = visibleClis(settings: settings, infos: all)
        XCTAssertTrue(visible.isEmpty)
    }

    func test_notDetected_hiddenRegardlessOfSettings() {
        let settings = AppSettings()
        let undetected = makeInfo(.claude, detected: false)
        let visible = visibleClis(settings: settings, infos: [undetected])
        XCTAssertTrue(visible.isEmpty)
    }

    func test_visibleClis_appliesEnabledFilter() {
        let viewModel = PetViewModel()
        viewModel.cliInfos = [
            makeInfo(.claude),
            makeInfo(.codex)
        ]
        viewModel.enabledCLIFilter = { $0.id != .codex }

        XCTAssertEqual(viewModel.visibleClis.map(\.id), [.claude])
    }
}
