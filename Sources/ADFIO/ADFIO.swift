// ADFIO — POSIX storage primitives: a positioned file handle (``PosixFile``)
// with vectored writes and durability syncs, a read-only memory mapping
// (``RawFileMap``), and the cross-process C11 atomics re-exported below.
// Stdlib + platform libc only (Darwin / Glibc); no Foundation. Adopts SE-0458
// strict memory safety — every pointer / mmap construct is explicitly `unsafe`.
//
// The atomics shim is re-exported so `import ADFIO` surfaces
// `adf_atomic_load_acquire_u64` / `adf_atomic_store_release_u64` /
// `adf_atomic_cas_acq_rel_u64` alongside the Swift primitives.
@_exported import ADFAtomics
