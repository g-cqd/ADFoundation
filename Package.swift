// swift-tools-version: 6.4
import PackageDescription

// Compatibility products forward to the shared Aemi implementation.

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

// SystemPackage is imported directly by the temporary-file compatibility tests.
var packageDependencies: [Package.Dependency] = [
    .package(url: "https://github.com/Aemi-Studio/aemi.git", branch: "main"),
    .package(url: "https://github.com/apple/swift-system.git", from: "1.7.2")
]
if isDev {
    // ordo-one benchmark suite (`ADF_DEV=1 swift package benchmark`).
    packageDependencies.append(
        .package(url: "https://github.com/ordo-one/benchmark", from: "1.4.0"))
}

let libraryBuildPlugins: [Target.PluginUsage] =
    isDev ? [.plugin(name: "LintBuild", package: "aemi")] : []

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
        // Runtime umbrella forwards to AemiFoundation.
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
        .target(
            name: "ADFCore", dependencies: [.product(name: "AemiKernel", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADFKernels", dependencies: [.product(name: "AemiKernels", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADFUnicode", dependencies: [.product(name: "AemiUnicode", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADFText", dependencies: [.product(name: "AemiText", package: "aemi")], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        .target(
            name: "ADFIO", dependencies: [.product(name: "AemiIO", package: "aemi")], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        .target(
            name: "ADFMetrics", dependencies: [.product(name: "AemiMetrics", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADConcurrency", dependencies: [.product(name: "AemiRuntime", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADFMacroSupport", dependencies: [.product(name: "AemiMacroSupport", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADTestKit", dependencies: [.product(name: "AemiTestKit", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADTestKitSeams", dependencies: [.product(name: "AemiTestKitSeams", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADFoundation", dependencies: [.product(name: "AemiFoundation", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .target(
            name: "ADTesting", dependencies: [.product(name: "AemiTestKit", package: "aemi")],
            swiftSettings: strictSettings, plugins: libraryBuildPlugins),
        .executableTarget(name: "ADFKernelsProbe", dependencies: ["ADFKernels"], swiftSettings: strictSettings),

        // ── Tests ──
        .testTarget(
            name: "ADFCoreTests", dependencies: ["ADFCore", "ADTestKit", .product(name: "AemiKernel", package: "aemi")],
            swiftSettings: testSettings),
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
            name: "ADTestKitTests", dependencies: ["ADTestKit", "ADTestKitSeams", systemPackage],
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
