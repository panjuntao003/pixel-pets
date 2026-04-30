import Foundation

final class PetStateMachine {
    private(set) var currentState: PetState = .idle
    private(set) var activeSubagentCount: Int = 0
    private(set) var lastActiveAgent: AgentSkin?
    private var lastHookEvent: Date?

    func handle(_ event: String, _ payload: [String: Any]) {
        lastHookEvent = Date()
        if let agent = payload["agent"] as? String, let skin = AgentSkin(rawValue: agent) {
            lastActiveAgent = skin
        }
        switch event {
        case "UserPromptSubmit": transition(.thinking)
        case "PreToolUse":
            let tool = payload["tool_name"] as? String ?? ""
            transition(["web_search","read_file","web_fetch","glob","grep"].contains(tool) ? .searching : .typing)
        case "PostToolUse":  transition(.typing)
        case "PostToolUseFailure", "StopFailure": transition(.error)
        case "Stop":  activeSubagentCount = 0; transition(.success)
        case "SubagentStart":
            activeSubagentCount += 1
            transition(activeSubagentCount >= 2 ? .conducting : .juggling)
        case "SubagentStop":
            activeSubagentCount = max(0, activeSubagentCount - 1)
            if activeSubagentCount == 0 { transition(.typing) }
        case "PermissionRequest": transition(.auth)
        case "SessionEnd": activeSubagentCount = 0; transition(.idle)
        case "PreCompact": transition(.searching)
        default: break
        }
    }

    /// Quota monitor calls this. Only takes effect when machine is in idle/sleeping — hook events win.
    func applyQuotaRecommendation(_ state: PetState) {
        guard currentState == .idle || currentState == .sleeping else { return }
        transition(state)
    }

    func forceEvolve() { transition(.evolving) }

    private func transition(_ state: PetState) { currentState = state }
}
