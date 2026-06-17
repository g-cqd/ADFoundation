/// LEB128 variable-length integers and zig-zag signed mapping — the compact integer codec shared
/// by free lists, record codecs, and posting lists. Relocated from ADSQL's `ByteCodec`.
public enum Varint {
    /// Appends `value` as an unsigned LEB128 varint (7 bits per byte, high bit = continuation).
    public static func append(_ value: UInt64, to bytes: inout [UInt8]) {
        var v = value
        while v >= 0x80 {
            bytes.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        bytes.append(UInt8(v))
    }

    /// Reads a varint from a raw buffer, advancing `offset`. Returns `nil` on truncation or on a
    /// value that would overflow 64 bits — never traps (the no-trap-at-boundaries rule).
    public static func read(_ bytes: UnsafeRawBufferPointer, _ offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < bytes.count {
            let byte = unsafe bytes[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    /// Safe `[UInt8]` overload (bounds-checked, no `unsafe`) for callers decoding from arrays.
    public static func read(_ bytes: [UInt8], _ offset: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while offset < bytes.count {
            let byte = bytes[offset]
            offset += 1
            result |= UInt64(byte & 0x7F) << shift
            if byte & 0x80 == 0 { return result }
            shift += 7
            if shift > 63 { return nil }
        }
        return nil
    }

    /// Maps a signed integer to an unsigned varint-friendly value (small magnitudes ⇒ short codes).
    @inline(__always)
    public static func zigzag(_ value: Int64) -> UInt64 {
        UInt64(bitPattern: (value << 1) ^ (value >> 63))
    }

    /// Inverse of ``zigzag(_:)``.
    @inline(__always)
    public static func unzigzag(_ value: UInt64) -> Int64 {
        Int64(bitPattern: (value >> 1)) ^ -Int64(bitPattern: value & 1)
    }
}
