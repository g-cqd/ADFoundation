import ADFText
import Testing

struct TokenizerTests {
    private func windowStrings(_ s: String, _ size: Int) -> [String] {
        let b = Array(s.utf8)
        return ADFText.windows(b, size: size).map { String(decoding: b[$0], as: UTF8.self) }
    }

    @Test func slidingWindows() {
        #expect(windowStrings("abcd", 2) == ["ab", "bc", "cd"])
        #expect(windowStrings("abc", 3) == ["abc"])
        #expect(windowStrings("abc", 1) == ["a", "b", "c"])
    }

    @Test func windowEdgeCases() {
        #expect(windowStrings("ab", 3).isEmpty)  // size > count
        #expect(windowStrings("", 1).isEmpty)  // empty input
        #expect(windowStrings("abc", 0).isEmpty)  // non-positive size
    }

    @Test func windowsOverBytes() {
        let b: [UInt8] = [1, 2, 3, 4]
        #expect(ADFText.windows(b, size: 3).map { Array(b[$0]) } == [[1, 2, 3], [2, 3, 4]])
    }

    /// Exercises the generic path over a non-`Int`-indexed collection (String / String.Index).
    @Test func windowsOverStringIndices() {
        let s = "café"
        #expect(ADFText.windows(s, size: 2).map { String(s[$0]) } == ["ca", "af", "fé"])
    }

    private func splitStrings(_ s: String, omittingEmpty: Bool = true) -> [String] {
        let b = Array(s.utf8)
        return ADFText.split(b, omittingEmptySubsequences: omittingEmpty) { $0 == UInt8(ascii: " ") }
            .map { String(decoding: b[$0], as: UTF8.self) }
    }

    @Test func splitsOnSeparatorOmittingEmpty() {
        #expect(splitStrings("the quick  brown ") == ["the", "quick", "brown"])
        #expect(splitStrings("nospace") == ["nospace"])
        #expect(splitStrings("").isEmpty)
    }

    @Test func splitKeepsEmptyWhenRequested() {
        #expect(splitStrings("a  b", omittingEmpty: false) == ["a", "", "b"])
        #expect(splitStrings(" a", omittingEmpty: false) == ["", "a"])
    }
}
