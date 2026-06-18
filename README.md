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
| **ADFMacroSupport** | swift-syntax helpers for macro compiler plugins: shared diagnostics, Swift source-literal escaping, identifier backticking | swift-syntax |
| **ADFoundation** | umbrella — re-exports every zero-dep tier (`ADFCore` / `ADFUnicode` / `ADFText` / `ADFIO`) | — |

`ADFCore` is **Foundation-free, swift-syntax-free, and carries no transitive package dependency**:
it is consumed by the portable `ADJSONCore` engine and by the apple-docs zero-external-dependency
dylib, both of which must keep clean resolution graphs. **`ADFMacroSupport` is the only tier with an
external dependency** (swift-syntax); it is linked solely by macro compiler plugins, so the core
tiers never pull it in.

### Choosing a tier

- Building a **runtime engine** (parser, store, builder): take `ADFCore`, plus `ADFUnicode` /
  `ADFText` / `ADFIO` only for the kernels you actually call.
- Writing a **macro compiler plugin**: take `ADFMacroSupport` (it already links swift-syntax).
- Want everything in one import: `ADFoundation` re-exports all four zero-dependency runtime tiers
  (`ADFCore` / `ADFUnicode` / `ADFText` / `ADFIO`). `ADFMacroSupport` stays separate — macro plugins
  import it directly — so a plain `import ADFoundation` never pulls in swift-syntax.

## Architecture

ADFoundation is the dependency root beneath the four g-cqd engines. Each links only the tiers it uses:

| Engine | Links from ADFoundation |
|---|---|
| **ADJSON** | `ADJSONCore` → `ADFCore` (+ `ADFUnicode`); `ADJSONMacros` → `ADFMacroSupport` |
| **ADSQL** | `ADDBCore` → `ADFCore` + `ADFIO`; `ADSQLMacros` → `ADFMacroSupport` |
| **URLBuilder** | `URLBuilder` → `ADFCore`; `URLBuilderMacros` → `ADFMacroSupport` |
| **apple-docs** | `ADBase` / `ADEmbed` → `ADFCore` / `ADFUnicode`; `ADSearchCascade` → `ADFText` |

Domain code stays with its owner: the JSON writer/escaper lives in ADJSON, the SQLite-FTS5 tokenizers
in ADSQL, URL semantics in URLBuilder, and the BERT/transformers.js tokenizers in apple-docs.
ADFoundation holds only the domain-neutral kernels they share — e.g. `ADFUnicode` carries the
transformers.js-parity Unicode tables, while ADSQL keeps its distinct SQLite-unicode61 tables.

## Design principles

- **No traps at trust boundaries.** Size/offset arithmetic on untrusted input returns `nil`
  (see `checkedAdding(_:)`), never aborting the host process; the binary reader and mmap views are
  bounded.
- **Strict memory safety.** The pointer kernels (`ADFCore`, `ADFIO`) build with SE-0458
  `-strict-memory-safety`; every unsafe construct is explicitly `unsafe`.
- **Neutral errors at the seam.** `ADFIO` throws a domain-neutral `IOError(errno:op:)`; a consumer
  with a richer taxonomy (e.g. a database error enum) maps it at its own boundary.
- **No recursion on untrusted input.** Decoders and scanners are iterative.
- **Aligned cross-process atomics.** `ADFIO`'s C11 atomics require 8-byte-aligned shared memory; the
  caller's table layout guarantees it (see the `ADFAtomics` header contract).

## Platforms

macOS 15 · iOS 18 · tvOS 18 · watchOS 11 · visionOS 2. `Synchronization` (`Mutex`/`Atomic`) is
available at this floor. `Span`/`RawSpan` are **deferred** — their ergonomic constructors and
stored-view lifetimes still sit behind experimental lifetime features on the pinned toolchain — and
the 2025-SDK-gated `InlineArray`/`UTF8Span` are likewise not adopted. The byte APIs therefore present
an `UnsafeRawBufferPointer` surface for now.

## Usage

Consumers resolve ADFoundation by its published remote by default, or override to a local checkout
via a per-dependency path environment variable — so the repositories need not live side by side:

```swift
// In a consumer's Package.swift:
let adFoundation: Package.Dependency =
    if let path = Context.environment["ADFOUNDATION_PATH"], !path.isEmpty {
        .package(path: path)
    } else {
        .package(url: "https://github.com/g-cqd/ADFoundation.git", branch: "main")
    }
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
swift package format            # format in place (swift-format)
ADF_DEV=1 swift package lint    # formatting + shipped-library discipline
ADF_DEV=1 swift package benchmark             # ordo-one suite (adaptive primitives)
ADF_DEV=1 swift package generate-documentation
```

## License

MIT — see [LICENSE](LICENSE).
