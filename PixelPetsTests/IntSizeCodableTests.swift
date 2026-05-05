import XCTest
@testable import PixelPets

final class IntSizeCodableTests: XCTestCase {

    // MARK: - Decode

    func test_decodes_widthHeight_format() throws {
        let json = Data(#"{"width":360,"height":140}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: json)
        XCTAssertEqual(size.w, 360)
        XCTAssertEqual(size.h, 140)
    }

    func test_decodes_legacy_wh_format() throws {
        let json = Data(#"{"w":360,"h":140}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: json)
        XCTAssertEqual(size.w, 360)
        XCTAssertEqual(size.h, 140)
    }

    func test_decodes_zero_dimensions() throws {
        let json = Data(#"{"width":0,"height":0}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: json)
        XCTAssertEqual(size.w, 0)
        XCTAssertEqual(size.h, 0)
    }

    func test_decode_throws_on_missing_keys() {
        let json = Data(#"{"x":10,"y":20}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(IntSize.self, from: json))
    }

    func test_decode_throws_on_partial_widthHeight() {
        // width present but height missing → should throw, not silently return garbage
        let json = Data(#"{"width":360}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(IntSize.self, from: json))
    }

    // MARK: - Encode

    func test_encodes_as_widthHeight() throws {
        let size = IntSize(width: 32, height: 28)
        let data = try JSONEncoder().encode(size)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Int]
        XCTAssertEqual(json?["width"], 32)
        XCTAssertEqual(json?["height"], 28)
        XCTAssertNil(json?["w"], "encode must not produce legacy 'w' key")
        XCTAssertNil(json?["h"], "encode must not produce legacy 'h' key")
    }

    // MARK: - Round-trip

    func test_roundtrip_widthHeight() throws {
        let original = IntSize(width: 360, height: 140)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(IntSize.self, from: data)
        XCTAssertEqual(original, decoded)
    }

    func test_roundtrip_legacy_decode_then_canonical_encode() throws {
        // Legacy w/h JSON decoded → re-encoded → canonical width/height
        let legacyJSON = Data(#"{"w":24,"h":28}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: legacyJSON)
        let reencoded = try JSONEncoder().encode(size)
        let dict = try JSONSerialization.jsonObject(with: reencoded) as? [String: Int]
        XCTAssertEqual(dict?["width"], 24)
        XCTAssertEqual(dict?["height"], 28)
    }

    // MARK: - Manifest fixture

    func test_decodes_real_scene_manifest_logicalSize() throws {
        // Verifies that the exact JSON from rooftop_server_garden manifest decodes.
        let fragment = Data(#"{"width":360,"height":140}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: fragment)
        XCTAssertEqual(size.w, 360)
        XCTAssertEqual(size.h, 140)
        XCTAssertEqual(size.cgSize.width, 360)
        XCTAssertEqual(size.cgSize.height, 140)
    }

    func test_decodes_real_pet_manifest_baseSize() throws {
        // Verifies nebula_bot baseSize {"width":24,"height":28}
        let fragment = Data(#"{"width":24,"height":28}"#.utf8)
        let size = try JSONDecoder().decode(IntSize.self, from: fragment)
        XCTAssertEqual(size.w, 24)
        XCTAssertEqual(size.h, 28)
    }
}
