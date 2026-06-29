import Foundation

/// Encodes the existing proto/location.proto wire format.
///
/// The project only sends protobuf messages and receives a one-byte heartbeat,
/// so a compact encoder keeps this prototype dependency-free while remaining
/// byte-compatible with the Android client.
enum ProtocolCodec {
    static func frame(_ response: ServerResponsePayload) -> Data {
        let payload = encode(response)
        var framed = Data()
        framed.appendUInt32BigEndian(UInt32(payload.count))
        framed.append(payload)
        return framed
    }

    private static func encode(_ response: ServerResponsePayload) -> Data {
        var data = Data()
        data.appendString(field: 1, value: response.status.rawValue)
        data.appendVarint(field: 2, value: UInt64(response.satellites))

        if let location = response.location {
            let encodedLocation = encode(location)
            data.appendLengthDelimited(field: 3, value: encodedLocation)
        }
        return data
    }

    private static func encode(_ location: LocationPayload) -> Data {
        var data = Data()
        data.appendVarint(field: 1, value: UInt64(bitPattern: location.timestamp))
        data.appendDouble(field: 2, value: location.latitude)
        data.appendDouble(field: 3, value: location.longitude)
        data.appendDouble(field: 4, value: location.altitude)
        data.appendFloat(field: 5, value: location.accuracy)
        data.appendFloat(field: 6, value: location.bearing)
        data.appendFloat(field: 7, value: location.speed)
        data.appendString(field: 9, value: location.provider)
        data.appendFloat(field: 10, value: location.locationAge)
        return data
    }
}

private extension Data {
    mutating func appendKey(field: UInt64, wireType: UInt64) {
        appendRawVarint((field << 3) | wireType)
    }

    mutating func appendVarint(field: UInt64, value: UInt64) {
        appendKey(field: field, wireType: 0)
        appendRawVarint(value)
    }

    mutating func appendString(field: UInt64, value: String) {
        appendLengthDelimited(field: field, value: Data(value.utf8))
    }

    mutating func appendLengthDelimited(field: UInt64, value: Data) {
        appendKey(field: field, wireType: 2)
        appendRawVarint(UInt64(value.count))
        append(value)
    }

    mutating func appendDouble(field: UInt64, value: Double) {
        appendKey(field: field, wireType: 1)
        var bits = value.bitPattern.littleEndian
        Swift.withUnsafeBytes(of: &bits) { append(contentsOf: $0) }
    }

    mutating func appendFloat(field: UInt64, value: Float) {
        appendKey(field: field, wireType: 5)
        var bits = value.bitPattern.littleEndian
        Swift.withUnsafeBytes(of: &bits) { append(contentsOf: $0) }
    }

    mutating func appendRawVarint(_ source: UInt64) {
        var value = source
        while value >= 0x80 {
            append(UInt8(value & 0x7f) | 0x80)
            value >>= 7
        }
        append(UInt8(value))
    }

    mutating func appendUInt32BigEndian(_ value: UInt32) {
        var bigEndian = value.bigEndian
        Swift.withUnsafeBytes(of: &bigEndian) { append(contentsOf: $0) }
    }
}

