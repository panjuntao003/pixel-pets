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
        unregister(configPath: "\(home)/.claude/settings.json", marker: "pixelpets")
        unregister(configPath: "\(home)/.gemini/settings.json", marker: "pixelpets")
        unregister(configPath: "\(home)/.codex/hooks.json", marker: "pixelpets")
    }

    private func registerClaude() {
        let path = "\(home)/.claude/settings.json"
        guard var json = readJSON(path) else {
            return
        }

        backup(path)

        let hookScript = bundledPath(name: "pixelpets-hook")
        var hooks = json["hooks"] as? [[String: Any]] ?? []
        let events = [
            "UserPromptSubmit", "PreToolUse", "PostToolUse", "PostToolUseFailure",
            "Stop", "StopFailure", "SubagentStart", "SubagentStop",
            "PermissionRequest", "SessionEnd", "PreCompact"
        ]

        for event in events where !containsPixelPetsCommand(in: hooks, event: event) {
            hooks.append([
                "event": event,
                "command": "\(nodePath) \"\(hookScript)\" \(event)"
            ])
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
        let command = "\(nodePath) \"\(hookScript)\""
        var hooks = json["hooks"] as? [[String: Any]] ?? []

        if !hooks.contains(where: { ($0["command"] as? String)?.contains("pixelpets") == true }) {
            hooks.append(["command": command])
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
            var list = json[event] as? [String] ?? []
            let command = "\(nodePath) \"\(hookScript)\" \(event)"
            if !list.contains(command) {
                list.append(command)
            }
            json[event] = list
        }

        writeJSON(json, to: path)
    }

    private func unregister(configPath: String, marker: String) {
        guard var json = readJSON(configPath) else {
            return
        }

        if var hooks = json["hooks"] as? [[String: Any]] {
            hooks.removeAll { ($0["command"] as? String)?.contains(marker) == true }
            json["hooks"] = hooks
            writeJSON(json, to: configPath)
            return
        }

        var changed = false
        for key in json.keys {
            guard var commands = json[key] as? [String] else {
                continue
            }

            let originalCount = commands.count
            commands.removeAll { $0.contains(marker) }
            json[key] = commands
            changed = changed || originalCount != commands.count
        }

        if changed {
            writeJSON(json, to: configPath)
        }
    }

    private func containsPixelPetsCommand(in hooks: [[String: Any]], event: String) -> Bool {
        hooks.contains {
            ($0["event"] as? String) == event
                && (($0["command"] as? String)?.contains("pixelpets") == true)
        }
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

        fm.createFile(atPath: path, contents: data)
    }

    private func ensureParentDirectoryExists(for path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
    }
}
