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

        let didRun: Bool
        do {
            try task.run()
            didRun = true
        } catch {
            didRun = false
        }
        if didRun {
            task.waitUntilExit()
        }

        let found: String
        if didRun {
            found = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            found = ""
        }

        if didRun, task.terminationStatus == 0, FileManager.default.isExecutableFile(atPath: found) {
            return .available(path: found)
        }

        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return .available(path: path)
        }

        return .unavailable
    }
}
