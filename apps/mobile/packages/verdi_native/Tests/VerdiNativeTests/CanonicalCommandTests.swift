import Foundation
import XCTest
@testable import VerdiNative

final class CanonicalCommandTests: XCTestCase {
    func testSharedIndependentVectors() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "canonical-command-v1", withExtension: "json", subdirectory: "Fixtures"))
        let file = try JSONDecoder().decode(VectorFile.self, from: Data(contentsOf: url))
        XCTAssertEqual(file.version, 1)
        XCTAssertEqual(file.vectors.count, 20)
        for vector in file.vectors {
            let value = try vector.logicalValue()
            let bytes = try CanonicalCommand.bytes(value)
            XCTAssertEqual(String(decoding: bytes, as: UTF8.self), vector.canonical, vector.name)
            XCTAssertEqual(bytes.map { String(format: "%02x", $0) }.joined(), vector.utf8Hex, vector.name)
            XCTAssertEqual(try CanonicalCommand.hash(value), vector.sha256, vector.name)
            if let type = vector.commandType, let payload = vector.payload {
                XCTAssertEqual(try CanonicalCommand.commandHash(type: type, payload: payload.mapValues(\.value)), vector.sha256)
            }
            if let type = vector.commandType, let field = vector.rawPayloadField, let units = vector.utf16Units {
                XCTAssertEqual(try CanonicalCommand.commandHash(type: type, payload: [field: .utf16(units)]), vector.sha256)
            }
        }
    }

    func testUnicodeDoesNotNormalizeOrFoldAndArraysRetainOrder() throws {
        XCTAssertNotEqual(try CanonicalCommand.hash(.string("é")), try CanonicalCommand.hash(.string("e\u{301}")))
        XCTAssertNotEqual(try CanonicalCommand.hash(.string("é")), try CanonicalCommand.hash(.string("É")))
        XCTAssertNotEqual(try CanonicalCommand.hash(.array([.integer(1), .integer(2)])), try CanonicalCommand.hash(.array([.integer(2), .integer(1)])))
    }

    func testRejectsOutOfRangeIntegersAndNonASCIIKeys() throws {
        for integer in [Int64.min, -9_007_199_254_740_992, 9_007_199_254_740_992, Int64.max] {
            XCTAssertThrowsError(try CanonicalCommand.bytes(.integer(integer))) { XCTAssertEqual($0 as? CanonicalFailure, .integerOutOfRange) }
        }
        XCTAssertThrowsError(try CanonicalCommand.hash(.object(["é": .null]))) { XCTAssertEqual($0 as? CanonicalFailure, .nonASCIIKey) }
    }

    func testDepthBoundaryIncludesCommandWrapper() throws {
        func nested(_ count: Int) -> CanonicalValue {
            (0..<count).reduce(CanonicalValue.null) { value, _ in .array([value]) }
        }
        XCTAssertNoThrow(try CanonicalCommand.bytes(nested(64)))
        XCTAssertThrowsError(try CanonicalCommand.bytes(nested(65))) { XCTAssertEqual($0 as? CanonicalFailure, .depthLimit) }
        XCTAssertNoThrow(try CanonicalCommand.commandHash(type: "Test", payload: ["nested": nested(62)]))
        XCTAssertThrowsError(try CanonicalCommand.commandHash(type: "Test", payload: ["nested": nested(63)])) {
            XCTAssertEqual($0 as? CanonicalFailure, .depthLimit)
        }
    }

    func testExactUTF8ByteBoundaryASCIIEmojiAndEscapedControls() throws {
        let available = CanonicalCommand.byteLimit - 2 // String quotes count.
        for (unit, size) in [("a", 1), ("🌿", 4), ("\u{0}", 6)] {
            let value = String(repeating: unit, count: available / size) + String(repeating: "a", count: available % size)
            XCTAssertEqual(try CanonicalCommand.bytes(.string(value)).count, CanonicalCommand.byteLimit)
            XCTAssertThrowsError(try CanonicalCommand.bytes(.string(value + "a"))) { XCTAssertEqual($0 as? CanonicalFailure, .sizeLimit) }
        }
    }

    func testCommandByteBoundaryCountsWrapper() throws {
        let overhead = try CanonicalCommand.bytes(.object(["commandType": .string("Test"), "normalisedPayload": .object(["text": .string("")])])).count
        let text = String(repeating: "x", count: CanonicalCommand.byteLimit - overhead)
        XCTAssertNoThrow(try CanonicalCommand.commandHash(type: "Test", payload: ["text": .string(text)]))
        XCTAssertThrowsError(try CanonicalCommand.commandHash(type: "Test", payload: ["text": .string(text + "x")])) { XCTAssertEqual($0 as? CanonicalFailure, .sizeLimit) }
    }

    func testRawUTF16IsAStringAndPreservesExactSizeBoundary() throws {
        let valid = "é🌿\u{0}\u{2028}"
        XCTAssertEqual(try CanonicalCommand.bytes(.string(valid)), try CanonicalCommand.bytes(.utf16(Array(valid.utf16))))
        XCTAssertNotEqual(try CanonicalCommand.hash(.utf16([0xd800])), try CanonicalCommand.hash(.array([.integer(0xd800)])))
        let available = CanonicalCommand.byteLimit - 2
        let units = Array(repeating: UInt16(0xd800), count: available / 6) + Array(repeating: UInt16(0x61), count: available % 6)
        XCTAssertEqual(try CanonicalCommand.bytes(.utf16(units)).count, CanonicalCommand.byteLimit)
        XCTAssertThrowsError(try CanonicalCommand.bytes(.utf16(units + [0x61]))) { XCTAssertEqual($0 as? CanonicalFailure, .sizeLimit) }
    }
}

private struct VectorFile: Decodable { let version: Int; let vectors: [Vector] }
private struct Vector: Decodable {
    let name: String
    let input: FixtureValue?
    let canonical: String
    let utf8Hex: String
    let sha256: String
    let commandType: String?
    let payload: [String: FixtureValue]?
    let utf16Units: [UInt16]?
    let rawPayloadField: String?
    enum CodingKeys: String, CodingKey {
        case name, input, canonical, sha256, payload
        case utf8Hex = "utf8_hex", commandType = "command_type"
        case utf16Units = "utf16_units", rawPayloadField = "raw_payload_field"
    }

    func logicalValue() throws -> CanonicalValue {
        if let units = utf16Units {
            let raw = CanonicalValue.utf16(units)
            if let type = commandType, let field = rawPayloadField {
                return .object(["commandType": .string(type), "normalisedPayload": .object([field: raw])])
            }
            return raw
        }
        // JSON null is decoded as an absent optional, but the vector still
        // explicitly supplies its input key; all fixtures are committed.
        return input?.value ?? .null
    }
}

// Decoder only for the committed, independently generated valid fixture file.
// Not the eventual Pigeon decoder: JSONDecoder's numeric coercion is not authority.
private struct FixtureValue: Decodable {
    let value: CanonicalValue
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { value = .null }
        else if let boolean = try? container.decode(Bool.self) { value = .boolean(boolean) }
        else if let integer = try? container.decode(Int64.self) { value = .integer(integer) }
        else if let string = try? container.decode(String.self) { value = .string(string) }
        else if let array = try? container.decode([FixtureValue].self) { value = .array(array.map(\.value)) }
        else { value = .object(try container.decode([String: FixtureValue].self).mapValues(\.value)) }
    }
}
