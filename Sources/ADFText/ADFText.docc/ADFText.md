# ``ADFText``

Generic text algorithms: bounded edit distance and tokenizer kernels.

## Overview

`ADFText` holds the domain-neutral text algorithms that were duplicated between fuzzy search and
full-text indexing — early-exit Levenshtein edit distance and the substring/window tokenizer
kernels. Stdlib-only, iterative, Foundation-free. The tokenizer kernels return index ranges rather
than copied subsequences, so the caller picks the element granularity and slices on demand.

## Topics

### Bounded edit distance

- ``ADFText/editDistance(_:_:maxDistance:)``
- ``ADFText/editDistanceFull(_:_:maxDistance:)``
- ``ADFText/editDistanceBanded(_:_:maxDistance:)``

### Tokenizer kernels

- ``ADFText/windows(_:size:)``
- ``ADFText/split(_:omittingEmptySubsequences:where:)``
