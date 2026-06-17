# ``ADFIO``

POSIX storage primitives: buffered file channel, read-only memory mapping, cross-process atomics.

## Overview

`ADFIO` holds the platform storage layer extracted from the database engine — positioned and
vectored I/O with durability profiles (`F_BARRIERFSYNC` / `F_FULLFSYNC` / `fdatasync`), read-only
`mmap` views, and C11 cross-process atomics for the shared-memory reader registry. Stdlib + libc
only; no Foundation, no external package.
