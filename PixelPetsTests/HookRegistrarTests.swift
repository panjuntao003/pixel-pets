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

        XCTAssertEqual(detections.map(\.cli), [.claude, .gemini, .codex])
        XCTAssertEqual(detections.first { $0.cli == .claude }?.configPath, tempHome.appendingPathComponent(".claude/settings.json").path)
        XCTAssertEqual(detections.first { $0.cli == .claude }?.detected, true)
        XCTAssertEqual(detections.first { $0.cli == .gemini }?.detected, false)
        XCTAssertEqual(detections.first { $0.cli == .codex }?.detected, true)
    }

    func test_registerClaudePreservesNestedHooksAddsAllEventsIdempotentlyAndBacksUpOnce() throws {
        try createFile(
            ".claude/settings.json",
            contents: """
            {
              "theme": "dark",
              "hooks": {
                "UserPromptSubmit": [
                  {
                    "matcher": "existing",
                    "hooks": [
                      { "type": "command", "command": "echo keep", "timeout": 42 }
                    ]
                  }
                ]
              }
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)
        registrar.setNodePath("/Applications/Node Tools/node")

        registrar.register(cli: .claude)
        let firstBackup = try readString(".claude/settings.json.pixelpets.bak")
        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let userPromptGroups = try eventGroups("UserPromptSubmit", in: hooks)
        let userPromptCommands = commandHandlers(in: userPromptGroups).compactMap { $0["command"] as? String }

        XCTAssertEqual(json["theme"] as? String, "dark")
        XCTAssertTrue(userPromptCommands.contains("echo keep"))
        XCTAssertEqual(userPromptCommands.filter { $0.contains("pixelpets-hook") }.count, 1)
        XCTAssertTrue(userPromptCommands.contains {
            $0.contains("'/Applications/Node Tools/node'") &&
            $0.contains("pixelpets-hook") &&
            $0.hasSuffix(" UserPromptSubmit")
        })

        for event in claudeEvents {
            XCTAssertEqual(try pixelPetsCommandCount(event: event, in: hooks), 1, event)
        }
        XCTAssertEqual(firstBackup, try readString(".claude/settings.json.pixelpets.bak"))
    }

    func test_registerGeminiPreservesNestedHooksAndIsIdempotent() throws {
        try createFile(
            ".gemini/settings.json",
            contents: """
            {
              "other": true,
              "hooks": {
                "BeforeTool": [
                  {
                    "hooks": [
                      { "type": "command", "command": "echo gemini keep" }
                    ]
                  }
                ]
              }
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .gemini)
        registrar.register(cli: .gemini)

        let json = try readObject(".gemini/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let beforeToolCommands = commandHandlers(in: try eventGroups("BeforeTool", in: hooks))
            .compactMap { $0["command"] as? String }

        XCTAssertEqual(json["other"] as? Bool, true)
        XCTAssertTrue(beforeToolCommands.contains("echo gemini keep"))
        XCTAssertEqual(beforeToolCommands.filter { $0.contains("gemini-hook") }.count, 1)
    }

    func test_registerClaudeMigratesLegacyFlatHooksArrayAndRemovesOldPixelPetsEntries() throws {
        try createFile(
            ".claude/settings.json",
            contents: """
            {
              "hooks": [
                { "event": "PreToolUse", "command": "echo keep pretool", "timeout": 8, "custom": "survives", "flag": true },
                { "event": "Stop", "command": "node pixelpets-hook Stop" },
                { "command": "echo keep unknown" },
                { "event": "Stop", "command": "echo pixelpets status" }
              ]
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let preToolHandlers = commandHandlers(in: try eventGroups("PreToolUse", in: hooks))
        let preToolCommands = preToolHandlers.compactMap { $0["command"] as? String }

        XCTAssertTrue(preToolCommands.contains("echo keep pretool"))
        let preserved = preToolHandlers.first { $0["command"] as? String == "echo keep pretool" }
        XCTAssertEqual(preserved?["timeout"] as? Int, 8)
        XCTAssertEqual(preserved?["custom"] as? String, "survives")
        XCTAssertEqual(preserved?["flag"] as? Bool, true)
        XCTAssertEqual(preserved?["type"] as? String, "command")
        XCTAssertEqual(try pixelPetsCommandCount(event: "Stop", in: hooks), 1)
        XCTAssertFalse(allCommands(in: hooks).contains("node pixelpets-hook Stop"))
        XCTAssertTrue(commandHandlers(in: try eventGroups("Stop", in: hooks)).contains { $0["command"] as? String == "echo pixelpets status" })
        XCTAssertTrue(commandHandlers(in: try eventGroups("UserPromptSubmit", in: hooks)).contains { $0["command"] as? String == "echo keep unknown" })
    }

    func test_registerGeminiMigratesLegacyFlatHooksArray() throws {
        try createFile(
            ".gemini/settings.json",
            contents: """
            {
              "hooks": [
                { "event": "BeforeTool", "command": "echo keep before tool" },
                { "event": "AfterAgent", "command": "node gemini-hook" }
              ]
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .gemini)

        let json = try readObject(".gemini/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let beforeToolCommands = commandHandlers(in: try eventGroups("BeforeTool", in: hooks)).compactMap { $0["command"] as? String }
        let afterAgentCommands = commandHandlers(in: try eventGroups("AfterAgent", in: hooks)).compactMap { $0["command"] as? String }

        XCTAssertTrue(beforeToolCommands.contains("echo keep before tool"))
        XCTAssertEqual(afterAgentCommands.filter { $0.contains("gemini-hook") }.count, 1)
        XCTAssertFalse(afterAgentCommands.contains("node gemini-hook"))
    }

    func test_registerCodexWritesNestedDefinitionsAndUnregisterRemovesOnlyPixelPetsHandlers() throws {
        try createFile(
            ".codex/hooks.json",
            contents: """
            {
              "SessionStart": [
                {
                  "matcher": "startup",
                  "hooks": [
                    { "type": "command", "command": "echo codex keep" }
                  ]
                }
              ]
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .codex)

        var json = try readObject(".codex/hooks.json")
        var sessionCommands = commandHandlers(in: try eventGroups("SessionStart", in: json)).compactMap { $0["command"] as? String }
        XCTAssertTrue(sessionCommands.contains("echo codex keep"))
        XCTAssertEqual(sessionCommands.filter { $0.contains("codex-hook") }.count, 1)
        XCTAssertNotNil(commandHandlers(in: try eventGroups("PreToolUse", in: json)).first { $0["type"] as? String == "command" })

        registrar.unregisterAll()

        json = try readObject(".codex/hooks.json")
        sessionCommands = commandHandlers(in: try eventGroups("SessionStart", in: json)).compactMap { $0["command"] as? String }
        XCTAssertEqual(sessionCommands, ["echo codex keep"])
        XCTAssertEqual(commandHandlers(in: try eventGroups("PreToolUse", in: json)).count, 0)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempHome.appendingPathComponent(".codex/hooks.json.pixelpets.bak").path))
    }

    func test_registerCodexMigratesStringEventArraysAndIsIdempotent() throws {
        try createFile(
            ".codex/hooks.json",
            contents: """
            {
              "SessionStart": [
                "echo keep codex",
                "node codex-hook SessionStart"
              ],
              "UnsupportedEvent": { "doNotTouch": true }
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .codex)
        registrar.register(cli: .codex)

        let json = try readObject(".codex/hooks.json")
        let sessionCommands = commandHandlers(in: try eventGroups("SessionStart", in: json)).compactMap { $0["command"] as? String }

        XCTAssertTrue(sessionCommands.contains("echo keep codex"))
        XCTAssertEqual(sessionCommands.filter { $0.contains("codex-hook") }.count, 1)
        XCTAssertFalse(sessionCommands.contains("node codex-hook SessionStart"))
        XCTAssertNotNil(json["UnsupportedEvent"] as? [String: Any])
    }

    func test_registerClaudeLeavesUnsupportedHooksShapeUntouched() throws {
        try createFile(
            ".claude/settings.json",
            contents: """
            {
              "hooks": "custom opaque config",
              "other": "keep"
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        XCTAssertEqual(json["hooks"] as? String, "custom opaque config")
        XCTAssertEqual(json["other"] as? String, "keep")
    }

    func test_unregisterAllRemovesNestedPixelPetsHandlersAndPreservesUnrelatedCommands() throws {
        try createFile(
            ".codex/hooks.json",
            contents: """
            {
              "SessionStart": [
                {
                  "matcher": "*",
                  "hooks": [
                    { "type": "command", "command": "echo keep" },
                    { "type": "command", "command": "node pixelpets-hook SessionStart" }
                  ]
                }
              ]
            }
            """
        )
        try createFile(
            ".claude/settings.json",
            contents: """
            {
              "hooks": {
                "Stop": [
                  {
                    "hooks": [
                      { "type": "command", "command": "echo keep claude" },
                      { "type": "command", "command": "node pixelpets-hook Stop" }
                    ]
                  }
                ]
              }
            }
            """
        )
        try createFile(
            ".gemini/settings.json",
            contents: """
            {
              "hooks": {
                "BeforeTool": [
                  {
                    "hooks": [
                      { "type": "command", "command": "echo keep gemini" },
                      { "type": "command", "command": "node gemini-hook" }
                    ]
                  }
                ]
              }
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.unregisterAll()

        let codex = try readObject(".codex/hooks.json")
        let codexCommands = commandHandlers(in: try eventGroups("SessionStart", in: codex)).compactMap { $0["command"] as? String }
        XCTAssertEqual(codexCommands, ["echo keep"])

        let claude = try readObject(".claude/settings.json")
        let claudeHooks = try XCTUnwrap(claude["hooks"] as? [String: Any])
        let claudeCommands = commandHandlers(in: try eventGroups("Stop", in: claudeHooks)).compactMap { $0["command"] as? String }
        XCTAssertEqual(claudeCommands, ["echo keep claude"])

        let gemini = try readObject(".gemini/settings.json")
        let geminiHooks = try XCTUnwrap(gemini["hooks"] as? [String: Any])
        let geminiCommands = commandHandlers(in: try eventGroups("BeforeTool", in: geminiHooks)).compactMap { $0["command"] as? String }
        XCTAssertEqual(geminiCommands, ["echo keep gemini"])
    }

    func test_unregisterAllRemovesLegacyFlatPixelPetsEntriesAndPreservesUnrelatedCommands() throws {
        try createFile(
            ".claude/settings.json",
            contents: """
            {
              "hooks": [
                { "event": "Stop", "command": "echo keep flat claude" },
                { "event": "Stop", "command": "echo pixelpets status" },
                { "event": "Stop", "command": "node pixelpets-hook Stop" }
              ]
            }
            """
        )
        try createFile(
            ".gemini/settings.json",
            contents: """
            {
              "hooks": [
                { "event": "BeforeTool", "command": "echo keep flat gemini" },
                { "event": "BeforeTool", "command": "node gemini-hook" }
              ]
            }
            """
        )
        try createFile(
            ".codex/hooks.json",
            contents: """
            {
              "SessionStart": [
                "echo keep flat codex",
                "node codex-hook SessionStart"
              ]
            }
            """
        )
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.unregisterAll()

        let claudeHooks = try XCTUnwrap(readObject(".claude/settings.json")["hooks"] as? [[String: Any]])
        XCTAssertEqual(claudeHooks.compactMap { $0["command"] as? String }, ["echo keep flat claude", "echo pixelpets status"])

        let geminiHooks = try XCTUnwrap(readObject(".gemini/settings.json")["hooks"] as? [[String: Any]])
        XCTAssertEqual(geminiHooks.compactMap { $0["command"] as? String }, ["echo keep flat gemini"])

        let codexCommands = try XCTUnwrap(readObject(".codex/hooks.json")["SessionStart"] as? [String])
        XCTAssertEqual(codexCommands, ["echo keep flat codex"])
    }

    func test_nodePathWithSingleQuoteIsShellQuotedSafely() throws {
        try createFile(".claude/settings.json", contents: #"{"hooks":{}}"#)
        let registrar = HookRegistrar(home: tempHome.path)
        registrar.setNodePath("/Users/dev's tools/node")

        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let commands = commandHandlers(in: try eventGroups("UserPromptSubmit", in: hooks)).compactMap { $0["command"] as? String }
        XCTAssertTrue(commands.contains {
            $0.contains("'/Users/dev'\\''s tools/node'") &&
            $0.contains("pixelpets-hook") &&
            $0.hasSuffix(" UserPromptSubmit")
        })
    }

    func test_registeredHandlerTimeoutIsLongerThanScriptRequestTimeout() throws {
        try createFile(".claude/settings.json", contents: #"{"hooks":{}}"#)
        let registrar = HookRegistrar(home: tempHome.path)

        registrar.register(cli: .claude)

        let json = try readObject(".claude/settings.json")
        let hooks = try XCTUnwrap(json["hooks"] as? [String: Any])
        let handler = try XCTUnwrap(commandHandlers(in: try eventGroups("UserPromptSubmit", in: hooks)).first {
            ($0["command"] as? String)?.contains("pixelpets-hook") == true
        })
        XCTAssertEqual(handler["timeout"] as? Int, 3000)
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

    private var claudeEvents: [String] {
        [
            "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
            "Stop", "StopFailure", "SubagentStart", "SubagentStop",
            "PermissionRequest", "SessionEnd", "PreCompact"
        ]
    }

    private func eventGroups(_ event: String, in hooks: [String: Any]) throws -> [[String: Any]] {
        try XCTUnwrap(hooks[event] as? [[String: Any]], event)
    }

    private func commandHandlers(in groups: [[String: Any]]) -> [[String: Any]] {
        groups.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
    }

    private func pixelPetsCommandCount(event: String, in hooks: [String: Any]) throws -> Int {
        commandHandlers(in: try eventGroups(event, in: hooks))
            .filter { handler in
                guard let command = handler["command"] as? String else {
                    return false
                }
                return ["pixelpets-hook", "gemini-hook", "codex-hook"].contains {
                    command.contains($0)
                }
            }
            .count
    }

    private func allCommands(in hooks: [String: Any]) -> [String] {
        hooks.values
            .compactMap { $0 as? [[String: Any]] }
            .flatMap(commandHandlers)
            .compactMap { $0["command"] as? String }
    }
}
