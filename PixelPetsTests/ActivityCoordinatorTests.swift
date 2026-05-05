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
        coordinator.reset()
        mockSource = ManualDebugEventSource.shared
        coordinator.start(sources: [mockSource])
    }
    
    func test_priority_errorWins() async {
        mockSource.trigger(.claude, .aiThinking)
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
        
        mockSource.trigger(.claude, .requestFailed)
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
        
        mockSource.trigger(.claude, .aiStreaming) // Lower priority
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
    }
    
    func test_multi_provider_priority() async {
        mockSource.trigger(.gemini, .aiThinking)
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
        XCTAssertEqual(coordinator.activeProvider, .gemini)
        
        mockSource.trigger(.claude, .requestFailed) // Higher priority
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .requestFailed)
        XCTAssertEqual(coordinator.activeProvider, .claude)
    }
    
    func test_quota_persistence() async {
        mockSource.trigger(.claude, .quotaLow)
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .quotaLow)
        
        mockSource.trigger(.claude, .aiThinking)
        await yield()
        XCTAssertEqual(coordinator.currentEvent, .aiThinking)
    }

    private func yield() async {
        // Allow DispatchQueue.main to process events
        await Task.yield()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
    }
}
