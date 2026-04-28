import XCTest
@testable import PixelPets

final class NodeGateTests: XCTestCase {
    func test_detectReturnsAvailableForSuccessfulWhichNodeExecutablePath() {
        let result = NodeGate.detect(
            which: { NodeGate.WhichResult(exitCode: 0, output: "/custom/bin/node\n") },
            isExecutable: { $0 == "/custom/bin/node" },
            candidates: []
        )

        XCTAssertEqual(result, .available(path: "/custom/bin/node"))
    }

    func test_detectFallsBackToKnownExecutableCandidateWhenWhichFails() {
        let result = NodeGate.detect(
            which: { NodeGate.WhichResult(exitCode: 1, output: "") },
            isExecutable: { $0 == "/opt/homebrew/bin/node" },
            candidates: ["/usr/local/bin/node", "/opt/homebrew/bin/node"]
        )

        XCTAssertEqual(result, .available(path: "/opt/homebrew/bin/node"))
    }

    func test_detectReturnsUnavailableWhenWhichFailsAndNoCandidatesAreExecutable() {
        let result = NodeGate.detect(
            which: { NodeGate.WhichResult(exitCode: 1, output: "") },
            isExecutable: { _ in false },
            candidates: ["/usr/local/bin/node", "/opt/homebrew/bin/node"]
        )

        XCTAssertEqual(result, .unavailable)
    }
}
