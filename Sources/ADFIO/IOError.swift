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
        // `strerror_r` writes into a caller-owned buffer, so concurrent error
        // formatting cannot corrupt it (unlike `strerror`'s shared static buffer).
        // Swift surfaces the XSI/POSIX `strerror_r` (returns `Int`, always fills
        // the caller buffer) on both Darwin and the Linux/Glibc toolchain.
        let detail = unsafe withUnsafeTemporaryAllocation(of: CChar.self, capacity: 256) { buffer in
            _ = unsafe strerror_r(errno, buffer.baseAddress!, buffer.count)
            return unsafe String(cString: buffer.baseAddress!)
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
