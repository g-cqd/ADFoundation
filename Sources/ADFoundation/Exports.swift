// The umbrella `ADFoundation` module re-exports every Foundation-free, zero-dependency runtime tier,
// so a single `import ADFoundation` sees the byte/number kernel, the Unicode kernel, the text
// algorithms, and the POSIX storage primitives as one flat public API.
//
// `ADFMacroSupport` is deliberately NOT re-exported: it links swift-syntax and is a compile-time
// helper that macro plugins import directly. Keeping it out of the umbrella means a plain
// `import ADFoundation` never drags swift-syntax into a consumer's resolution or link graph.
@_exported import ADFCore
@_exported import ADFIO
@_exported import ADFText
@_exported import ADFUnicode
