import XCTest
@testable import Quota

final class ClaudeQuotaClientTests: XCTestCase {
    override func tearDown() {
        ClaudeQuotaClient.copyKeychainCredential = ClaudeQuotaClient.defaultCopyKeychainCredential
        ClaudeQuotaClient.updateKeychainAccess = ClaudeQuotaClient.defaultUpdateKeychainAccess
        super.tearDown()
    }

    func test_readKeychainCredentialDataRemovesAppRestrictionAfterSuccessfulRead() throws {
        let credentialData = Data("{}".utf8)
        var didUpdateAccess = false
        ClaudeQuotaClient.copyKeychainCredential = { _ in
            (credentialData, errSecSuccess)
        }
        ClaudeQuotaClient.updateKeychainAccess = { service in
            didUpdateAccess = service == "Claude Code-credentials"
            return errSecSuccess
        }

        let (data, status) = ClaudeQuotaClient.readKeychainCredentialData()

        XCTAssertEqual(data, credentialData)
        XCTAssertEqual(status, errSecSuccess)
        XCTAssertTrue(didUpdateAccess)
    }

    func test_readKeychainCredentialDataDoesNotUpdateAccessAfterFailedRead() throws {
        var didUpdateAccess = false
        ClaudeQuotaClient.copyKeychainCredential = { _ in
            (nil, errSecAuthFailed)
        }
        ClaudeQuotaClient.updateKeychainAccess = { _ in
            didUpdateAccess = true
            return errSecSuccess
        }

        let (data, status) = ClaudeQuotaClient.readKeychainCredentialData()

        XCTAssertNil(data)
        XCTAssertEqual(status, errSecAuthFailed)
        XCTAssertFalse(didUpdateAccess)
    }

    func test_keychainAccessDeniedDistinguishesMissingItemFromDeniedAccess() throws {
        XCTAssertFalse(ClaudeQuotaClient.keychainAccessDenied(status: errSecSuccess))
        XCTAssertFalse(ClaudeQuotaClient.keychainAccessDenied(status: errSecItemNotFound))
        XCTAssertTrue(ClaudeQuotaClient.keychainAccessDenied(status: errSecAuthFailed))
    }

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

    func test_parseQuotaTiersNormalizesIntegerPercentageUtilization() throws {
        let json = """
        {
          "five_hour": {
            "utilization": 42
          },
          "seven_day": {
            "utilization": 85
          }
        }
        """

        let tiers = ClaudeQuotaClient.parseQuotaTiers(from: Data(json.utf8))

        XCTAssertEqual(tiers.map(\.id), ["five_hour", "seven_day"])
        XCTAssertEqual(tiers[0].utilization, 0.42, accuracy: 0.0001)
        XCTAssertEqual(tiers[1].utilization, 0.85, accuracy: 0.0001)
    }

    func test_codexParseQuotaTiersReadsPrimaryAndSecondaryWindows() throws {
        let json = """
        {
          "rate_limit": {
            "primary_window": {
              "used_percent": 58,
              "reset_at": 1777444795
            },
            "secondary_window": {
              "used_percent": 40,
              "reset_after_seconds": 533999
            }
          }
        }
        """

        let tiers = CodexQuotaClient.parseQuotaTiers(from: Data(json.utf8), now: Date(timeIntervalSince1970: 1_777_431_526))

        XCTAssertEqual(tiers.map(\.id), ["five_hour", "weekly"])
        XCTAssertEqual(tiers[0].utilization, 0.58, accuracy: 0.0001)
        XCTAssertEqual(tiers[0].resetsAt, Date(timeIntervalSince1970: 1_777_444_795))
        XCTAssertFalse(tiers[0].isEstimated)
        XCTAssertEqual(tiers[1].utilization, 0.40, accuracy: 0.0001)
        XCTAssertEqual(tiers[1].resetsAt, Date(timeIntervalSince1970: 1_777_431_526 + 533_999))
    }

    func test_geminiParseQuotaTiersPoolsGemini3BucketsLikeCLIStats() throws {
        let json = """
        {
          "buckets": [
            {
              "modelId": "gemini-2.5-pro",
              "remainingFraction": 0.10,
              "resetTime": "2026-04-29T05:06:04Z"
            },
            {
              "modelId": "gemini-3-pro-preview",
              "remainingFraction": 0.81333333,
              "resetTime": "2026-04-29T05:06:04Z"
            },
            {
              "modelId": "gemini-3-flash-preview",
              "remainingFraction": 0.994,
              "resetTime": "2026-04-30T03:06:13Z"
            }
          ]
        }
        """

        let tiers = GeminiQuotaClient.parseQuotaTiers(from: Data(json.utf8))

        // Pro tier: gemini-2.5-pro (0.10) + gemini-3-pro-preview (0.813) → avg remaining 0.4567 → utilization ~0.543
        // Flash tier: gemini-3-flash-preview (0.994) → utilization ~0.006
        XCTAssertEqual(tiers.map(\.id), ["pro", "flash"])
        XCTAssertEqual(tiers[0].utilization, 1 - (0.10 + 0.81333333) / 2, accuracy: 0.0001)
        XCTAssertEqual(tiers[0].resetsAt, ISO8601DateFormatter().date(from: "2026-04-29T05:06:04Z"))
        XCTAssertFalse(tiers[0].isEstimated)
        XCTAssertEqual(tiers[1].utilization, 1 - 0.994, accuracy: 0.0001)
        XCTAssertEqual(tiers[1].resetsAt, ISO8601DateFormatter().date(from: "2026-04-30T03:06:13Z"))
        XCTAssertFalse(tiers[1].isEstimated)
    }

    func test_geminiParseProjectReadsStringOrObjectProject() throws {
        let stringProject = Data(#"{ "cloudaicompanionProject": "project-a" }"#.utf8)
        let objectProject = Data(#"{ "cloudaicompanionProject": { "id": "project-b" } }"#.utf8)

        XCTAssertEqual(GeminiQuotaClient.parseProject(from: stringProject), "project-a")
        XCTAssertEqual(GeminiQuotaClient.parseProject(from: objectProject), "project-b")
    }
}
