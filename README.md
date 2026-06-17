# ADFoundation

Shared, modular foundations for the g-cqd engines — [ADJSON](https://github.com/g-cqd/ADJSON), ADSQL,
URLBuilder, and apple-docs. ADFoundation holds only **domain-neutral** primitives so each engine
stops re-implementing them, and is split into tiers **by dependency footprint** so every consumer
links exactly what it needs.

## Tiers

| Product | What it holds | External deps |
|---|---|---|
| **ADFCore** | byte buffers & readers, varint + little/big-endian codecs, overflow-checked arithmetic, ASCII classification, RFC 3629 UTF-8 validation, percent-coding, non-cryptographic hashing | none |
| **ADFUnicode** | canonical decomposition (NFD), case-folding, Unicode property sets | none |
| **ADFText** | bounded edit distance, tokenizer kernels | none |
| **ADFIO** | POSIX file channel, read-only memory mapping, cross-process atomics | none |
| **ADFoundation** | umbrella — re-exports `ADFCore` + `ADFUnicode` | — |

`ADFCore` is **Foundation-free, swift-syntax-free, and carries no transitive package dependency**:
it is consumed by the portable `ADJSONCore` engine and by the apple-docs zero-external-dependency
dylib, both of which must keep clean resolution graphs. `import ADFoundation` re-exports `ADFCore`
and `ADFUnicode`; import `ADFText` or `ADFIO` directly when you need them.

## Design principles

- **No traps at trust boundaries.** Size/offset arithmetic on untrusted input returns `nil`
  (see `checkedAdding(_:)`), never aborting the host process.
- **Strict memory safety.** The pointer kernels (`ADFCore`, `ADFIO`) build with SE-0458
  `-strict-memory-safety`; every unsafe construct is explicitly `unsafe`.
- **No recursion on untrusted input.** Decoders and scanners are iterative.

## Platforms

macOS 15 · iOS 18 · tvOS 18 · watchOS 11 · visionOS 2. `Synchronization` (`Mutex`/`Atomic`) and
`Span`/`RawSpan` are available at this floor; the 2025-SDK-gated `InlineArray`/`UTF8Span` are
deliberately not adopted.

## Usage

```swift
.package(url: "https://github.com/g-cqd/ADFoundation.git", branch: "main")
```

```swift
.target(name: "MyEngine", dependencies: [
    .product(name: "ADFCore", package: "ADFoundation")
])
```

## Development

```bash
swift build
swift test
swift package format          # format in place (swift-format)
ADF_DEV=1 swift package lint   # formatting + shipped-library discipline
ADF_DEV=1 swift package generate-documentation
```

## License

MIT — see [LICENSE](LICENSE).
