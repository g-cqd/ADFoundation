/// Lenient leading-numeric-prefix parsing over UTF-8 bytes. Reads a number from the front of the input
/// (after optional ASCII whitespace) and ignores any trailing non-numeric bytes — the shape needed for
/// tolerant config / environment-variable reads (`"0.65"`, `"200ms"`, `"  16 "`). Domain-neutral and
/// `Foundation`-free; iterative (no recursion) and no-trap (returns `nil` rather than crashing).
///
/// Operates on a concrete `[UInt8]` scanned with plain `Int` indices: concrete (not generic over
/// `Collection`, which would run unspecialized and allocate across a module boundary) and safe (the
/// `Array` subscript is bounds-checked, so no `unsafe` is needed under the kernel's strict-memory-safety
/// mode). Allocation-free on the fast path — digits accumulate into registers and the value is assembled
/// by the shared ``DecimalFloat`` Clinger fast path (correctly rounded for the common case). Only a
/// pathological literal (> 19 significant digits, or one outside the exact fast-path domain) falls back
/// to the standard library's parser. The decimal→float kernel and the power-of-ten tables live once in
/// ``DecimalFloat`` and are shared with ADJSON's number parser. Callers holding a `String` pass
/// `Array(s.utf8)`.
public enum NumberParse {
    @usableFromInline static let minus = UInt8(ascii: "-")
    @usableFromInline static let plus = UInt8(ascii: "+")
    @usableFromInline static let dot = UInt8(ascii: ".")

    /// `true` for the ASCII whitespace a leading run is allowed to skip (space, tab, NL, VT, FF, CR).
    @inlinable
    public static func isASCIIWhitespace(_ b: UInt8) -> Bool {
        b == 0x20 || (b >= 0x09 && b <= 0x0D)
    }

    /// `0x30...0x39` → `0...9`.
    @inlinable
    public static func isDigit(_ b: UInt8) -> Bool { b >= 0x30 && b <= 0x39 }

    /// Maps an ASCII digit or letter to its base-36 value (`0-9`, `a-z`/`A-Z` → `10-35`), else `nil`.
    @inlinable
    public static func digitValue(_ b: UInt8) -> Int? {
        switch b {
            case 0x30 ... 0x39: return Int(b - 0x30)
            case 0x61 ... 0x7A: return Int(b - 0x61) + 10
            case 0x41 ... 0x5A: return Int(b - 0x41) + 10
            default: return nil
        }
    }

    /// Parses a leading decimal `Double`: optional whitespace, optional sign, integer digits, an
    /// optional `.`-fraction, and an optional `[eE][+-]?digits` exponent. Trailing bytes are ignored.
    /// Returns `nil` when no significant digit is present (a bare sign, lone `"."`, or empty). A `.`/`e`
    /// not followed by digits is dropped (`"5."` → `5`, `"1e"` → `1`). Allocation-free for the common
    /// case via the shared Clinger fast path; an over-long literal falls back to the standard library's
    /// `Double` parser over the recognized slice. `@inlinable` so a consumer specializes/inlines it
    /// across the module boundary (no cross-module-optimization needed on the shipped library).
    @inlinable
    public static func doublePrefix(_ bytes: [UInt8]) -> Double? {
        let end = bytes.count
        var i = 0
        while i < end, isASCIIWhitespace(bytes[i]) { i += 1 }

        var negative = false
        if i < end, bytes[i] == plus || bytes[i] == minus {
            negative = bytes[i] == minus
            i += 1
        }
        let digitsStart = i  // after the sign — the slice fed to the stdlib fallback (no sign char)

        // Accumulate the significand into a UInt64 and the net power of ten into `exponent` (each
        // fraction digit lowers it by one). Past 19 digits the UInt64 would overflow, so we stop
        // accumulating and mark `overlong`; the scan continues only to locate the prefix end.
        var significand: UInt64 = 0
        var digits = 0
        var exponent = 0
        var sawDigit = false
        var overlong = false

        while i < end, isDigit(bytes[i]) {
            sawDigit = true
            if digits < 19 {
                significand = significand &* 10 &+ UInt64(bytes[i] - 0x30)
                digits += 1
            } else {
                overlong = true
            }
            i += 1
        }
        if i < end, bytes[i] == dot {
            i += 1
            while i < end, isDigit(bytes[i]) {
                sawDigit = true
                if digits < 19 {
                    significand = significand &* 10 &+ UInt64(bytes[i] - 0x30)
                    digits += 1
                    exponent -= 1
                } else {
                    overlong = true
                }
                i += 1
            }
        }
        guard sawDigit else { return nil }

        // Exponent: consumed only when well-formed (digits follow the optional sign).
        if i < end, bytes[i] == 0x65 || bytes[i] == 0x45 {  // e / E
            var j = i + 1
            var expNegative = false
            if j < end, bytes[j] == plus || bytes[j] == minus {
                expNegative = bytes[j] == minus
                j += 1
            }
            var expValue = 0
            var sawExpDigit = false
            while j < end, isDigit(bytes[j]) {
                // Clamp so a pathological exponent can't overflow `Int`; anything ≥ 1e6 is far outside the
                // ±22 the fast path accepts, so the clamp only routes it to the (correct) fallback.
                if expValue < 1_000_000 { expValue = expValue * 10 + Int(bytes[j] - 0x30) }
                sawExpDigit = true
                j += 1
            }
            if sawExpDigit {
                exponent += expNegative ? -expValue : expValue
                i = j
            }
        }

        if !overlong, let value = DecimalFloat.double(significand: significand, exponent: exponent, negative: negative)
        {
            return value
        }
        // Rare path: an over-long literal, or one outside the exact fast-path domain. The recognized
        // slice (digits only, no sign) is a well-formed numeral the stdlib parser rounds correctly.
        guard let magnitude = Double(String(decoding: bytes[digitsStart ..< i], as: UTF8.self)) else {
            return nil
        }
        return negative ? -magnitude : magnitude
    }

    /// Parses a leading `Int`: optional whitespace, optional sign, then digits in `radix` (`2...36`).
    /// Trailing bytes are ignored. Returns `nil` when no digit is present or the value overflows `Int`.
    /// Allocation-free: digits accumulate directly with overflow checks (the negative register avoids the
    /// `Int.min` asymmetry). `radix` must be in `2...36`. `@inlinable` for cross-module inlining.
    @inlinable
    public static func intPrefix(_ bytes: [UInt8], radix: Int = 10) -> Int? {
        precondition(radix >= 2 && radix <= 36, "radix must be in 2...36")
        let end = bytes.count
        var i = 0
        while i < end, isASCIIWhitespace(bytes[i]) { i += 1 }

        var negative = false
        if i < end, bytes[i] == plus || bytes[i] == minus {
            negative = bytes[i] == minus
            i += 1
        }

        // Accumulate in the negative range so `Int.min` is representable; flip the sign at the end.
        var result = 0
        var sawDigit = false
        while i < end, let value = digitValue(bytes[i]), value < radix {
            let (scaled, overflow1) = result.multipliedReportingOverflow(by: radix)
            guard !overflow1 else { return nil }
            let (next, overflow2) = scaled.subtractingReportingOverflow(value)
            guard !overflow2 else { return nil }
            result = next
            sawDigit = true
            i += 1
        }
        guard sawDigit else { return nil }
        if negative { return result }
        return result == Int.min ? nil : -result  // |Int.min| is the one magnitude a positive can't hold
    }
}
