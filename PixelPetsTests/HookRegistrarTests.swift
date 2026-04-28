import XCTest
@testable import PixelPets

final class HookRegistrarTests: XCTestCase {
    private var tempHome: URL!

    override func setUpWithError() throws {
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("PixelPetsHookRegistrarTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempHome {
            try? FileManager.default.removeItem(at: tempHome)
        }
        tempHome = nil
    }

    func test_detectAllUsesConfiguredHomeAndReportsExistingConfigs() throws {
        try createFile(".claude/settings.json", contents: "{}")
        try createDirectory(".codex")

        let detections = HookRegistrar(home: tempHome.path).detectAll()

        XCTAssertEqual(detections.map(\.cli), [.claude, .gemini, .codex, .opencode])
        XCTAssertEqual(detections.first { $0.cli == .claude }?.configPath, tempHome.appendingPathComponent(".claude/settings.json").path)
        XCTAssertEqual(detections.first { $0.cli == .opencode }?.configPath, tempHome.appendingPathComponent(".config/opencode/opencode.json").path)
        XCTAssertEqual(detections.first { $0.cli == .claude }?.detected, true)
        XCTAssertEqual(detections.first { $0.cli == .gemini }?.detected, false)
        XCTAssertEqual(detections.first { $0.cli == .codex }?.detected, true)
    }

    func test_registerClaudeBacksUpOnceAndAddsExpectedHookEvents() throws {
        try createFile(".claude/settings.json", contents: #"{"hooks":[{"event":"Other","command":"echo keep"}]}"#)
        let registrar = HookRegistrar(home: tempHome.path)
        registrar.setNodePath("/custom/node")

        registrar.register(cli: .claude)
        try createFile(".claude/settings.json.pixelpets.bak", contents: "original backup")
        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [[String: Any]])
        let commands = hooks.compactMap { $0["command"] as? String }

        XCTAssertEqual(hooks.filter { ($0["command"] as? String)?.contains("pixelpets-hook") == true }.count, 11)
        XCTAssertTrue(commands.contains("echo keep"))
        XCTAssertTrue(commands.contains { $0 == #"/custom/node "pixelpets-hook" UserPromptSubmit"# })
        XCTAssertEqual(try readString(".claude/settings.json.pixelpets.bak"), "original backup")
    }

    func test_registerCodexCreatesHooksFileAndUnregisterRemovesPixelPetsCommands() throws {
        try createDirectory(".codex")
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .codex)
        registrar.unregisterAll()

        let json = try readObject(".codex/hooks.json")
        XCTAssertEqual(json["SessionStart"] as? [String], [])
        XCTAssertEqual(json["UserPromptSubmit"] as? [String], [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempHome.appendingPathComponent(".codex/hooks.json.pixelpets.bak").path) == false)
    }

    private func createDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: tempHome.appendingPathComponent(relativePath),
            withIntermediateDirectories: true
        )
    }

    private func createFile(_ relativePath: String, contents: String) throws {
        let url = tempHome.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func readObject(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: tempHome.appendingPathComponent(relativePath))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func readString(_ relativePath: String) throws -> String {
        try String(contentsOf: tempHome.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
