import Foundation

enum NodeAvailability: Equatable {
    case available(path: String)
    case unavailable
}

final class NodeGate {
    struct WhichResult {
        let exitCode: Int32
        let output: String
    }

    static func detect() -> NodeAvailability {
        let candidates = ["/usr/local/bin/node", "/opt/homebrew/bin/node", "/usr/bin/node"]

        return detect(
            which: runWhichNode,
            isExecutable: FileManager.default.isExecutableFile(atPath:),
            candidates: candidates
        )
    }

    static func detect(
        which: () -> WhichResult,
        isExecutable: (String) -> Bool,
        candidates: [String]
    ) -> NodeAvailability {
        let whichResult = which()
        let found = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if whichResult.exitCode == 0, isExecutable(found) {
            return .available(path: found)
        }

        for path in candidates where isExecutable(path) {
            return .available(path: path)
        }

        return .unavailable
    }

    private static func runWhichNode() -> WhichResult {
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

        let output: String
        if didRun {
            output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } else {
            output = ""
        }

        return WhichResult(exitCode: didRun ? task.terminationStatus : 1, output: output)
    }
}
