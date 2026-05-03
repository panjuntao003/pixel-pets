import Foundation
import Combine

final class ManualDebugEventSource: SystemEventSource {
    static let shared = ManualDebugEventSource()
    
    private let eventSubject = PassthroughSubject<(AIProvider, SystemEvent), Never>()
    var events: AnyPublisher<(AIProvider, SystemEvent), Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    func trigger(_ provider: AIProvider, _ event: SystemEvent) {
        eventSubject.send((provider, event))
    }
}
