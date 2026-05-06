import XCTest
@testable import PixelPets

final class PetStateMachineTests: XCTestCase {
    var m: PetStateMachine!
    override func setUp() { m = PetStateMachine() }

    func test_initial_isIdle()                    { XCTAssertEqual(m.currentState, .idle) }
    func test_lastActiveAgent_nilInitially()      { XCTAssertNil(m.lastActiveAgent) }
    func test_UserPromptSubmit_thinking()         { m.handle("UserPromptSubmit", [:]); XCTAssertEqual(m.currentState, .thinking) }
    func test_PreToolUse_typing()                 { m.handle("PreToolUse", [:]); XCTAssertEqual(m.currentState, .typing) }
    func test_PreToolUse_webSearch_searching()    { m.handle("PreToolUse", ["tool_name":"web_search"]); XCTAssertEqual(m.currentState, .searching) }
    func test_Stop_success()                      { m.handle("Stop", [:]); XCTAssertEqual(m.currentState, .success) }
    func test_PostToolUseFailure_error()          { m.handle("PostToolUseFailure", [:]); XCTAssertEqual(m.currentState, .error) }
    func test_oneSubagent_juggling()              { m.handle("SubagentStart", [:]); XCTAssertEqual(m.currentState, .juggling) }
    func test_twoSubagents_conducting()           { m.handle("SubagentStart", [:]); m.handle("SubagentStart", [:]); XCTAssertEqual(m.currentState, .conducting) }
    func test_PermissionRequest_auth()            { m.handle("PermissionRequest", [:]); XCTAssertEqual(m.currentState, .auth) }
    func test_SessionEnd_resetsSubagentCount()    { m.handle("SubagentStart", [:]); m.handle("SessionEnd", [:]); XCTAssertEqual(m.activeSubagentCount, 0) }
    func test_applyQuotaRecommendation_sleeping() { m.applyQuotaRecommendation(.sleeping); XCTAssertEqual(m.currentState, .sleeping) }
    func test_applyQuotaRecommendation_onlyWhenIdle() {
        m.handle("UserPromptSubmit", [:])   // thinking
        m.applyQuotaRecommendation(.sleeping)
        XCTAssertEqual(m.currentState, .thinking)  // hook wins
    }

    func test_lastActiveAgent_tracksAgentFromPayload() {
        let sm = PetStateMachine()
        sm.handle("UserPromptSubmit", ["agent": "gemini"])
        XCTAssertEqual(sm.lastActiveAgent, .gemini)
        sm.handle("Stop", ["agent": "claude"])
        XCTAssertEqual(sm.lastActiveAgent, .claude)
    }

    func test_quotaMonitorRecommendsSleepingWhenDetectedQuotaIsFull() {
        let infos = [
            CliQuotaInfo(
                id: .claude,
                fetchResult: .success([
                    QuotaTier(id: "five_hour", utilization: 1.0, resetsAt: nil, isEstimated: false)
                ]),
                isDetected: true
            )
        ]

        XCTAssertEqual(QuotaMonitor.recommendation(for: infos), .sleeping)
    }

    func test_quotaMonitorIgnoresUndetectedFullQuota() {
        let infos = [
            CliQuotaInfo(
                id: .claude,
                fetchResult: .success([
                    QuotaTier(id: "five_hour", utilization: 1.0, resetsAt: nil, isEstimated: false)
                ]),
                isDetected: false
            )
        ]

        XCTAssertEqual(QuotaMonitor.recommendation(for: infos), .idle)
    }
}
