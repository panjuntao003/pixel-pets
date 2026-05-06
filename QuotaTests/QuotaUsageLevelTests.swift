import XCTest
@testable import Quota

final class QuotaUsageLevelTests: XCTestCase {
    func test_fromUsedFraction_matchesRemainingQuotaThresholds() {
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.59), .normal)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.60), .low)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.89), .low)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.90), .exhausted)
    }
}
