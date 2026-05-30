#include <fflow/config.hh>
#include <fflow/common.hh>
#include <fflow/gcd.hh>
#include <fflow/primes.hh>
#include <fflow/primes32.hh>

#include <algorithm>
#include <cstdint>
#include <iostream>
#include <random>
#include <vector>

using namespace fflow;

namespace {

UInt ref_mod(UInt a, UInt p)
{
  return a % p;
}

UInt ref_add(UInt a, UInt b, UInt p)
{
  return UInt(((FFU128)(a % p) + (b % p)) % p);
}

UInt ref_sub(UInt a, UInt b, UInt p)
{
  UInt ar = a % p;
  UInt br = b % p;
  return ar >= br ? ar - br : ar + p - br;
}

UInt ref_mul(UInt a, UInt b, UInt p)
{
  return UInt(((FFU128)(a % p) * (b % p)) % p);
}

UInt ref_apbc(UInt a, UInt b, UInt c, UInt p)
{
  return ref_add(a, ref_mul(b, c, p), p);
}

UInt ref_ambc(UInt a, UInt b, UInt c, UInt p)
{
  return ref_sub(a, ref_mul(b, c, p), p);
}

bool is_prime_u32(UInt n)
{
  if (n < 2)
    return false;
  if (n % 2 == 0)
    return n == 2;
  for (UInt d = 3; d*d <= n; d += 2)
    if (n % d == 0)
      return false;
  return true;
}

void require(bool ok, const char * what, UInt p, UInt a = 0,
             UInt b = 0, UInt c = 0)
{
  if (!ok) {
    std::cerr << "finiteflow32 arithmetic check failed: " << what
              << " p=" << p << " a=" << a << " b=" << b
              << " c=" << c << "\n";
    std::exit(1);
  }
}

void test_prime(UInt p)
{
  Mod mod(p);

  require(p < (UInt(1) << 31), "active prime is not msolve-compatible", p);
  require(is_prime_u32(p), "active prime is not prime", p);
  require(beta_mod(p) == UInt((FFU128(1) << 64) % p), "beta_mod", p);

  std::vector<UInt> values = {
    0, 1, 2, 3, p - 3, p - 2, p - 1, p, p + 1, 2*p - 1, 2*p,
    0xffffffffULL, 0x100000000ULL, 12345678901ULL, ~UInt(0)
  };

  std::mt19937_64 gen(0x5f17f10f32ULL ^ p);
  for (unsigned i = 0; i < 64; ++i)
    values.push_back(gen());

  for (UInt a : values)
    require(red_mod(a, mod) == ref_mod(a, p), "red_mod", p, a);

  std::vector<UInt> residues;
  for (UInt a : values)
    residues.push_back(a % p);
  std::sort(residues.begin(), residues.end());
  residues.erase(std::unique(residues.begin(), residues.end()), residues.end());

  for (UInt a : residues) {
    require(neg_mod(a, mod) == ref_sub(0, a, p), "neg_mod", p, a);
    require(twice_mod(a, mod) == ref_add(a, a, p), "twice_mod", p, a);

    if (a != 0) {
      UInt inv = mul_inv(a, mod);
      require(mul_mod(a, inv, mod) == 1, "mul_inv", p, a);
      require(div_mod(a, a, mod) == 1, "div_mod", p, a);
    }

    for (UInt b : residues) {
      require(add_mod(a, b, mod) == ref_add(a, b, p),
              "add_mod", p, a, b);
      require(sub_mod(a, b, mod) == ref_sub(a, b, p),
              "sub_mod", p, a, b);
      require(mul_mod(a, b, mod) == ref_mul(a, b, p),
              "mul_mod", p, a, b);

      UInt bp = precomp_mul_shoup(b, mod);
      require(mul_mod_shoup(a, b, bp, mod) == ref_mul(a, b, p),
              "mul_mod_shoup", p, a, b);

      for (UInt c : residues) {
        require(apbc_mod(a, b, c, mod) == ref_apbc(a, b, c, p),
                "apbc_mod", p, a, b, c);
        require(ambc_mod(a, b, c, mod) == ref_ambc(a, b, c, p),
                "ambc_mod", p, a, b, c);
      }
    }
  }
}

} // namespace

int main()
{
#if !FFLOW_USE_UINT32_PRIMES
  std::cerr << "FFLOW_USE_UINT32_PRIMES is not enabled.\n";
  return 1;
#endif

  require(BIG_UINT_PRIMES_SIZE == BIG_UINT32_PRIMES_SIZE,
          "active table size does not match 32-bit table", 0);
  require(BIG_UINT_PRIMES[0] == BIG_UINT32_PRIMES[0],
          "active table is not the 32-bit table", BIG_UINT_PRIMES[0]);
  require(BIG_UINT_PRIMES[BIG_UINT_PRIMES_SIZE - 1] ==
          BIG_UINT32_PRIMES[BIG_UINT32_PRIMES_SIZE - 1],
          "active table tail is not the 32-bit table",
          BIG_UINT_PRIMES[BIG_UINT_PRIMES_SIZE - 1]);

  for (unsigned idx = 0; idx < BIG_UINT_PRIMES_SIZE; ++idx) {
    UInt p = BIG_UINT_PRIMES[idx];
    require(p < (UInt(1) << 31), "active prime is not msolve-compatible", p);
    require(is_prime_u32(p), "active prime is not prime", p);
    if (idx)
      require(BIG_UINT_PRIMES[idx - 1] > p,
              "active prime table is not strictly descending", p);
  }

  std::vector<unsigned> prime_indexes = {
    0, 1, 2, 3, 4, 5, 7, 11, 17, 31, 63, 127, 199, 255, 319, 399
  };

  for (unsigned idx : prime_indexes)
    test_prime(BIG_UINT_PRIMES[idx]);

  std::cout << "finiteflow32 arithmetic test passed\n";
  return 0;
}
