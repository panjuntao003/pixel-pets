import Foundation
import Combine

final class ClaudeLogEventSource: SystemEventSource {
    private let eventSubject = PassthroughSubject<(AIProvider, SystemEvent), Never>()
    var events: AnyPublisher<(AIProvider, SystemEvent), Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    func push(_ event: SystemEvent) {
        eventSubject.send((.claude, event))
    }
    
    func handleHook(event: String, payload: [String: Any]) {
        switch event {
        case "UserPromptSubmit": push(.userStartedRequest)
        case "PreToolUse":       push(.aiThinking)
        case "PostToolUse":      push(.aiStreaming)
        case "PostToolUseFailure", "StopFailure": push(.requestFailed)
        case "Stop":             push(.requestSucceeded)
        default: break
        }
    }
}
