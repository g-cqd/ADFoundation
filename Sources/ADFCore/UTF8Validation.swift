/// RFC 3629 UTF-8 well-formedness. Rejects invalid lead/continuation bytes, overlong encodings,
/// surrogate code points (U+D800–U+DFFF), and values above U+10FFFF.
///
/// Relocated from ADJSON's `JSONUTF8`. Domain-neutral here: malformed input returns `nil` rather
/// than throwing a JSON-specific error, so each caller maps the failure to its own error type.
public enum UTF8Validation {
    /// The expected byte length (2–4) of a multi-byte sequence from its lead byte, or `nil` for an
    /// invalid lead (a continuation byte or a 5+/6-byte form). Lets a resumable scanner decide how
    /// many bytes it must wait for before validating the full sequence.
    @inlinable
    public static func leadLength(_ b: UInt8) -> Int? {
        if b & 0xE0 == 0xC0 { return 2 }
        if b & 0xF0 == 0xE0 { return 3 }
        if b & 0xF8 == 0xF0 { return 4 }
        return nil
    }

    /// Validates the multi-byte UTF-8 sequence starting at `j` (where `p[j] >= 0x80`) within the
    /// `0..<n` window, returning its length in bytes, or `nil` if the sequence is malformed,
    /// truncated, overlong, a surrogate, or out of range.
    @inlinable
    public static func sequenceLength(_ p: UnsafePointer<UInt8>, _ j: Int, _ n: Int) -> Int? {
        let b = unsafe p[j]
        let length: Int
        let lowerBound: UInt32
        var scalar: UInt32
        if b & 0xE0 == 0xC0 {
            length = 2
            lowerBound = 0x80
            scalar = UInt32(b & 0x1F)
        } else if b & 0xF0 == 0xE0 {
            length = 3
            lowerBound = 0x800
            scalar = UInt32(b & 0x0F)
        } else if b & 0xF8 == 0xF0 {
            length = 4
            lowerBound = 0x1_0000
            scalar = UInt32(b & 0x07)
        } else {
            return nil  // continuation byte or invalid lead (0xF8+)
        }
        guard j + length <= n else { return nil }
        for k in 1..<length {
            let cont = unsafe p[j + k]
            guard cont & 0xC0 == 0x80 else { return nil }
            scalar = (scalar << 6) | UInt32(cont & 0x3F)
        }
        let upperBound: UInt32 = length == 2 ? 0x7FF : (length == 3 ? 0xFFFF : 0x10_FFFF)
        guard scalar >= lowerBound, scalar <= upperBound else { return nil }
        guard !(scalar >= 0xD800 && scalar <= 0xDFFF) else { return nil }
        return length
    }
}
