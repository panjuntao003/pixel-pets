import XCTest
@testable import PixelPets

final class GrowthEngineTests: XCTestCase {
    let e = GrowthEngine()

    func test_below500k_noAccessories_level1() {
        let (lvl, acc) = e.compute(totalTokens: 100_000)
        XCTAssertEqual(lvl, 1); XCTAssertTrue(acc.isEmpty)
    }

    func test_at500k_sprout() {
        let (_, acc) = e.compute(totalTokens: 500_000)
        XCTAssertTrue(acc.contains(.sprout))
    }

    func test_at1M_level2() {
        XCTAssertEqual(e.compute(totalTokens: 1_000_000).level, 2)
    }

    func test_at5M_level3() {
        XCTAssertEqual(e.compute(totalTokens: 5_000_000).level, 3)
    }

    func test_at20M_level4() {
        XCTAssertEqual(e.compute(totalTokens: 20_000_000).level, 4)
    }

    func test_at2M_battery() {
        XCTAssertTrue(e.compute(totalTokens: 2_000_000).accessories.contains(.battery))
    }

    func test_milestones_400k_to_600k() {
        XCTAssertEqual(e.newMilestones(from: 400_000, to: 600_000), [.sprout])
    }

    func test_milestones_none_within_range() {
        XCTAssertTrue(e.newMilestones(from: 600_000, to: 900_000).isEmpty)
    }

    func test_milestones_multiple_in_one_jump() {
        XCTAssertEqual(e.newMilestones(from: 400_000, to: 3_500_000), [.sprout, .battery, .headset])
    }

    func test_milestones_doesNotReemitOldTotalThreshold() {
        XCTAssertEqual(e.newMilestones(from: 500_000, to: 2_000_000), [.battery])
    }

    func test_at20M_fullAccessoryOrdering() {
        XCTAssertEqual(
            e.compute(totalTokens: 20_000_000).accessories,
            [.sprout, .battery, .headset, .minidrone, .jetpack, .halo, .codecloud, .cape, .antenna]
        )
    }
}
