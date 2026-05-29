#ifndef FFLOW_PRIMES32_HH
#define FFLOW_PRIMES32_HH

#include <fflow/common.hh>

namespace fflow {

  // The 400 largest primes strictly below 2^32.  The list is generated
  // by scripts/generate_primes32.py and stored in src/ff_prime32_list.hh.
  const unsigned BIG_UINT32_PRIMES_SIZE = 400;
  extern const UInt BIG_UINT32_PRIMES[BIG_UINT32_PRIMES_SIZE];

} // namespace fflow

#endif // FFLOW_PRIMES32_HH
