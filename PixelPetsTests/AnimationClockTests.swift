import XCTest
import SwiftUI
@testable import PixelPets

final class AnimationClockTests: XCTestCase {
    func test_frameIndexAdvancesFromElapsedTimeAndFPS() {
        let start = Date(timeIntervalSince1970: 100)
        let now = start.addingTimeInterval(1.25)

        XCTAssertEqual(AnimationClock<EmptyView>.frameIndex(since: start, at: now, fps: 8), 10)
    }

    func test_frameIndexNeverGoesNegative() {
        let start = Date(timeIntervalSince1970: 100)
        let now = start.addingTimeInterval(-1)

        XCTAssertEqual(AnimationClock<EmptyView>.frameIndex(since: start, at: now, fps: 30), 0)
    }
}
