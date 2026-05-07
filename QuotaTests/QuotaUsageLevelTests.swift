import XCTest
@testable import Quota

final class QuotaUsageLevelTests: XCTestCase {
    func test_fromUsedFraction_usesLowQuotaThreshold() {
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.70, lowQuotaThreshold: 20), .normal)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.80, lowQuotaThreshold: 20), .low)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 0.70, lowQuotaThreshold: 30), .low)
        XCTAssertEqual(QuotaUsageLevel(usedFraction: 1.0, lowQuotaThreshold: 20), .exhausted)
    }
}
