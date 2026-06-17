// The umbrella `ADFoundation` module re-exports the always-available core tiers so a single
// `import ADFoundation` sees the byte/number kernel and the Unicode kernel as one flat public API.
// The heavier tiers (`ADFText`, `ADFIO`) are imported explicitly by the targets that need them, so
// this umbrella's link surface stays minimal and a consumer never pulls storage code it does not use.
@_exported import ADFCore
@_exported import ADFUnicode
