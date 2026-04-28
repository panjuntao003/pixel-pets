import Foundation
import XCTest
@testable import PixelPets

final class HookServerTests: XCTestCase {
    func test_completeBodyReturnsNilForIncompleteHeaders() {
        let request = Data("POST /hook HTTP/1.1\r\nContent-Length: 5\r\n".utf8)

        XCTAssertNil(HookServer.completeBody(in: request))
    }

    func test_completeBodyReturnsNilForIncompleteBody() {
        let request = Data("POST /hook HTTP/1.1\r\nContent-Length: 5\r\n\r\nhe".utf8)

        XCTAssertNil(HookServer.completeBody(in: request))
    }

    func test_completeBodyReturnsBodyAfterSplitRequestCompletes() {
        var request = Data("POST /hook HTTP/1.1\r\nContent-Length: 5\r\n\r\nhe".utf8)
        request.append(Data("llo".utf8))

        XCTAssertEqual(HookServer.completeBody(in: request), Data("hello".utf8))
    }

    func test_completeBodyTreatsMissingContentLengthAsEmptyBody() {
        let request = Data("POST /hook HTTP/1.1\r\nHost: localhost\r\n\r\nignored".utf8)

        XCTAssertEqual(HookServer.completeBody(in: request), Data())
    }

    func test_completeBodyTreatsMalformedContentLengthAsEmptyBody() {
        let request = Data("POST /hook HTTP/1.1\r\nContent-Length: nope\r\n\r\nignored".utf8)

        XCTAssertEqual(HookServer.completeBody(in: request), Data())
    }
}
