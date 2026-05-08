import XCTest
@testable import Quota

final class QuotaUsageLevelTests: XCTestCase {
    func test_fromRemainingFraction_thresholds() {
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 1.00), .normal)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 0.40), .normal)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 0.39), .low)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 0.10), .low)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 0.09), .exhausted)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 0.00), .exhausted)
    }

    func test_clampsOutOfRangeInputs() {
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: -0.1), .exhausted)
        XCTAssertEqual(QuotaUsageLevel(remainingFraction: 1.5), .normal)
    }
}
