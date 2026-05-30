#!/usr/bin/env python3
"""Generate the FiniteFlow32 msolve-compatible prime table."""

from __future__ import annotations

import argparse
from pathlib import Path


DEFAULT_COUNT = 400
LIMIT = 2**31


def is_prime_u32(n: int) -> bool:
    if n < 2:
        return False
    small_primes = (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37)
    for p in small_primes:
        if n % p == 0:
            return n == p

    d = n - 1
    s = 0
    while d % 2 == 0:
        s += 1
        d //= 2

    # Deterministic for 32-bit integers.
    for a in (2, 3, 5, 7):
        if a >= n:
            continue
        x = pow(a, d, n)
        if x == 1 or x == n - 1:
            continue
        for _ in range(s - 1):
            x = (x * x) % n
            if x == n - 1:
                break
        else:
            return False

    return True


def largest_primes_below_limit(count: int) -> list[int]:
    primes: list[int] = []
    n = LIMIT - 1
    while len(primes) < count:
        if is_prime_u32(n):
            primes.append(n)
        n -= 2
    return primes


def render(primes: list[int]) -> str:
    return "".join(f"{p}ULL,\n" for p in primes)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    primes = largest_primes_below_limit(args.count)
    text = render(primes)

    if args.output:
        args.output.write_text(text)
    else:
        print(text, end="")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
