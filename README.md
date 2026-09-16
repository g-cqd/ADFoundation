# ADFoundation compatibility package

The implementation lives in [Aemi](https://github.com/Aemi-Studio/aemi).
This package preserves legacy products and imports through the published Aemi `main`
branch. New packages should depend on Aemi directly.

| Legacy product | Aemi product |
| --- | --- |
| `ADFCore` | `AemiKernel` |
| `ADFKernels` | `AemiKernels` |
| `ADFUnicode` | `AemiUnicode` |
| `ADFText` | `AemiText` |
| `ADFIO` | `AemiIO` |
| `ADFMetrics` | `AemiMetrics` |
| `ADConcurrency` | `AemiRuntime` |
| `ADFMacroSupport` | `AemiMacroSupport` |
| `ADTestKit` | `AemiTestKit` |
| `ADTestKitSeams` | `AemiTestKitSeams` |
| `ADFoundation` | `AemiFoundation` |
| `ADTesting` | `AemiTestKit` |

The wrappers share types and runtime state with Aemi. They contain no duplicate
kernel, IO, concurrency, or test-support implementation. Use the shared
`AemiKernels` and `AemiText` namespaces in calls, even when keeping the legacy
imports. Use Foundation's `QualityOfService` for blocking-pool scheduling.
The wrappers do not add aliases for renamed types.

## Requirements

Swift 6.4. iOS 18, macOS 15, tvOS 18, watchOS 11, or visionOS 2.

## Verification

`swift test` runs the existing behavioral suites against the shared implementation.
`ADF_DEV=1` enables remote benchmark tooling; `ADF_FUZZ=1`
enables the Linux kernel fuzz harness. Implementation documentation lives in Aemi.

## License

[MIT](LICENSE).
