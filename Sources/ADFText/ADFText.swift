/// Generic text algorithms. Reference-neutral and stdlib-only: the caller chooses the element
/// granularity (UTF-16 code units, Unicode scalars, bytes, characters), so domain-specific parity
/// (e.g. JS string indexing) lives at the call site, not here.
///
/// All members are pure free functions over value types with no shared mutable state, so they are
/// inherently `Sendable`-safe and `nonisolated`: call them from any actor or thread, and fan a batch
/// out across a `TaskGroup` / `concurrentPerform` freely. (Parallelizing very small inputs can lose
/// to scheduling overhead — measure the batch before fanning out.)
public enum ADFText {
    /// Levenshtein edit distance with an early exit — adaptive over input size and the distance bound.
    ///
    /// Returns the exact distance (the minimum single-element insertions, deletions, and
    /// substitutions to turn `a` into `b`) when it is `≤ maxDistance`, otherwise `maxDistance + 1`
    /// (saturating). With the default `maxDistance` the exact distance is always returned.
    ///
    /// Dispatch: when the bound is tight relative to the inputs (`2·maxDistance + 1 < b.count`) the
    /// O(`a.count`·`maxDistance`) **banded** matrix is used; otherwise the O(`a.count`·`b.count`)
    /// **full** matrix (which also serves the unbounded case). Both honor the same early-exit contract.
    public static func editDistance<Element: Equatable>(
        _ a: [Element], _ b: [Element], maxDistance: Int = .max
    ) -> Int {
        let m = a.count
        let n = b.count
        if abs(m - n) > maxDistance { return maxDistance + 1 }
        if m == 0 { return n <= maxDistance ? n : maxDistance + 1 }
        if n == 0 { return m <= maxDistance ? m : maxDistance + 1 }
        // Banded only when the band (width 2·k+1) is strictly narrower than the row, and the row is
        // long enough that skipping out-of-band cells outweighs the band's boundary bookkeeping. The
        // size threshold is set from the benchmark crossover (see Benchmarks/ADFoundationSuite).
        if maxDistance < (n - 1) / 2, n >= bandedMinRowWidth {
            return editDistanceBanded(a, b, maxDistance: maxDistance)
        }
        return editDistanceFull(a, b, maxDistance: maxDistance)
    }

    /// Row width below which the full matrix is used even for a tight bound (banded bookkeeping does
    /// not pay on tiny rows). Benchmarked crossover: banded already wins ~2× at width 16 and far more
    /// above it, so 16 is the floor (below it the absolute cost is negligible either way).
    @usableFromInline static let bandedMinRowWidth = 16

    /// Full two-row Levenshtein matrix with the early-exit bound. Exact when `maxDistance == .max`.
    public static func editDistanceFull<Element: Equatable>(
        _ a: [Element], _ b: [Element], maxDistance: Int = .max
    ) -> Int {
        let m = a.count
        let n = b.count
        if abs(m - n) > maxDistance { return maxDistance + 1 }
        if m == 0 { return n <= maxDistance ? n : maxDistance + 1 }
        if n == 0 { return m <= maxDistance ? m : maxDistance + 1 }

        var previous = Array(0...n)
        var current = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            current[0] = i
            var rowMin = i
            let ai = a[i - 1]
            for j in 1...n {
                current[j] =
                    ai == b[j - 1]
                    ? previous[j - 1]
                    : 1 + Swift.min(previous[j], current[j - 1], previous[j - 1])
                if current[j] < rowMin { rowMin = current[j] }
            }
            if rowMin > maxDistance { return maxDistance + 1 }
            swap(&previous, &current)
        }
        // Saturate at `maxDistance + 1`: the row-minimum early-exit can miss a final distance that
        // only exceeds the bound on the last column, so clamp for a well-defined bounded contract
        // (matching the banded path). When `maxDistance == .max` the comparison is never true.
        let distance = previous[n]
        return distance > maxDistance ? maxDistance + 1 : distance
    }

    /// Banded Levenshtein: only the diagonal band `|i − j| ≤ maxDistance` is evaluated (cells outside
    /// it can only hold distances `> maxDistance`). O(`a.count`·`maxDistance`). Returns the exact
    /// distance when it is `≤ maxDistance`, else `maxDistance + 1`.
    public static func editDistanceBanded<Element: Equatable>(
        _ a: [Element], _ b: [Element], maxDistance k: Int
    ) -> Int {
        let m = a.count
        let n = b.count
        if abs(m - n) > k { return k + 1 }
        if m == 0 { return n <= k ? n : k + 1 }
        if n == 0 { return m <= k ? m : k + 1 }

        // `inf` is one past the bound: any path through it is already over budget. Cells outside the
        // current/previous band are held at `inf` so reads from them propagate "unreachable".
        let inf = k + 1
        var previous = [Int](repeating: inf, count: n + 1)
        var current = [Int](repeating: inf, count: n + 1)
        for j in 0...Swift.min(k, n) { previous[j] = j }

        for i in 1...m {
            let lo = Swift.max(0, i - k)
            let hi = Swift.min(n, i + k)
            if lo > 0 { current[lo - 1] = inf }  // left boundary read by current[j-1] at j == lo
            var rowMin = inf
            for j in lo...hi {
                let value: Int
                if j == 0 {
                    value = i  // reached only while i ≤ k (lo == 0)
                } else {
                    let cost = a[i - 1] == b[j - 1] ? 0 : 1
                    value = Swift.min(previous[j] + 1, current[j - 1] + 1, previous[j - 1] + cost)
                }
                current[j] = value
                if value < rowMin { rowMin = value }
            }
            if hi < n { current[hi + 1] = inf }  // right boundary read by previous[j] next row
            if rowMin > k { return k + 1 }
            swap(&previous, &current)
        }
        let distance = previous[n]
        return distance > k ? k + 1 : distance
    }
}
