# ``ADFoundation``

Shared, modular foundations for the g-cqd engines — ADJSON, ADSQL, URLBuilder, and apple-docs.

## Overview

ADFoundation is the dependency root beneath the g-cqd engines. It holds only **domain-neutral**
primitives, split into tiers by dependency footprint so each consumer links exactly what it needs:

- ``ADFCore`` — byte buffers and readers, varint and little/big-endian codecs, overflow-checked
  arithmetic, ASCII classification, RFC 3629 UTF-8 validation, percent-coding, non-cryptographic
  hashing. Zero transitive dependencies.
- ``ADFUnicode`` — canonical decomposition, case-folding, and Unicode property sets.
- ``ADFText`` — bounded edit distance and tokenizer kernels.
- ``ADFIO`` — POSIX file channel, memory mapping, and cross-process atomics.

`import ADFoundation` re-exports ``ADFCore`` and ``ADFUnicode``. Import ``ADFText`` or ``ADFIO``
directly when you need them. Everything floors at macOS 15 / iOS 18 / tvOS 18 / watchOS 11 /
visionOS 2 and is Foundation-free.

## Topics

### Tiers

- ``ADFCore``
- ``ADFUnicode``
- ``ADFText``
- ``ADFIO``
