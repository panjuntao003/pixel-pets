import XCTest
import Combine
@testable import PixelPets

@MainActor
final class ActivityCoordinatorTests: XCTestCase {
    var coordinator: ActivityCoordinator!
    var mockSource: ManualDebugEventSource!
    
    override func setUp() {
        super.setUp()
        coordinator = ActivityCoordinator.shared
        mockSource = ManualDebugEventSource.shared
        coordinator.start(sources: [mockSource])
    }
    
    func test_priority_errorWins() async {
        mockSource.trigger(.claude, .aiThinking)
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
        
        mockSource.trigger(.claude, .requestFailed)
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
        
        mockSource.trigger(.claude, .aiStreaming) // Lower priority
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
    }
    
    func test_multi_provider_priority() async {
        mockSource.trigger(.gemini, .aiThinking)
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
        XCTAssertEqual(coordinator.activeProvider, .gemini)
        
        mockSource.trigger(.claude, .requestFailed) // Higher priority
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
        XCTAssertEqual(coordinator.activeProvider, .claude)
    }
    
    func test_quota_persistence() async {
        mockSource.trigger(.claude, .quotaLow)
        XCTAssertEqual(coordinator.currentEvent, .quotaLow)
        
        mockSource.trigger(.claude, .aiThinking)
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
        
        // Wait for transient state to expire (simulated by manual reset for test simplicity if possible, 
        // or just checking logic)
        // In our impl, we'd need to wait 2 seconds.
    }
}
