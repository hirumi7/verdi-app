import Foundation

/// Bounded lossless reader. Raw strings never pass through Foundation JSON or
/// String(decoding:) repair. Schema owners decide which values require Text.
enum CanonicalParseFailure: Error { case malformed, duplicateKey, nonCanonical }

enum CanonicalParser {
    static func package(_ text: String) throws -> CanonicalValue {
        guard text.utf8.count <= 32*1024*1024 else { throw CanonicalFailure.sizeLimit }
        var parser = JSONTokenReader(bytes:Array(text.utf8)); parser.whitespace()
        let value = try parser.value(depth:0); parser.whitespace()
        guard parser.position == parser.bytes.count else { throw CanonicalParseFailure.malformed }
        return value
    }
    static func parse(_ text: String, limit: Int = CanonicalCommand.byteLimit) throws -> CanonicalValue {
        guard text.utf8.count <= limit else { throw CanonicalFailure.sizeLimit }
        var parser = JSONTokenReader(bytes: Array(text.utf8))
        let value = try parser.value(depth: 0)
        guard parser.position == parser.bytes.count else { throw CanonicalParseFailure.malformed }
        guard try CanonicalCommand.bytes(value) == Data(text.utf8) else { throw CanonicalParseFailure.nonCanonical }
        return value
    }
}

private struct JSONTokenReader {
    let bytes: [UInt8]
    var position = 0
    var peek: UInt8? { position < bytes.count ? bytes[position] : nil }
    mutating func whitespace() { while let b=peek, [9,10,13,32].contains(b) {position += 1} }
    mutating func take(_ byte: UInt8) throws {
        whitespace()
        guard peek == byte else { throw CanonicalParseFailure.malformed }
        position += 1
    }
    mutating func literal(_ value: String) throws {
        for byte in value.utf8 { try take(byte) }
    }
    mutating func string() throws -> [UInt16] {
        try take(34)
        var units: [UInt16] = []
        while let byte = peek {
            if byte == 34 { position += 1; return units }
            guard byte >= 32 else { throw CanonicalParseFailure.malformed }
            if byte == 92 {
                position += 1
                guard let escape = peek else { throw CanonicalParseFailure.malformed }
                position += 1
                switch escape {
                case 34, 92, 47: units.append(UInt16(escape))
                case 98: units.append(8)
                case 102: units.append(12)
                case 110: units.append(10)
                case 114: units.append(13)
                case 116: units.append(9)
                case 117:
                    var unit: UInt16 = 0
                    for _ in 0..<4 {
                        guard let hex = peek else { throw CanonicalParseFailure.malformed }
                        let digit: UInt16
                        switch hex {
                        case 48...57: digit = UInt16(hex - 48)
                        case 97...102: digit = UInt16(hex - 87)
                        case 65...70: digit = UInt16(hex - 55)
                        default: throw CanonicalParseFailure.malformed
                        }
                        unit = unit * 16 + digit
                        position += 1
                    }
                    units.append(unit)
                default: throw CanonicalParseFailure.malformed
                }
            } else if byte < 128 {
                units.append(UInt16(byte)); position += 1
            } else {
                let width: Int
                switch byte {
                case 0xc2...0xdf: width = 2
                case 0xe0...0xef: width = 3
                case 0xf0...0xf4: width = 4
                default: throw CanonicalParseFailure.malformed
                }
                guard position + width <= bytes.count,
                      let scalarText = String(bytes: bytes[position..<(position + width)], encoding: .utf8),
                      scalarText.unicodeScalars.count == 1 else { throw CanonicalParseFailure.malformed }
                units.append(contentsOf: scalarText.utf16)
                position += width
            }
        }
        throw CanonicalParseFailure.malformed
    }
    mutating func value(depth: Int) throws -> CanonicalValue {
        whitespace()
        guard let firstByte = peek else { throw CanonicalParseFailure.malformed }
        switch firstByte {
        case 110: try literal("null"); return .null
        case 116: try literal("true"); return .boolean(true)
        case 102: try literal("false"); return .boolean(false)
        case 34: return .utf16(try string())
        case 91:
            guard depth < CanonicalCommand.depthLimit else { throw CanonicalFailure.depthLimit }
            position += 1
            whitespace()
            var values: [CanonicalValue] = []
            if peek == 93 { position += 1; return .array(values) }
            while true {
                values.append(try value(depth: depth + 1))
                whitespace()
                if peek == 93 { position += 1; return .array(values) }
                try take(44)
            }
        case 123:
            guard depth < CanonicalCommand.depthLimit else { throw CanonicalFailure.depthLimit }
            position += 1
            whitespace()
            var values: [String: CanonicalValue] = [:]
            if peek == 125 { position += 1; return .object(values) }
            while true {
                whitespace()
                let units = try string()
                guard units.allSatisfy({ $0 < 128 }) else { throw CanonicalFailure.nonASCIIKey }
                let key = String(utf16CodeUnits: units, count: units.count)
                guard values[key] == nil else { throw CanonicalParseFailure.duplicateKey }
                try take(58)
                values[key] = try value(depth: depth + 1)
                whitespace()
                if peek == 125 { position += 1; return .object(values) }
                try take(44)
            }
        case 45, 48...57:
            let start = position
            if peek == 45 { position += 1 }
            guard let first = peek, (48...57).contains(first) else { throw CanonicalParseFailure.malformed }
            if first == 48 { position += 1 }
            else { while let digit = peek, (48...57).contains(digit) { position += 1 } }
            guard let number = Int64(String(decoding: bytes[start..<position], as: UTF8.self)),
                  (-9_007_199_254_740_991...9_007_199_254_740_991).contains(number) else {
                throw CanonicalFailure.integerOutOfRange
            }
            return .integer(number)
        default: throw CanonicalParseFailure.malformed
        }
    }
}

extension CanonicalValue {
    var object: [String: CanonicalValue]? { if case .object(let v) = self { return v }; return nil }
    var array: [CanonicalValue]? { if case .array(let v) = self { return v }; return nil }
    var integer: Int64? { if case .integer(let v) = self { return v }; return nil }
    var isNull: Bool { if case .null = self { return true }; return false }
    var units: [UInt16]? {
        switch self { case .string(let v): return Array(v.utf16); case .utf16(let v): return v; default: return nil }
    }
    /// Finalized identifiers/enums only. This never repairs a raw draft string.
    var text: String? {
        guard let units, !units.contains(0) else { return nil }
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xd800...0xdbff).contains(unit) {
                guard index + 1 < units.count, (0xdc00...0xdfff).contains(units[index + 1]) else { return nil }
                index += 2
            } else {
                guard !(0xdc00...0xdfff).contains(unit) else { return nil }
                index += 1
            }
        }
        return String(utf16CodeUnits: units, count: units.count)
    }
    func json() throws -> String { String(decoding: try CanonicalCommand.bytes(self), as: UTF8.self) }
}
