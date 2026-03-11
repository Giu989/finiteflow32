#include <flint.h>
#include <ulong_extras.h>
#include "fflow/ffmod.h"


FFU64 ffMulInverseMod(FFU64 z, FFMod p)
{
  return n_invmod(z, p.n);
}

FFU64 ffDivMod(FFU64 num, FFU64 den, FFMod p)
{
  return ffMulMod(num, ffMulInverseMod(den, p), p);
}


// Instantiate inline functions
extern inline FFMod ffPrecomputedReciprocalMod(FFU64 n);
extern inline FFU64 ffDiv2Mod1(FFU128 z, FFMod p);
extern inline void ffDiv2By1(FFU128 z, FFMod p, FFU64 * quo, FFU64 * rem);
extern inline FFU64 ffAddMod(FFU64 a, FFU64 b, FFMod p);
extern inline FFU64 ffSubMod(FFU64 a, FFU64 b, FFMod p);
extern inline FFU64 ffMulMod(FFU64 a, FFU64 b, FFMod p);
extern inline FFU64 ffAPBCMod(FFU64 a, FFU64 b, FFU64 c, FFMod p);
extern inline FFU64 ffPrecomputedMulShoup(FFU64 w, FFMod p);
extern inline FFU64 ffMulShoup(FFU64 t, FFU64 w, FFU64 wp, FFMod p);
