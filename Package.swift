// swift-tools-version: 6.3
import PackageDescription

// Strict, dependency-safe settings applied to every Swift target. `.v6` turns on complete
// strict-concurrency checking; the upcoming features tighten existentials (`any`) and import
// visibility. None are unsafe flags, so the libraries stay resolvable through a version-pinned
// `.package(url:from:)` requirement. Aligned with the sibling ADJSON / ADSQL / URLBuilder packages.
let strictSettings: [SwiftSetting] = [
    .swiftLanguageMode(.v6),
    .enableUpcomingFeature("ExistentialAny"),
    .enableUpcomingFeature("InternalImportsByDefault"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

// The byte/IO kernel additionally adopts SE-0458 strict memory safety: every unsafe construct must
// be explicitly `unsafe`-annotated, so any new unsafe use is compiler-flagged. Matches ADSQL's
// `ADDBCore` kernel. Applied to the targets that hold pointer / POSIX code (ADFCore, ADFIO).
let kernelSettings: [SwiftSetting] = strictSettings + [.strictMemorySafety()]

// Compile-time type-check timing warnings (flag slow expressions / function bodies). These use
// unsafe flags, which would block version-based dependency resolution if placed on a shipped
// library, so they live only on the internal (non-exported) test targets.
let timingWarningFlags: [SwiftSetting] = [
    .unsafeFlags([
        "-Xfrontend", "-warn-long-function-bodies=100",
        "-Xfrontend", "-warn-long-expression-type-checking=100",
    ])
]

// Tests: strict + timing warnings + runtime actor data-race checks.
let testSettings: [SwiftSetting] =
    strictSettings + timingWarningFlags + [.unsafeFlags(["-enable-actor-data-race-checks"])]

// Dev-only tooling is gated behind `ADF_DEV` so packages that depend on ADFoundation never resolve
// it. The `format` / `lint` command plugins carry no external dependencies, so they are always
// available without the flag; build-time lint enforcement (the `LintBuild` plugin) attaches to the
// libraries only in dev/CI.
let isDev = Context.environment["ADF_DEV"] != nil

var packageDependencies: [Package.Dependency] = []
if isDev {
    packageDependencies.append(
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0"))
}

// Build-time formatting enforcement attaches to the libraries only in dev/CI. A build-tool plugin on
// a library target would otherwise run for everyone who depends on ADFoundation, so it stays gated.
let libraryBuildPlugins: [Target.PluginUsage] = isDev ? ["LintBuild"] : []

let package = Package(
    name: "ADFoundation",
    // The shared deployment floor of every consumer (ADJSON / ADSQL / URLBuilder / apple-docs):
    // `Synchronization` (Mutex/Atomic) ships in macOS 15 / iOS 18 / tvOS 18 / watchOS 11 /
    // visionOS 2, and `Span`/`RawSpan` back-deploy further still. The 2025-SDK-gated
    // `InlineArray`/`UTF8Span` are deliberately NOT adopted, so this floor holds. (The Swift 6.3
    // tools-version is a *toolchain* requirement, not a deployment one.)
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2),
    ],
    products: [
        // Umbrella: re-exports the always-available core tiers for `import ADFoundation`.
        .library(name: "ADFoundation", targets: ["ADFoundation"]),
        // The zero-dependency byte / number / ASCII / UTF-8 / hash kernel. Foundation-free,
        // swift-syntax-free, no transitive package dependency — so the portable `ADJSONCore` and the
        // apple-docs zero-external-dep dylib can link it without poisoning their dependency graphs.
        .library(name: "ADFCore", targets: ["ADFCore"]),
        // Generic Unicode kernel (canonical decomposition / case-folding / property sets). Stdlib-only.
        .library(name: "ADFUnicode", targets: ["ADFUnicode"]),
        // Generic text algorithms (edit distance, tokenizer kernels). Stdlib-only.
        .library(name: "ADFText", targets: ["ADFText"]),
        // POSIX file channel + read-only memory mapping + cross-process atomics. Stdlib + libc only.
        .library(name: "ADFIO", targets: ["ADFIO"]),
    ],
    dependencies: packageDependencies,
    targets: [
        // ADFCore — pointer-level byte primitives; SE-0458 strict memory safety.
        .target(name: "ADFCore", swiftSettings: kernelSettings, plugins: libraryBuildPlugins),
        // ADFUnicode — generic Unicode kernel over ADFCore byte buffers.
        .target(
            name: "ADFUnicode", dependencies: ["ADFCore"], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        // ADFText — edit distance + tokenizer kernels.
        .target(
            name: "ADFText", dependencies: ["ADFCore", "ADFUnicode"], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),
        // ADFIO — POSIX storage primitives; SE-0458 strict memory safety.
        .target(name: "ADFIO", dependencies: ["ADFCore"], swiftSettings: kernelSettings, plugins: libraryBuildPlugins),
        // ADFoundation — umbrella re-export of the always-available core tiers.
        .target(
            name: "ADFoundation", dependencies: ["ADFCore", "ADFUnicode"], swiftSettings: strictSettings,
            plugins: libraryBuildPlugins),

        .testTarget(name: "ADFCoreTests", dependencies: ["ADFCore"], swiftSettings: testSettings),

        // Developer tooling. The command plugins are dependency-free (they drive the toolchain's
        // bundled `swift format`), so they impose nothing on packages that depend on ADFoundation.
        .plugin(
            name: "Format",
            capability: .command(
                intent: .custom(verb: "format", description: "Format Swift sources with swift-format"),
                permissions: [.writeToPackageDirectory(reason: "Format Swift sources with swift-format")])),
        .plugin(
            name: "Lint",
            capability: .command(
                intent: .custom(verb: "lint", description: "Check formatting and shipped-library discipline"))),
        .plugin(name: "LintBuild", capability: .buildTool()),
    ]
)
