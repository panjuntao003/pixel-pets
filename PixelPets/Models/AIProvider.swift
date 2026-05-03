import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case claude
    case opencode
    case codex
    case gemini
    case unknown
}
