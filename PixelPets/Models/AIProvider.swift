import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case claude
    case opencode
    case codex
    case gemini
    case unknown
}

extension AIProvider {
    var displayName: String {
        switch self {
        case .claude:  return "Claude"
        case .opencode: return "OpenCode"
        case .codex:   return "Codex"
        case .gemini:  return "Gemini"
        case .unknown: return "Unknown"
        }
    }
}
