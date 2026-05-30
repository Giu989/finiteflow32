# FiniteFlow32 Arithmetic Audit

This audit records the source-level assumptions that had to be addressed before
using small primes. The current FiniteFlow32 table is below `2^31` for msolve
compatibility, while the arithmetic branch remains valid for primes below
`2^32`. The upstream arithmetic is optimized for primes near `2^63` satisfying:

```text
2*p < 2^64 < 3*p
```

FiniteFlow32 keeps `UInt` / `FFUInt` storage as `uint64_t`, but can now build
with an msolve-compatible prime table below `2^31` by enabling
`FFLOW_USE_UINT32_PRIMES`.

## Prime Tables

- [include/fflow/primes.hh](../include/fflow/primes.hh)
  - Upstream behavior: `BIG_UINT_PRIMES` is the 2048-prime table near `2^63`.
  - FiniteFlow32 mode: `BIG_UINT_PRIMES` aliases a 400-prime table below
    `2^31`.
  - Strategy: build-time option `FFLOW_USE_UINT32_PRIMES`; existing
    `prime_no` APIs continue to index `BIG_UINT_PRIMES`.

- [include/fflow/primes32.hh](../include/fflow/primes32.hh)
  - New explicit 32-bit prime-table declaration.
  - Table size: 400.

- [src/ff_prime32_list.hh](../src/ff_prime32_list.hh)
  - Generated table of the 400 largest primes below `2^31`.
  - Regenerate with [scripts/generate_primes32.py](../scripts/generate_primes32.py).

## Modular Arithmetic Helpers

- [include/fflow/ffmod.h](../include/fflow/ffmod.h)
  - `ffPrecomputedReciprocalMod`
    - Upstream dependency: precomputes a reciprocal of `2*p` and assumes
      `2*p >= 2^63`.
    - 32-bit strategy: store the modulus and skip reciprocal use.
  - `ffDiv2Mod1`, `ffDiv2By1`
    - Upstream dependency: invariant division after doubling the divisor and
      dividend.
    - 32-bit strategy: use ordinary `__int128` division / remainder.
  - `ffMulMod`
    - Upstream dependency: calls `ffDiv2Mod1` after a 128-bit product.
    - 32-bit strategy: reduce operands modulo `p`, multiply in 128-bit, then
      `% p`.
  - `ffAddMod`, `ffSubMod`
    - Upstream dependency: operands are residues and `p` is near `2^63`.
    - 32-bit strategy: reduce operands first, which also handles constants
      such as the reconstruction sampling stride that are larger than `p`.
  - `ffAPBCMod`
    - Upstream dependency: computes `a + b*c` then uses the near-63-bit
      reduction.
    - 32-bit strategy: reduce operands and compute `(a + b*c) % p` safely.
  - `ffPrecomputedMulShoup`, `ffMulShoup`
    - Upstream dependency: Shoup precomputation relies on valid large-modulus
      division.
    - 32-bit strategy: keep the API, but make `ffMulShoup` fall back to
      `ffMulMod` in small-prime mode.

- [include/fflow/common.hh](../include/fflow/common.hh)
  - `beta_mod`
    - Upstream dependency: `2^64 mod p == -(2*p)` only under
      `2*p < 2^64 < 3*p`.
    - 32-bit strategy: compute `2^64 % p` directly in `__int128`.
  - `red_mod`
    - Upstream dependency: bounded reduction valid for values below `3*p`.
    - 32-bit strategy: ordinary `% p`, required for arbitrary 64-bit values
      and sampling hashes.
  - `add_mod`, `sub_mod`, `mul_mod`, `apbc_mod`, `ambc_mod`,
    `precomp_mul_shoup`, `mul_mod_shoup`
    - Strategy: wrappers call the patched low-level `ffmod.h` helpers.
  - `twice_mod`, `neg_mod`
    - Safe for residues in both modes after low-level helper patches.

- [src/ffmod.c](../src/ffmod.c)
  - `ffMulInverseMod`
    - Upstream FLINT path is safe for 32-bit primes.
    - Fallback path now uses signed `__int128` temporaries to avoid signed
      overflow in extended Euclid.
  - `ffDivMod`
    - Safe after `ffMulMod` and inverse handling.

## Reconstruction Assumptions

- [include/fflow/univariate_reconstruction.hh](../include/fflow/univariate_reconstruction.hh)
  - `SAMPLING_STRIDE = 12345678901` is smaller than 63-bit primes but larger
    than 32-bit primes.
  - Strategy: patched `add_mod` handles large constants in 32-bit mode.

- [include/fflow/function_cache.hh](../include/fflow/function_cache.hh)
  - `sample_uint` reduces 64-bit hashes through `red_mod`.
  - Strategy: patched `red_mod` makes hash sampling safe for `p < 2^32`.

- [src/mp_multivariate_reconstruction.cc](../src/mp_multivariate_reconstruction.cc)
  - Uses `BIG_UINT_PRIMES[(start_mod + i) % BIG_UINT_PRIMES_SIZE]` for CRT
    reconstruction.
  - Strategy: active table switches to 32-bit primes at build time. More
    primes may be needed because each prime contributes roughly 31 CRT bits
    instead of 63.

- [src/alg_mp_reconstruction.cc](../src/alg_mp_reconstruction.cc)
  - Numeric reconstruction merges residues through CRT and rational
    reconstruction.
  - Strategy: no algorithmic rewrite yet; uses the active table and benefits
    from the patched arithmetic and increased `MaxPrimes` availability.

- [src/graph.cc](../src/graph.cc), [src/capi.cc](../src/capi.cc),
  [mathlink/fflowmlink.cc](../mathlink/fflowmlink.cc)
  - `prime_no`, `start_mod`, `min_primes`, and `max_primes` index
    `BIG_UINT_PRIMES`.
  - Strategy: preserve API shape; in `FFLOW_USE_UINT32_PRIMES` builds those
    indices address the 400-prime 32-bit table.

## Tests Added

- [tests/testfiniteflow32_arithmetic.cc](../tests/testfiniteflow32_arithmetic.cc)
  - Verifies the active table is the msolve-compatible 32-bit table.
  - Checks all table entries are prime, below `2^31`, and strictly descending.
  - Randomized and edge-case checks for reduction, addition, subtraction,
    negation, multiplication, Shoup multiplication fallback, fused
    `a + b*c`, fused `a - b*c`, inverse, and division.

- [tests/mathematica/multiprime_reconstruction.m](../tests/mathematica/multiprime_reconstruction.m)
  - Verifies Mathematica sees the 400-prime table below `2^31`.
  - Confirms reconstruction with too few 32-bit primes does not succeed.
  - Reconstructs large-coefficient rational functions with many primes and
    checks the exact result.

## Remaining Watch Points

- `MPolyReconstruction::getXi` returns `x0 + i` without explicit reduction.
  Existing degree ranges are far below `2^31`, and sampled `x0` almost never
  falls within that small tail window. The current tests pass, but this is a
  useful place to revisit if very high degree reconstruction is pushed near the
  field size.
- 32-bit mode is correctness-first. The `% p` branches are intentionally simple
  and can be optimized later after broader reconstruction coverage is stable.
