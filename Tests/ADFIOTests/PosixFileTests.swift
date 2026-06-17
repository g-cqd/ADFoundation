import Testing

@testable import ADFIO

#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Unique scratch path under the system temp dir; the caller `unlink`s it.
private func makeTempPath() -> String {
    "/tmp/adfio-\(getpid())-\(UInt64.random(in: 0..<UInt64.max)).bin"
}

@Suite struct PosixFileTests {
    @Test func writeThenReadRoundtrips() throws {
        let path = makeTempPath()
        let file = try PosixFile(path: path, mode: .readWrite(create: true))
        defer {
            file.close()
            _ = path.withCString { unlink($0) }
        }
        let payload: [UInt8] = Array("the quick brown fox".utf8)
        try payload.withUnsafeBytes { try file.pwrite($0, at: 0) }

        #expect(try file.fileSize() == payload.count)

        var readback = [UInt8](repeating: 0, count: payload.count)
        try readback.withUnsafeMutableBytes { try file.pread(into: $0, at: 0) }
        #expect(readback == payload)
    }

    @Test func vectoredWriteConcatenatesInOrder() throws {
        let path = makeTempPath()
        let file = try PosixFile(path: path, mode: .readWrite(create: true))
        defer {
            file.close()
            _ = path.withCString { unlink($0) }
        }
        let a: [UInt8] = [1, 2, 3]
        let b: [UInt8] = [4, 5]
        let c: [UInt8] = [6, 7, 8, 9]
        try a.withUnsafeBytes { pa in
            try b.withUnsafeBytes { pb in
                try c.withUnsafeBytes { pc in
                    try file.pwritev([pa, pb, pc], at: 0)
                }
            }
        }
        var readback = [UInt8](repeating: 0, count: 9)
        try readback.withUnsafeMutableBytes { try file.pread(into: $0, at: 0) }
        #expect(readback == [1, 2, 3, 4, 5, 6, 7, 8, 9])
    }

    @Test func preallocateGrowsAndTruncateShrinks() throws {
        let path = makeTempPath()
        let file = try PosixFile(path: path, mode: .readWrite(create: true))
        defer {
            file.close()
            _ = path.withCString { unlink($0) }
        }
        try file.preallocate(minimumSize: 8192)
        #expect(try file.fileSize() == 8192)
        try file.truncate(to: 100)
        #expect(try file.fileSize() == 100)
    }

    @Test func badPathThrowsIOErrorWithErrno() {
        #expect(throws: IOError.self) {
            _ = try PosixFile(path: "/nonexistent-dir-xyz/file.bin", mode: .readOnly)
        }
    }
}

@Suite struct RawFileMapTests {
    @Test func mappedRegionReflectsFileBytes() throws {
        let path = makeTempPath()
        let file = try PosixFile(path: path, mode: .readWrite(create: true))
        defer {
            file.close()
            _ = path.withCString { unlink($0) }
        }
        let payload = [UInt8](0..<64)
        try payload.withUnsafeBytes { try file.pwrite($0, at: 0) }
        try file.sync(.barrier)

        let map = try RawFileMap(fileDescriptor: file.fileDescriptor, capacity: 64)
        map.prefetch(offset: 0, length: 64)
        let region = map.region(offset: 0, count: 64)
        #expect(Array(region) == payload)
        #expect(map.capacity == 64)
    }
}

@Suite struct AtomicsTests {
    /// Exercises the re-exported C11 atomics over local (aligned) `UInt64` storage.
    @Test func compareExchangeHasReleaseAcquireSemantics() {
        withUnsafeTemporaryAllocation(of: UInt64.self, capacity: 1) { buffer in
            let p = buffer.baseAddress!
            adf_atomic_store_release_u64(p, 0)
            #expect(adf_atomic_load_acquire_u64(p) == 0)

            #expect(adf_atomic_cas_acq_rel_u64(p, 0, 5))  // 0 → 5 succeeds
            #expect(adf_atomic_load_acquire_u64(p) == 5)

            #expect(!adf_atomic_cas_acq_rel_u64(p, 0, 9))  // expected 0, holds 5 → fails
            #expect(adf_atomic_load_acquire_u64(p) == 5)
        }
    }
}
