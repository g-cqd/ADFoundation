#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// Read-only shared memory mapping of a file.
///
/// `capacity` bytes of virtual address space are reserved once at open. Virtual
/// reservation is free and there is no `mremap` on Darwin, so a caller may map
/// more than the current file length and let the file grow underneath the
/// mapping (pages become valid as the file is extended; no remap needed).
///
/// **Caller contract.** The mapping hands out *borrowed* views (``region(offset:count:)``)
/// into foreign memory. The caller must (1) only read bytes that are backed by
/// the file — touching a page past the file's current end faults — and (2) keep
/// the backing file from shrinking below any range it still reads, since a
/// mapped region over truncated-away bytes is undefined. The read access policy
/// is `MADV_RANDOM`; ``prefetch(offset:length:)`` schedules a localized readahead
/// without changing that global policy.
@safe public final class RawFileMap: @unchecked Sendable {
    /// The naked mapping pointer is private: callers get only the bounded
    /// `region` views, so the unsafe pointer never leaves this type.
    private let base: UnsafeRawPointer
    /// Reserved length of the mapping in bytes.
    public let capacity: Int

    public init(fileDescriptor: Int32, capacity: Int) throws(IOError) {
        // `mmap` rejects a zero length with EINVAL; surface it as a clear precondition failure.
        guard capacity > 0 else { throw IOError(errno: EINVAL, op: "mmap(capacity: \(capacity))") }
        let ptr = unsafe mmap(nil, capacity, PROT_READ, MAP_SHARED, fileDescriptor, 0)
        guard let ptr = unsafe ptr, unsafe ptr != MAP_FAILED else { throw ioErrno("mmap(\(capacity))") }
        unsafe self.base = UnsafeRawPointer(ptr)
        self.capacity = capacity
        // Random-access workloads (e.g. tree descent) shouldn't let read-ahead
        // pollute the cache.
        _ = unsafe madvise(UnsafeMutableRawPointer(mutating: ptr), capacity, MADV_RANDOM)
    }

    deinit {
        _ = unsafe munmap(UnsafeMutableRawPointer(mutating: base), capacity)
    }

    /// Borrowed view of `count` bytes at `offset`. Not bounds-checked: the caller
    /// guarantees `offset + count` lies within the file's committed length (see
    /// the type's caller contract).
    @inline(__always)
    public func region(offset: Int, count: Int) -> UnsafeRawBufferPointer {
        // Debug-only guard against gross misuse (negative or past-capacity ranges); compiled out of
        // release builds, so the documented "not bounds-checked" hot path is unchanged. It cannot see
        // the file's committed length, so the file-shrink contract still rests with the caller.
        assert(
            offset >= 0 && count >= 0 && count <= capacity && offset <= capacity - count,
            "RawFileMap.region(offset: \(offset), count: \(count)) escapes the \(capacity)-byte mapping")
        return unsafe UnsafeRawBufferPointer(start: base + offset, count: count)
    }

    /// Advisory readahead for `length` bytes starting at `offset`. `MADV_WILLNEED`
    /// only schedules a prefetch for the named range — unlike `MADV_SEQUENTIAL` it
    /// does not change the mapping's global policy, so a scan can prefetch ahead
    /// without disturbing concurrent random-access readers. The range is clamped to
    /// the reserved capacity; a tail beyond the committed file is harmless (those
    /// pages simply are not resident and never get touched in correct use).
    @inline(__always)
    public func prefetch(offset: Int, length: Int) {
        guard offset < capacity, length > 0 else { return }
        let clamped = min(length, capacity - offset)
        _ = unsafe madvise(UnsafeMutableRawPointer(mutating: base + offset), clamped, MADV_WILLNEED)
    }
}
