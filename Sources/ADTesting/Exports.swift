// The umbrella `ADTesting` module re-exports the family's deterministic-testing kit, so a test target
// writes a single `import ADTesting` instead of `import ADTestKit` + `import ADTestKitSeams`. The
// production seams (`TaskProvider`/`Clock`/`ResourcePool`) come transitively via `ADTestKitSeams`'s own
// `@_exported import ADConcurrency`. This is the test-side mirror of the runtime `import ADFoundation`
// umbrella — both vended by this one package, so a consumer links ADFoundation once and gets both
// entry points (the test umbrella only enters a *test* target's graph).
@_exported import ADTestKit
@_exported import ADTestKitSeams
