import ADFCore
import ADFText
import Benchmark

// ADFoundation's benchmark suite on ordo-one's `Benchmark` framework, matching the sibling packages.
// Run with `ADF_DEV=1 swift package benchmark` (add `BENCHMARK_DISABLE_JEMALLOC=1` if jemalloc isn't
// installed; CI installs it for malloc metrics). Each adaptive primitive's variants sit side by side
// so their p-percentiles are directly comparable — this is what backs the dispatch thresholds
// (`ADFText.bandedMinRowWidth`, `UTF8Validation.simdMinBytes`).

private func nearStrings(_ n: Int, edits k: Int) -> (a: [UInt8], b: [UInt8]) {
    let a = (0..<n).map { UInt8(97 + ($0 % 5)) }
    var b = a
    let stride = Swift.max(1, n / Swift.max(k, 1))
    for e in 0..<k {
        let i = (e * stride) % n
        b[i] = b[i] == 122 ? 97 : b[i] &+ 1
    }
    return (a, b)
}

private func asciiBytes(_ n: Int) -> [UInt8] { [UInt8](repeating: UInt8(ascii: "a"), count: n) }

private func mixedBytes(_ n: Int) -> [UInt8] {
    var out: [UInt8] = []
    let unit = Array("aé本x".utf8)
    while out.count < n { out += unit }
    return out
}

nonisolated(unsafe) let benchmarks = {
    Benchmark.defaultConfiguration = .init(metrics: [.wallClock, .throughput])

    // MARK: edit distance — full vs banded vs adaptive at representative (length, bound) points.
    for (n, k) in [(32, 2), (64, 2), (128, 2), (256, 3)] {
        let (a, b) = nearStrings(n, edits: k)
        Benchmark("editDistance/full n\(n) k\(k)") { bm in
            for _ in bm.scaledIterations { blackHole(ADFText.editDistanceFull(a, b, maxDistance: k)) }
        }
        Benchmark("editDistance/banded n\(n) k\(k)") { bm in
            for _ in bm.scaledIterations { blackHole(ADFText.editDistanceBanded(a, b, maxDistance: k)) }
        }
        Benchmark("editDistance/adaptive n\(n) k\(k)") { bm in
            for _ in bm.scaledIterations { blackHole(ADFText.editDistance(a, b, maxDistance: k)) }
        }
    }

    // MARK: ByteBufferPool take/recycle throughput — the baseline for the zero-dependency, LIFO
    // Array backing. A swift-collections `Deque` is deliberately not adopted: the pool only appends
    // and pops the tail (both O(1) on Array), so a deque's O(1) head removal buys nothing here, and
    // ADFCore must stay dependency-free for the portable consumers. This guards the backing against
    // regressions.
    for size in [64, 4096] {
        let pool = ByteBufferPool()
        let payload = [UInt8](repeating: 0xAB, count: size)
        Benchmark("pool/take-recycle \(size)B") { bm in
            for _ in bm.scaledIterations {
                var b = pool.take()
                b.append(contentsOf: payload)
                blackHole(b.count)
                pool.recycle(b)
            }
        }
    }

    // MARK: UTF-8 validation — scalar vs adaptive(SIMD), ASCII vs multibyte-dense.
    for n in [256, 4096] {
        let ascii = asciiBytes(n)
        let mixed = mixedBytes(n)
        Benchmark("utf8/scalar ascii \(n)") { bm in
            for _ in bm.scaledIterations { blackHole(UTF8Validation.firstInvalidByteScalar(ascii) ?? -1) }
        }
        Benchmark("utf8/adaptive ascii \(n)") { bm in
            for _ in bm.scaledIterations { blackHole(UTF8Validation.firstInvalidByte(ascii) ?? -1) }
        }
        Benchmark("utf8/scalar mixed \(n)") { bm in
            for _ in bm.scaledIterations { blackHole(UTF8Validation.firstInvalidByteScalar(mixed) ?? -1) }
        }
        Benchmark("utf8/adaptive mixed \(n)") { bm in
            for _ in bm.scaledIterations { blackHole(UTF8Validation.firstInvalidByte(mixed) ?? -1) }
        }
    }
}
