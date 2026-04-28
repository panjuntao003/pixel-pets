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
        guard var hooks = normalizedHookObject(from: json["hooks"], defaultEvent: "UserPromptSubmit", markers: ["pixelpets", "pixelpets-hook"]) else {
            return
        }
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
        guard var hooks = normalizedHookObject(from: json["hooks"], defaultEvent: "BeforeTool", markers: ["pixelpets", "gemini-hook"]) else {
            return
        }
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
            _ = appendCommandHandler(
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

        if var hooks = json["hooks"] as? [[String: Any]] {
            removeFlatCommandEntries(containingAnyOf: markers, from: &hooks)
            json["hooks"] = hooks
            writeJSON(json, to: configPath)
            return
        }

        removeCommandHandlers(containingAnyOf: markers, from: &json)
        writeJSON(json, to: configPath)
    }

    @discardableResult
    private func appendCommandHandler(command: String, to hooks: inout [String: Any], event: String, marker: String) -> Bool {
        guard var groups = normalizedEventGroups(from: hooks[event], markers: ["pixelpets", marker]) else {
            return false
        }

        guard !containsCommand(in: groups, marker: marker) else {
            hooks[event] = groups
            return true
        }

        let handler: [String: Any] = [
            "type": "command",
            "command": command,
            "timeout": 3000
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
        return true
    }

    private func removeCommandHandlers(containingAnyOf markers: [String], from hooks: inout [String: Any]) {
        for key in hooks.keys {
            if var groups = hooks[key] as? [[String: Any]] {
                for index in groups.indices {
                    var group = groups[index]
                    guard var handlers = group["hooks"] as? [[String: Any]] else {
                        continue
                    }

                    removeCommandHandlers(containingAnyOf: markers, from: &handlers)
                    group["hooks"] = handlers
                    groups[index] = group
                }

                hooks[key] = groups
            } else if var commands = hooks[key] as? [String] {
                commands.removeAll { command in
                    markers.contains { command.localizedCaseInsensitiveContains($0) }
                }
                hooks[key] = commands
            }
        }
    }

    private func removeCommandHandlers(containingAnyOf markers: [String], from handlers: inout [[String: Any]]) {
        handlers.removeAll { handler in
            guard let command = handler["command"] as? String else {
                return false
            }
            return markers.contains { command.localizedCaseInsensitiveContains($0) }
        }
    }

    private func removeFlatCommandEntries(containingAnyOf markers: [String], from entries: inout [[String: Any]]) {
        entries.removeAll { entry in
            guard let command = entry["command"] as? String else {
                return false
            }
            return markers.contains { command.localizedCaseInsensitiveContains($0) }
        }
    }

    private func containsCommand(in groups: [[String: Any]], marker: String) -> Bool {
        groups.contains { group in
            let handlers = group["hooks"] as? [[String: Any]] ?? []
            return handlers.contains { (($0["command"] as? String)?.localizedCaseInsensitiveContains(marker) == true) }
        }
    }

    private func normalizedHookObject(from value: Any?, defaultEvent: String, markers: [String]) -> [String: Any]? {
        if value == nil {
            return [:]
        }

        if let hooks = value as? [String: Any] {
            return hooks
        }

        if let flatEntries = value as? [[String: Any]] {
            return migrateFlatEntries(flatEntries, defaultEvent: defaultEvent, markers: markers)
        }

        return nil
    }

    private func normalizedEventGroups(from value: Any?, markers: [String]) -> [[String: Any]]? {
        if value == nil {
            return []
        }

        if let groups = value as? [[String: Any]] {
            return groups
        }

        if let commands = value as? [String] {
            let handlers = commands
                .filter { command in
                    !markers.contains { command.localizedCaseInsensitiveContains($0) }
                }
                .map { command in
                    ["type": "command", "command": command]
                }
            return handlers.isEmpty ? [] : [["hooks": handlers]]
        }

        return nil
    }

    private func migrateFlatEntries(_ entries: [[String: Any]], defaultEvent: String, markers: [String]) -> [String: Any] {
        var hooks: [String: Any] = [:]

        for entry in entries {
            guard let command = entry["command"] as? String,
                  !markers.contains(where: { command.localizedCaseInsensitiveContains($0) }) else {
                continue
            }

            let event = entry["event"] as? String ?? defaultEvent
            var handler: [String: Any] = [
                "type": entry["type"] as? String ?? "command",
                "command": command
            ]
            if let timeout = entry["timeout"] {
                handler["timeout"] = timeout
            }

            var group: [String: Any] = ["hooks": [handler]]
            if let matcher = entry["matcher"] {
                group["matcher"] = matcher
            }

            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.append(group)
            hooks[event] = groups
        }

        return hooks
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
