import Foundation

enum ProtoWireType: UInt {
    case varint = 0
    case lengthDelimited = 2
}

struct ProtoField {
    let number: Int
    let wireType: ProtoWireType
    let payload: [UInt8]

    var intValue: Int? {
        guard wireType == .varint,
              let decoded = Decoder.decodeVarint(payload) else {
            return nil
        }
        return Int(decoded.value)
    }

    var stringValue: String? {
        guard wireType == .lengthDelimited else { return nil }
        return String(bytes: payload, encoding: .utf8)
    }
}

enum ProtoMessageCoder {
    static func encodeVarintField(_ number: Int, value: Int) -> [UInt8] {
        guard value >= 0 else { return [] }
        let encodedValue = Encoder.encodeVarint(UInt(value))
        return encodeTag(number, wireType: .varint) + encodedValue
    }

    static func encodeStringField(_ number: Int, value: String) -> [UInt8] {
        let bytes = Array(value.utf8)
        return encodeLengthDelimitedField(number, payload: bytes)
    }

    static func encodeMessageField(_ number: Int, payload: [UInt8]) -> [UInt8] {
        encodeLengthDelimitedField(number, payload: payload)
    }

    static func decodeDelimitedMessage(_ bytes: [UInt8]) -> [UInt8]? {
        guard let decodedLength = Decoder.decodeVarint(bytes) else { return nil }
        let startIndex = decodedLength.bytesCount
        let endIndex = startIndex + Int(decodedLength.value)
        guard startIndex <= bytes.count, endIndex <= bytes.count else { return nil }
        return Array(bytes[startIndex..<endIndex])
    }

    static func decodeFields(_ bytes: [UInt8]) -> [ProtoField]? {
        var index = 0
        var fields: [ProtoField] = []

        while index < bytes.count {
            guard let tag = decodeVarint(bytes, startingAt: index),
                  let wireType = ProtoWireType(rawValue: UInt(tag.value & 0x07)) else {
                return nil
            }

            index += tag.length
            let fieldNumber = Int(tag.value >> 3)

            switch wireType {
            case .varint:
                guard let value = decodeVarint(bytes, startingAt: index) else { return nil }
                let payload = Array(bytes[index..<index + value.length])
                fields.append(ProtoField(number: fieldNumber, wireType: .varint, payload: payload))
                index += value.length
            case .lengthDelimited:
                guard let length = decodeVarint(bytes, startingAt: index) else { return nil }
                index += length.length
                let endIndex = index + Int(length.value)
                guard endIndex <= bytes.count else { return nil }
                let payload = Array(bytes[index..<endIndex])
                fields.append(ProtoField(number: fieldNumber, wireType: .lengthDelimited, payload: payload))
                index = endIndex
            }
        }

        return fields
    }

    private static func encodeTag(_ number: Int, wireType: ProtoWireType) -> [UInt8] {
        let tag = UInt((number << 3) | Int(wireType.rawValue))
        return Encoder.encodeVarint(tag)
    }

    private static func encodeLengthDelimitedField(_ number: Int, payload: [UInt8]) -> [UInt8] {
        encodeTag(number, wireType: .lengthDelimited)
        + Encoder.encodeVarint(UInt(payload.count))
        + payload
    }

    private static func decodeVarint(_ bytes: [UInt8], startingAt index: Int) -> (value: UInt, length: Int)? {
        guard index < bytes.count else { return nil }
        let slice = Array(bytes[index...])
        guard let decoded = Decoder.decodeVarint(slice) else { return nil }
        return (decoded.value, decoded.bytesCount)
    }
}
