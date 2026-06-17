/// Namespace for POSIX storage primitives: a buffered file channel (positioned reads/writes,
/// vectored writes, durability profiles), read-only memory mapping, and cross-process atomics over
/// shared memory. Stdlib + platform libc only (Darwin / Glibc); no Foundation. Adopts SE-0458 strict
/// memory safety — every pointer/mmap construct is explicitly `unsafe`.
public enum ADFIO {}
