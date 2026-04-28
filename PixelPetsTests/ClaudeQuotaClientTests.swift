import XCTest
@testable import PixelPets

final class ClaudeQuotaClientTests: XCTestCase {
    func test_extractAccessTokenReadsClaudeAiOauthCredential() throws {
        let json = """
        {
          "claudeAiOauth": {
            "accessToken": "token-a"
          }
        }
        """

        let token = ClaudeQuotaClient.extractAccessToken(from: Data(json.utf8))

        XCTAssertEqual(token, "token-a")
    }

    func test_extractAccessTokenReadsClaudeDotAiOauthCredential() throws {
        let json = """
        {
          "claude.ai_oauth": {
            "accessToken": "token-b"
          }
        }
        """

        let token = ClaudeQuotaClient.extractAccessToken(from: Data(json.utf8))

        XCTAssertEqual(token, "token-b")
    }

    func test_parseQuotaTiersReadsKnownWindowsAndDates() throws {
        let json = """
        {
          "five_hour": {
            "utilization": 0.42,
            "resets_at": "2026-04-28T10:30:00Z"
          },
          "seven_day_opus": {
            "utilization": 0.75
          },
          "ignored": {
            "utilization": 0.99
          }
        }
        """

        let tiers = ClaudeQuotaClient.parseQuotaTiers(from: Data(json.utf8))

        XCTAssertEqual(tiers.map(\.id), ["five_hour", "seven_day_opus"])
        XCTAssertEqual(tiers[0].utilization, 0.42, accuracy: 0.0001)
        XCTAssertEqual(tiers[0].resetsAt, ISO8601DateFormatter().date(from: "2026-04-28T10:30:00Z"))
        XCTAssertFalse(tiers[0].isEstimated)
        XCTAssertEqual(tiers[1].utilization, 0.75, accuracy: 0.0001)
        XCTAssertNil(tiers[1].resetsAt)
    }
}
