import ADFText
import Testing

/// Deterministic generator so the randomized cross-checks are reproducible.
private struct LCG {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state >> 16
    }
    mutating func int(_ upperBound: Int) -> Int { Int(next() % UInt64(upperBound)) }
}

@Suite("ADFText.editDistance")
struct EditDistanceTests {
    private func dist(_ a: String, _ b: String, max: Int = .max) -> Int {
        ADFText.editDistance(Array(a.utf8), Array(b.utf8), maxDistance: max)
    }

    @Test func exactDistances() {
        #expect(dist("", "") == 0)
        #expect(dist("abc", "abc") == 0)
        #expect(dist("", "abc") == 3)
        #expect(dist("abc", "") == 3)
        #expect(dist("kitten", "sitting") == 3)
        #expect(dist("flaw", "lawn") == 2)
        #expect(dist("a", "b") == 1)
    }

    @Test func earlyExitReturnsMaxPlusOneWhenExceeded() {
        #expect(dist("a", "abcdef", max: 2) == 3)
        #expect(dist("kitten", "sitting", max: 3) == 3)
        #expect(dist("abcd", "wxyz", max: 2) == 3)
    }

    @Test func worksOverArbitraryEquatableElements() {
        #expect(ADFText.editDistance([1, 2, 3], [1, 2, 3]) == 0)
        #expect(ADFText.editDistance([1, 2, 3], [1, 4, 3]) == 1)
        #expect(ADFText.editDistance(Array("café".utf16), Array("cafe".utf16)) == 1)
    }

    /// Exhaustive: every pair of strings of length ≤ 3 over {a,b,c}, every bound 0…4. Banded and the
    /// adaptive dispatcher must equal the full (exact) distance clamped to the bound.
    @Test func bandedMatchesFullExhaustively() {
        let alphabet: [UInt8] = [97, 98, 99]
        var corpus: [[UInt8]] = [[]]
        var frontier: [[UInt8]] = [[]]
        for _ in 0..<3 {
            var next: [[UInt8]] = []
            for s in frontier { for c in alphabet { next.append(s + [c]) } }
            corpus += next
            frontier = next
        }
        var failures: [String] = []
        for a in corpus {
            for b in corpus {
                let full = ADFText.editDistanceFull(a, b)
                for k in 0...4 {
                    let expected = full <= k ? full : k + 1
                    let banded = ADFText.editDistanceBanded(a, b, maxDistance: k)
                    if banded != expected {
                        failures.append("banded(\(a),\(b),k=\(k))=\(banded) != \(expected) full=\(full)")
                    }
                    let adaptive = ADFText.editDistance(a, b, maxDistance: k)
                    if adaptive != expected { failures.append("adaptive(\(a),\(b),k=\(k))=\(adaptive) != \(expected)") }
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.prefix(8))")
    }

    /// Long inputs (rows past the banded dispatch threshold), so the adaptive path actually selects
    /// the banded matrix; checked against the full matrix for several bounds.
    @Test func bandedMatchesFullOnLongInputs() {
        var rng = LCG(seed: 0x9E37_79B9_7F4A_7C15)
        var failures = 0
        for _ in 0..<400 {
            let length = 16 + rng.int(96)  // 16…111, straddles the bandedMinRowWidth threshold
            let a = (0..<length).map { _ in UInt8(97 + rng.int(5)) }
            var b = a
            for _ in 0..<rng.int(10) where !b.isEmpty { b[rng.int(b.count)] = UInt8(97 + rng.int(5)) }
            for k in [0, 1, 2, 3, 5, 10, 50] {
                let full = ADFText.editDistanceFull(a, b)
                let expected = full <= k ? full : k + 1
                if ADFText.editDistanceBanded(a, b, maxDistance: k) != expected { failures += 1 }
                if ADFText.editDistance(a, b, maxDistance: k) != expected { failures += 1 }
            }
        }
        #expect(failures == 0)
    }

    /// The pure functions are safe to fan out concurrently (no shared state).
    @Test func concurrentCallsAgree() async {
        let pairs: [(String, String)] = [
            ("kitten", "sitting"), ("flaw", "lawn"), ("foundation", "fundamentals"), ("", "abc"),
        ]
        let serial = pairs.map { dist($0.0, $0.1) }
        let parallel = await withTaskGroup(of: (Int, Int).self) { group in
            for (i, p) in pairs.enumerated() {
                group.addTask { (i, ADFText.editDistance(Array(p.0.utf8), Array(p.1.utf8))) }
            }
            var out = [Int](repeating: -1, count: pairs.count)
            for await (i, d) in group { out[i] = d }
            return out
        }
        #expect(serial == parallel)
    }
}
