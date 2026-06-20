/// XML / SVG text escaping over UTF-8: replaces the five XML 1.0 predefined-entity metacharacters —
/// `&`, `<`, `>`, `"`, `'` — with `&amp;`, `&lt;`, `&gt;`, `&quot;`, `&apos;`, and copies every other
/// byte verbatim. The metacharacters are all ASCII, so escaping at the byte level never splits a
/// multi-byte scalar. One canonical escaper for the family's hand-built XML/SVG output (OpenSearch
/// descriptors, glyph and symbol SVGs), replacing the per-site `replacingOccurrences` / `+=` copies.
/// Domain-neutral and `Foundation`-free; one result allocation, no recursion, no trap.
///
/// `&apos;` (the XML 1.0 predefined entity) is used for the apostrophe rather than the HTML-style
/// numeric `&#39;`, so the output is valid in any XML/SVG context and byte-compatible with the
/// hand-rolled escapers it consolidates. The conservative five-character set covers both element text
/// and double-quoted attribute values: escaping `"`/`'` inside element text is harmless, and escaping
/// `&`/`<`/`>` everywhere is required.
public enum XMLEscape {
    /// Escape `value` for XML/SVG text or a double-quoted attribute value, returning the escaped bytes.
    @inlinable
    public static func escape(_ value: String) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(value.utf8.count)
        for byte in value.utf8 {
            switch byte {
                case UInt8(ascii: "&"): out.append(contentsOf: "&amp;".utf8)
                case UInt8(ascii: "<"): out.append(contentsOf: "&lt;".utf8)
                case UInt8(ascii: ">"): out.append(contentsOf: "&gt;".utf8)
                case UInt8(ascii: "\""): out.append(contentsOf: "&quot;".utf8)
                case UInt8(ascii: "'"): out.append(contentsOf: "&apos;".utf8)
                default: out.append(byte)
            }
        }
        return out
    }

    /// `String` convenience over ``escape(_:)`` for the XML/SVG builders that assemble a `String`.
    @inlinable
    public static func escaped(_ value: String) -> String {
        String(decoding: escape(value), as: UTF8.self)
    }
}
