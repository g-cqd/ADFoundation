// swift-tools-version: 6.4
import PackageDescription

// ADFoundation — the umbrella package + the family's shared, finely-decomposed foundation tiers.
// ONE package, MANY small targets (link exactly what you need), with two umbrella modules:
//   • `import ADFoundation` — every zero-dependency RUNTIME tier (byte/number kernel, Unicode, text,
//     POSIX IO, process metrics, and the concurrency seams).
//   • `import ADTesting`    — the deterministic-testing kit (ADTestKit + ADTestKitSeams; the seams
//     come transitively). The test-side mirror of the runtime umbrella.
// Folded in (formerly standalone packages): ADConcurrency (zero-dep production seams + pools) and
// ADTestKit (the testing kit). Keeping them as IN-PACKAGE targets dissolves the old
// ADFoundation↔ADTestKit dependency cycle — ADFoundation's own tests now use the in-package kit
// directly, so there is no external test-kit package to cycle with.

// Strict, dependency-safe settings applied to every Swift target. `.v6` turns on complete
// strict-concurrency checking; the upcoming features tighten existentials (`any`) and import visibility.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .treatAllWarnings(as: .error),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility")
]

// The byte/IO kernel additionally adopts SE-0458 strict memory safety + the compile-time-only
// `Lifetimes` feature (no runtime-floor impact). Applied to the pointer/POSIX targets (ADFCore, ADFIO).
let kernelSettings: [SwiftSetting] =
    strictSettings + [.strictMemorySafety(), .enableExperimentalFeature("Lifetimes")]

// Compile-time type-check timing warnings — unsafe flags, so they live only on test targets.
// The budget is env-tunable because `treatAllWarnings(as: .error)` turns an overrun into a HARD
// build error while the measured quantity is type-check WALL TIME — structurally flaky on shared
// CI runners (observed 102–168 ms flips for bodies comfortably under 100 ms locally). CI exports
// AD_TYPECHECK_BUDGET_MS=250 to calibrate for runner noise; unset (local builds) it stays 100 so
// regressions still surface at developer-machine speed.
let typeCheckBudgetMS = Context.environment["AD_TYPECHECK_BUDGET_MS"].flatMap { Int($0) } ?? 100
let timingWarningFlags: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=\(typeCheckBudgetMS)",
        "-Xfrontend", "-warn-long-expression-type-checking=\(typeCheckBudgetMS)"
    ])
]

// Tests: strict + timing warnings + runtime actor data-race checks.
let testSettings: [SwiftSetting] =
    strictSettings + timingWarningFlags + [.unsafeFlags(["-enable-actor-data-race-checks"])]

// Dev-only tooling is gated behind `ADF_DEV` so consumers never resolve it.
let isDev = Context.environment["ADF_DEV"] != nil

// The libFuzzer kernel target is gated behind `ADF_FUZZ` so the default build never links a `main`-less
// `-sanitize=fuzzer` executable. `-sanitize=fuzzer` is a Linux capability of the toolchain (the Darwin
// SDK rejects it), so this is built + run in the Linux CI fuzz job. See `Sources/ADFKernelsFuzz`.
let isFuzz = Context.environment["ADF_FUZZ"] != nil

// Non-dev dependencies:
//   • swift-syntax     — backs ADFMacroSupport (the shared macro-plugin helpers).
//   • swift-collections — `HeapModule` backs the in-package ADTestKit `TestClock` sleeper queue.
//   • swift-system     — `SystemPackage` backs ADTestKit's typed temp-file paths.
// The latter two enter the graph because the test kit now ships as a product of THIS package; a
// consumer that links only a runtime tier (e.g. `ADFCore`) still does not BUILD them, but does
// resolve them (SwiftPM resolution is package-granular). This is the accepted cost of the single
// umbrella package over the previous separate ADConcurrency / ADTestKit repos.
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
    .package(url: "https://github.com/apple/swift-collections.git", from: "1.6.0"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.7.2")
]
if isDev {
    // Shared lint/format tooling (Format/Lint/LintBuild plugins + canonical `.swift-format`).
    if let path = Context.environment["ADBUILDTOOLS_PATH"], !path.isEmpty {
        packageDependencies.append(.package(path: path))
    } else {
        packageDependencies.append(
            .package(url: "https://github.com/g-cqd/ADBuildTools.git", branch: "main"))
    }
    packageDependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"))
    // ordo-one benchmark suite (`ADF_DEV=1 swift package benchmark`).
    packageDependencies.append(
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0"))
}

let libraryBuildPlugins: [Target.PluginUsage] =
    isDev ? [.plugin(name: "LintBuild", package: "ADBuildTools")] : []

let heapModule: Target.Dependency = .product(name: "HeapModule", package: "swift-collections")
let systemPackage: Target.Dependency = .product(name: "SystemPackage", package: "swift-system")

let package = Package(
    name: "ADFoundation",
    // Family floor: `Synchronization` (Mutex/Atomic) ships in macOS 15 / iOS 18 / tvOS 18 / watchOS 11 /
    // visionOS 2; `Span`/`RawSpan` back-deploy further. The 2025-SDK-gated InlineArray/UTF8Span are not adopted.
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        // Runtime umbrella: `import ADFoundation` → every zero-dependency runtime tier.
        .library(name: "ADFoundation", targets: ["ADFoundation"]),
        // Test umbrella: `import ADTesting` → the deterministic-testing kit (+ seams).
        .library(name: "ADTesting", targets: ["ADTesting"]),
        // Individual runtime tiers — link exactly what you need.
        .library(name: "ADFCore", targets: ["ADFCore"]),
        // Runtime-dispatched SIMD byte kernels (JSON string scan, ASCII fold, byte search). Its own
        // product so a consumer (e.g. HTTP) can link just this without the rest of ADFCore.
        .library(name: "ADFKernels", targets: ["ADFKernels"]),
        .library(name: "ADFUnicode", targets: ["ADFUnicode"]),
        .library(name: "ADFText", targets: ["ADFText"]),
        .library(name: "ADFIO", targets: ["ADFIO"]),
        .library(name: "ADFMetrics", targets: ["ADFMetrics"]),
        // Concurrency seams + pools (formerly the standalone ADConcurrency package).
        .library(name: "ADConcurrency", targets: ["ADConcurrency"]),
        // Shared swift-syntax helpers for macro compiler plugins. The one tier that links swift-syntax.
        .library(name: "ADFMacroSupport", targets: ["ADFMacroSupport"]),
        // Test tooling (formerly the standalone ADTestKit package).
        .library(name: "ADTestKit", targets: ["ADTestKit"]),
        .library(name: "ADTestKitSeams", targets: ["ADTestKitSeams"])
    ],
    dependencies: packageDependencies,
    targets: [
        // ── Runtime tiers ──
        // ADFCore — pointer-level byte primitives; SE-0458 strict memory safety. Depends on ADFKernels
        // for the shared runtime-dispatched SIMD scans (XML escape; UTF-8 validation widening). Acyclic:
        // ADFKernels → CADFKernels only (its scalar fallback is self-contained, never imports ADFCore).
        .target(
            name: "ADFCore", dependencies: ["ADFKernels"], swiftSettings: kernelSettings,
            plugins: libraryBuildPlugins),
        // CADFKernels — runtime-dispatched SIMD byte kernels in C (per-function `__attribute__((target))`
        // + `pthread_once` feature probe, extending the CCRC32 pattern). Default C-target convention
        // (public `include/`), no linker/cSettings — `sysctl`/`getauxval`/`pthread` live in libSystem/glibc.
        .target(name: "CADFKernels"),
        // ADFKernels — the pure-Swift facade over CADFKernels; strict-memory-safe like ADFCore.
        .target(
            name: "ADFKernels", dependencies: ["CADFKernels"], swiftSettings: kernelSettings,
            plugins: libraryBuildPlugins),
        // ADFKernelsProbe — a standalone differential check (kernels vs scalar reference) + ISA-tier
        // printer. Runs the x86_64 slice under Rosetta (`swift run --arch x86_64 ADFKernelsProbe`),
        // which the in-process `swift test` loader cannot do cross-arch; also the per-arch CI smoke.
        .executableTarget(
            name: "ADFKernelsProbe", dependencies: ["ADFKernels"], swiftSettings: strictSettings),
        .target(
            name: "ADFUnicode", dependencies: ["ADFCore"], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        .target(
            name: "ADFText", dependencies: ["ADFCore", "ADFUnicode"], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        .target(
            name: "ADFIO", dependencies: ["ADFCore"], swiftSettings: kernelSettings,
            plugins: libraryBuildPlugins),
        .target(name: "ADFMetrics", swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        // ADConcurrency — zero-dep production seams (TaskProvider/Clock) + ResourcePool / BlockingOffloadPool.
        .target(name: "ADConcurrency", swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        // Runtime umbrella — re-exports every runtime tier (NOT ADFMacroSupport: swift-syntax stays opt-in).
        .target(
            name: "ADFoundation",
            dependencies: [
                "ADFCore", "ADFKernels", "ADFIO", "ADFText", "ADFUnicode", "ADFMetrics", "ADConcurrency"
            ],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),

        // ── Macro support (the one swift-syntax tier) ──
        .target(
            name: "ADFMacroSupport",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ],
            swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),

        // ── Test tooling ──
        // CADTestKitMalloc — C shim exposing process-wide heap-allocation counting (Darwin malloc_logger).
        .target(name: "CADTestKitMalloc"),
        // ADTestKitSeams — stable re-export of the ADConcurrency seams (`@_exported import ADConcurrency`).
        .target(
            name: "ADTestKitSeams", dependencies: ["ADConcurrency"],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        // ADTestKit — the deterministic-testing kit (Testing-backed asserts, SeededRNG, Fuzz, oracles,
        // TestClock/AsyncProbe, gates). HeapModule = TestClock sleeper queue; SystemPackage = temp files.
        .target(
            name: "ADTestKit",
            dependencies: ["ADTestKitSeams", "CADTestKitMalloc", heapModule, systemPackage],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        // ADTesting — test umbrella: one `import ADTesting` for a test target.
        .target(
            name: "ADTesting", dependencies: ["ADTestKit", "ADTestKitSeams"],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),

        // ── Tests ──
        // ADFCore / ADFText use the in-package kit's `SeededRNG` — the cycle-break in action (no external
        // ADTestKit package, so depending on it from ADFoundation's own tests is just an intra-package edge).
        .testTarget(
            name: "ADFCoreTests", dependencies: ["ADFCore", "ADTestKit"], swiftSettings: testSettings),
        .testTarget(
            name: "ADFKernelsTests", dependencies: ["ADFKernels", "ADTestKit"],
            swiftSettings: testSettings),
        .testTarget(name: "ADFUnicodeTests", dependencies: ["ADFUnicode"], swiftSettings: testSettings),
        .testTarget(
            name: "ADFTextTests", dependencies: ["ADFText", "ADTestKit"], swiftSettings: testSettings),
        .testTarget(name: "ADFIOTests", dependencies: ["ADFIO"], swiftSettings: testSettings),
        .testTarget(name: "ADFMetricsTests", dependencies: ["ADFMetrics"], swiftSettings: testSettings),
        .testTarget(
            name: "ADFMacroSupportTests", dependencies: ["ADFMacroSupport"], swiftSettings: testSettings),
        // Folded suites keep their origin settings (no aggressive type-check timing gate).
        .testTarget(
            name: "ADConcurrencyTests", dependencies: ["ADConcurrency"], swiftSettings: strictSettings),
        .testTarget(
            name: "ADTestKitTests", dependencies: ["ADTestKit", "ADTestKitSeams"],
            swiftSettings: strictSettings)
    ]
)

// libFuzzer kernel target (ADF_FUZZ-gated; Linux-CI-only — `-sanitize=fuzzer` is Darwin-rejected).
// `-parse-as-library` because libFuzzer supplies `main`; the explicit product drives the link.
if isFuzz {
    package.targets.append(
        .executableTarget(
            name: "ADFKernelsFuzz",
            dependencies: ["ADFKernels"],
            swiftSettings: strictSettings + [
                .unsafeFlags(["-parse-as-library", "-sanitize=fuzzer"])
            ]))
    package.products.append(.executable(name: "ADFKernelsFuzz", targets: ["ADFKernelsFuzz"]))
}

// ordo-one benchmark suite (ADF_DEV-gated).
if isDev {
    package.targets.append(
        .executableTarget(
            name: "ADFoundationSuite",
            dependencies: [
                "ADFCore", "ADFText", "ADFKernels",
                .product(name: "Benchmark", package: "benchmark")
            ],
            path: "Benchmarks/ADFoundationSuite",
            swiftSettings: strictSettings,
            plugins: [.plugin(name: "BenchmarkPlugin", package: "benchmark")]))
}
