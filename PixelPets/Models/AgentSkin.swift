import SwiftUI

enum AgentSkin: String, CaseIterable, Codable {
    case claude, gemini, codex, opencode

    var displayName: String {
        switch self {
        case .claude:   return "Claude Code"
        case .gemini:   return "Gemini CLI"
        case .codex:    return "Codex"
        case .opencode: return "OpenCode"
        }
    }

    var personalityTag: String {
        switch self {
        case .claude:   return "CLAUDE / 热血程序员"
        case .gemini:   return "GEMINI / 赛博法师"
        case .codex:    return "CODEX / 冷酷分析师"
        case .opencode: return "OPENCODE / 暗网黑客"
        }
    }
}
