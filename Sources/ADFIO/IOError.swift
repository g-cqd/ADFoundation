#if canImport(Darwin)
    import Darwin
#elseif canImport(Glibc)
    import Glibc
#endif

/// A failed POSIX operation, carrying the captured `errno` and a short label for
/// the syscall that produced it. Domain-neutral: a consumer that needs a richer
/// error taxonomy (e.g. a database error enum) maps this at its own boundary,
/// preserving `errno` and `op` verbatim.
public struct IOError: Error, Equatable, Sendable {
    /// The C `errno` captured at the failure site.
    public let errno: Int32
    /// A short label for the operation that failed (e.g. `"pread"`, `"mmap"`).
    public let op: String

    public init(errno: Int32, op: String) {
        self.errno = errno
        self.op = op
    }
}

extension IOError: CustomStringConvertible {
    public var description: String {
        // Format `errno` into a caller-owned buffer so concurrent formatting can't corrupt a shared
        // static buffer (as plain `strerror` would). Darwin and Glibc expose different `strerror_r`
        // contracts, handled explicitly below; the buffer is zero-initialized first so no branch can
        // ever read uninitialized stack memory.
        let detail = withUnsafeTemporaryAllocation(of: CChar.self, capacity: 256) { buffer in
            guard let base = buffer.baseAddress else { return "errno \(errno)" }
            unsafe base.initialize(repeating: 0, count: buffer.count)
            #if canImport(Darwin)
                // XSI `strerror_r`: returns 0 on success and fills the buffer. On failure don't trust
                // a partially written buffer — surface the bare errno instead.
                guard unsafe strerror_r(errno, base, buffer.count) == 0 else { return "errno \(errno)" }
                return unsafe String(cString: base)
            #else
                // GNU `strerror_r` (the Glibc default): returns a `char *` that may point at a static
                // string rather than the supplied buffer, so the *return value* is the message.
                return unsafe String(cString: strerror_r(errno, base, buffer.count))
            #endif
        }
        return "I/O error in \(op): \(detail) (errno \(errno))"
    }
}

/// Builds an ``IOError`` capturing the current global `errno`. Use it at the
/// `throw` site immediately after a failing syscall, before any other call can
/// overwrite `errno`.
func ioErrno(_ op: String) -> IOError {
    IOError(errno: errno, op: op)
}
