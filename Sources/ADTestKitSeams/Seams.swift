// `ADTestKitSeams` is now a stable re-export name for the `ADConcurrency` leaf.
//
// The shipped-safe production seams (`TaskProvider`/`LiveTaskProvider`, the `Clock`/`now`
// injection points `EpochSecondsProvider`/`MonotonicNanosecondsProvider`/`LiveClock`) and the
// `ResourcePool` pooling primitive moved into the zero-dependency `ADConcurrency` package, so a
// production library (ADJSON) can depend on `ADConcurrency` instead of a package named
// "TestKit". This module re-exports them unchanged, so every existing `import ADTestKitSeams`
// call site — `TaskProviderSpy`, the AD-family seam consumers — keeps compiling verbatim.
@_exported import ADConcurrency
