import Foundation
import Combine

final class OpenCodeLogEventSource: SystemEventSource {
    private let eventSubject = PassthroughSubject<(AIProvider, SystemEvent), Never>()
    var events: AnyPublisher<(AIProvider, SystemEvent), Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    func push(_ event: SystemEvent) {
        eventSubject.send((.opencode, event))
    }
}
