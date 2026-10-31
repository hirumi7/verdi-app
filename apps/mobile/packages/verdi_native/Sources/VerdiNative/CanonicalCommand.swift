import CryptoKit
import Foundation

/// Only validated transport/domain values can construct a command. This codec
/// does not accept arbitrary JSON objects or confer authority from a valid hash.
indirect enum CanonicalValue {
    case null
    case boolean(Bool)
    case integer(Int64)
    case string(String)
    case utf16([UInt16])
    case array([CanonicalValue])
    case object([String: CanonicalValue])
}

enum CanonicalFailure: Error, Equatable {
    case integerOutOfRange, nonASCIIKey, sizeLimit, depthLimit
}

enum CanonicalCommand {
    static let byteLimit = 4 * 1024 * 1024
    static let depthLimit = 64

    static func bytes(_ value: CanonicalValue) throws -> Data {
        var writer = CanonicalWriter()
        try writer.write(value, depth: 0)
        return Data(writer.output)
    }

    static func hash(_ value: CanonicalValue) throws -> String {
        SHA256.hash(data: try bytes(value)).map { String(format: "%02x", $0) }.joined()
    }

    static func commandHash(type: String, payload: [String: CanonicalValue]) throws -> String {
        try hash(.object(["commandType": .string(type), "normalisedPayload": .object(payload)]))
    }
}

private struct CanonicalWriter {
    var output: [UInt8] = []

    mutating func append(_ byte: UInt8) throws {
        guard output.count < CanonicalCommand.byteLimit else { throw CanonicalFailure.sizeLimit }
        output.append(byte)
    }

    mutating func append(_ text: String) throws {
        guard text.utf8.count <= CanonicalCommand.byteLimit - output.count else { throw CanonicalFailure.sizeLimit }
        output.append(contentsOf: text.utf8)
    }

    mutating func string(_ value: String) throws {
        guard value.utf8.count <= CanonicalCommand.byteLimit - output.count else { throw CanonicalFailure.sizeLimit }
        try append(0x22)
        for scalar in value.unicodeScalars {
            try writeScalar(scalar)
        }
        try append(0x22)
    }

    mutating func writeScalar(_ scalar: Unicode.Scalar) throws {
        switch scalar.value {
        case 0x22: try append("\\\"")
        case 0x5c: try append("\\\\")
        case 0x08: try append("\\b")
        case 0x09: try append("\\t")
        case 0x0a: try append("\\n")
        case 0x0c: try append("\\f")
        case 0x0d: try append("\\r")
        case 0..<0x20:
            let hex = String(scalar.value, radix: 16)
            try append("\\u00" + (hex.count == 1 ? "0" : "") + hex)
        case 0x20..<0x80: try append(UInt8(scalar.value))
        default: try append(String(scalar))
        }
    }

    mutating func rawString(_ units: [UInt16]) throws {
        guard units.count <= CanonicalCommand.byteLimit - output.count else { throw CanonicalFailure.sizeLimit }
        try append(0x22)
        var index = 0
        while index < units.count {
            let unit = units[index]
            if (0xd800...0xdbff).contains(unit), index + 1 < units.count,
               (0xdc00...0xdfff).contains(units[index + 1]) {
                let scalar = 0x10000 + ((UInt32(unit) - 0xd800) << 10) + UInt32(units[index + 1]) - 0xdc00
                try writeScalar(Unicode.Scalar(scalar)!)
                index += 2
            } else if (0xd800...0xdfff).contains(unit) {
                try append("\\u" + String(unit, radix: 16))
                index += 1
            } else {
                try writeScalar(Unicode.Scalar(unit)!)
                index += 1
            }
        }
        try append(0x22)
    }

    mutating func write(_ value: CanonicalValue, depth: Int) throws {
        switch value {
        case .null: try append("null")
        case .boolean(let flag): try append(flag ? "true" : "false")
        case .integer(let number):
            guard number >= -9_007_199_254_740_991, number <= 9_007_199_254_740_991 else {
                throw CanonicalFailure.integerOutOfRange
            }
            try append(String(number))
        case .string(let value): try string(value)
        case .utf16(let units): try rawString(units)
        case .array(let values):
            guard depth < CanonicalCommand.depthLimit else { throw CanonicalFailure.depthLimit }
            try append(0x5b)
            for (index, value) in values.enumerated() {
                if index > 0 { try append(0x2c) }
                try write(value, depth: depth + 1)
            }
            try append(0x5d)
        case .object(let values):
            guard depth < CanonicalCommand.depthLimit else { throw CanonicalFailure.depthLimit }
            let keys = values.keys.sorted()
            guard keys.allSatisfy({ $0.utf8.allSatisfy { $0 < 128 } }) else { throw CanonicalFailure.nonASCIIKey }
            try append(0x7b)
            for (index, key) in keys.enumerated() {
                if index > 0 { try append(0x2c) }
                try string(key)
                try append(0x3a)
                // The key came from this immutable local dictionary.
                try write(values[key]!, depth: depth + 1)
            }
            try append(0x7d)
        }
    }
}
