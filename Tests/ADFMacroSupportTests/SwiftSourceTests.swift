import Testing

@testable import ADFMacroSupport

@Suite struct EscapedIdentifierTests {
    @Test func backticksReservedWords() {
        #expect(escapedIdentifier("default") == "`default`")
        #expect(escapedIdentifier("class") == "`class`")
        #expect(escapedIdentifier("Self") == "`Self`")
        #expect(escapedIdentifier("Any") == "`Any`")
    }

    @Test func leavesOrdinaryNamesUnchanged() {
        #expect(escapedIdentifier("name") == "name")
        #expect(escapedIdentifier("userID") == "userID")
        #expect(escapedIdentifier("klass") == "klass")
    }

    @Test func keywordSetCoversContextualAndDeclarationKeywords() {
        #expect(swiftKeywords.contains("associatedtype"))
        #expect(swiftKeywords.contains("fileprivate"))
        #expect(swiftKeywords.contains("rethrows"))
        #expect(!swiftKeywords.contains("foo"))
        #expect(swiftKeywords.count == 52)
    }
}

@Suite struct SwiftStringLiteralTests {
    @Test func wrapsPlainTextInQuotes() {
        #expect(swiftStringLiteral("abc") == #""abc""#)
        #expect(swiftStringLiteral("") == #""""#)
    }

    @Test func escapesQuotesAndBackslashes() {
        // Input: a"b\c  →  "a\"b\\c"
        #expect(swiftStringLiteral(#"a"b\c"#) == #""a\"b\\c""#)
    }

    @Test func escapesWhitespaceControls() {
        #expect(swiftStringLiteral("a\nb") == #""a\nb""#)
        #expect(swiftStringLiteral("\t") == #""\t""#)
        #expect(swiftStringLiteral("\r") == #""\r""#)
    }

    @Test func escapesNulAndControlScalars() {
        #expect(swiftStringLiteral("\u{0}") == #""\0""#)
        #expect(swiftStringLiteral("\u{1}") == #""\u{01}""#)
        #expect(swiftStringLiteral("\u{1F}") == #""\u{1f}""#)
        // 0x20 (space) is the first non-control scalar — passes through.
        #expect(swiftStringLiteral("\u{20}") == #"" ""#)
    }

    @Test func leavesNonAsciiUnescaped() {
        #expect(swiftStringLiteral("café—∑") == #""café—∑""#)
    }
}
