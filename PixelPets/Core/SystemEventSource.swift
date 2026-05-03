import Foundation
import Combine

protocol SystemEventSource {
    var events: AnyPublisher<(AIProvider, SystemEvent), Never> { get }
}
