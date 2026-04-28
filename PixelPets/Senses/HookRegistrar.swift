import Foundation

struct HookRegistration {
    let cli: AgentSkin
    let configPath: String
    var detected: Bool
}

final class HookRegistrar {
    private let fm: FileManager
    private let home: String
    private var nodePath: String = "node"

    init(fileManager: FileManager = .default, home: String = FileManager.default.homeDirectoryForCurrentUser.path) {
        self.fm = fileManager
        self.home = home
    }

    func setNodePath(_ path: String) {
        nodePath = path
    }

    func detectAll() -> [HookRegistration] {
        [
            HookRegistration(
                cli: .claude,
                configPath: "\(home)/.claude/settings.json",
                detected: fm.fileExists(atPath: "\(home)/.claude/settings.json")
            ),
            HookRegistration(
                cli: .gemini,
                configPath: "\(home)/.gemini/settings.json",
                detected: fm.fileExists(atPath: "\(home)/.gemini/settings.json")
            ),
            HookRegistration(
                cli: .codex,
                configPath: "\(home)/.codex/hooks.json",
                detected: fm.fileExists(atPath: "\(home)/.codex") || fm.fileExists(atPath: "\(home)/.codex/hooks.json")
            ),
            HookRegistration(
                cli: .opencode,
                configPath: "\(home)/.config/opencode/opencode.json",
                detected: fm.fileExists(atPath: "\(home)/.config/opencode/opencode.json")
            )
        ]
    }

    func register(cli: AgentSkin) {
        switch cli {
        case .claude:
            registerClaude()
        case .gemini:
            registerGemini()
        case .codex:
            registerCodex()
        case .opencode:
            break
        }
    }

    func unregisterAll() {
        unregister(configPath: "\(home)/.claude/settings.json", markers: ["pixelpets", "pixelpets-hook"])
        unregister(configPath: "\(home)/.gemini/settings.json", markers: ["pixelpets", "gemini-hook"])
        unregister(configPath: "\(home)/.codex/hooks.json", markers: ["pixelpets", "codex-hook"])
    }

    private func registerClaude() {
        let path = "\(home)/.claude/settings.json"
        guard var json = readJSON(path) else {
            return
        }

        backup(path)

        let hookScript = bundledPath(name: "pixelpets-hook")
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        let events = [
            "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
            "Stop", "StopFailure", "SubagentStart", "SubagentStop",
            "PermissionRequest", "SessionEnd", "PreCompact"
        ]

        for event in events {
            appendCommandHandler(
                command: command(scriptPath: hookScript, event: event),
                to: &hooks,
                event: event,
                marker: "pixelpets-hook"
            )
        }

        json["hooks"] = hooks
        writeJSON(json, to: path)
    }

    private func registerGemini() {
        let path = "\(home)/.gemini/settings.json"
        guard var json = readJSON(path) else {
            return
        }

        backup(path)

        let hookScript = bundledPath(name: "gemini-hook")
        let command = command(scriptPath: hookScript)
        var hooks = json["hooks"] as? [String: Any] ?? [:]
        let events = [
            "SessionStart", "SessionEnd", "BeforeAgent", "BeforeTool",
            "AfterTool", "AfterAgent", "PreCompress"
        ]

        for event in events {
            appendCommandHandler(command: command, to: &hooks, event: event, marker: "gemini-hook")
        }

        json["hooks"] = hooks
        writeJSON(json, to: path)
    }

    private func registerCodex() {
        let path = "\(home)/.codex/hooks.json"
        backup(path)
        ensureParentDirectoryExists(for: path)

        var json = readJSON(path) ?? [:]
        let hookScript = bundledPath(name: "codex-hook")
        let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Stop"]

        for event in events {
            appendCommandHandler(
                command: command(scriptPath: hookScript, event: event),
                to: &json,
                event: event,
                marker: "codex-hook"
            )
        }

        writeJSON(json, to: path)
    }

    private func unregister(configPath: String, markers: [String]) {
        guard var json = readJSON(configPath) else {
            return
        }

        if var hooks = json["hooks"] as? [String: Any] {
            removeCommandHandlers(containingAnyOf: markers, from: &hooks)
            json["hooks"] = hooks
            writeJSON(json, to: configPath)
            return
        }

        removeCommandHandlers(containingAnyOf: markers, from: &json)
        writeJSON(json, to: configPath)
    }

    private func appendCommandHandler(command: String, to hooks: inout [String: Any], event: String, marker: String) {
        var groups = hooks[event] as? [[String: Any]] ?? []
        guard !containsCommand(in: groups, marker: marker) else {
            return
        }

        let handler: [String: Any] = [
            "type": "command",
            "command": command,
            "timeout": 1000
        ]

        if let index = groups.firstIndex(where: { $0["matcher"] == nil || ($0["matcher"] as? String) == "*" }) {
            var group = groups[index]
            var handlers = group["hooks"] as? [[String: Any]] ?? []
            handlers.append(handler)
            group["hooks"] = handlers
            groups[index] = group
        } else {
            groups.append(["hooks": [handler]])
        }

        hooks[event] = groups
    }

    private func removeCommandHandlers(containingAnyOf markers: [String], from hooks: inout [String: Any]) {
        for key in hooks.keys {
            guard var groups = hooks[key] as? [[String: Any]] else {
                continue
            }

            for index in groups.indices {
                var group = groups[index]
                guard var handlers = group["hooks"] as? [[String: Any]] else {
                    continue
                }

                handlers.removeAll { handler in
                    guard let command = handler["command"] as? String else {
                        return false
                    }
                    return markers.contains { command.localizedCaseInsensitiveContains($0) }
                }
                group["hooks"] = handlers
                groups[index] = group
            }

            hooks[key] = groups
        }
    }

    private func containsCommand(in groups: [[String: Any]], marker: String) -> Bool {
        groups.contains { group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return handlers.contains { (($0["command"] as? String)?.localizedCaseInsensitiveContains(marker) == true) }
        }
    }

    private func command(scriptPath: String, event: String? = nil) -> String {
        var parts = [shellQuote(nodePath), shellQuote(scriptPath)]
        if let event {
            parts.append(event)
        }
        return parts.joined(separator: " ")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private func backup(_ path: String) {
        guard fm.fileExists(atPath: path) else {
            return
        }

        let backupPath = path + ".pixelpets.bak"
        guard !fm.fileExists(atPath: backupPath) else {
            return
        }

        try? fm.copyItem(atPath: path, toPath: backupPath)
    }

    private func bundledPath(name: String) -> String {
        Bundle.main.path(forResource: name, ofType: "js") ?? name
    }

    private func readJSON(_ path: String) -> [String: Any]? {
        guard let data = fm.contents(atPath: path) else {
            return nil
        }

        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private func writeJSON(_ json: [String: Any], to path: String) {
        ensureParentDirectoryExists(for: path)

        guard let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) else {
            return
        }

        try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    private func ensureParentDirectoryExists(for path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }
}
