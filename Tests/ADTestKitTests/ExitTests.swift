import Foundation
import Testing

@testable import ADTestKit

/// Exit tests for the genuine trap paths the kit exposes: a `precondition` it owns,
/// and the constrained-stack runner's whole purpose — surfacing a stack overflow as a
/// process abort rather than a silent pass.
struct ExitTests {
    @Test
    func `uniform(0) trips its precondition`() async {
        await #expect(processExitsWith: .failure) {
            var rng = SeededRNG(seed: 1)
            _ = rng.uniform(0)
        }
    }

    @Test
    func `a planted unbounded recursion overflows the constrained stack`() async {
        await #expect(processExitsWith: .failure) {
            // `limit` is read from the environment (never set in practice → .max), so the
            // compiler cannot prove the base case is unreachable and won't raise its
            // infinite-recursion diagnostic — yet at runtime the call recurses far enough
            // to overflow the 256 KiB stack (SIGBUS), which is exactly what this asserts.
            let limit =
                ProcessInfo.processInfo.environment["ADTESTKIT_RECURSION_LIMIT"]
                .flatMap(Int.init) ?? .max
            @Sendable func deepen(_ depth: Int) -> Int {
                if depth >= limit { return depth }
                let pad = [depth, depth &+ 1]
                return deepen(depth &+ 1) &+ pad[0]
            }
            runOnConstrainedStack(stackSize: 256 * 1024) {
                _ = deepen(0)
            }
        }
    }
}
