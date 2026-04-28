import Foundation

enum NodeAvailability {
    case available(path: String)
    case unavailable
}

final class NodeGate {
    static func detect() -> NodeAvailability {
        let candidates = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]

        let task = Process()
        task.launchPath = "/bin/zsh"
        task.arguments = ["-c", "which node"]

        let pipe = Pipe()
        task.standardOutput = pipe

        try? task.run()
        task.waitUntilExit()

        let found = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !found.isEmpty {
            return .available(path: found)
        }

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return .available(path: path)
        }

        return .unavailable
    }
}
