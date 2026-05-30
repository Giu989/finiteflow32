#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-${script_dir}/_install/finiteflow32}"

export PREFIX="${prefix}"

"${script_dir}/scripts/build_finiteflow32.sh"
"${script_dir}/scripts/test_finiteflow32_arithmetic.sh"
"${script_dir}/scripts/test_poly_reduction.sh"
"${script_dir}/scripts/test_mathematica_smoke.sh"
"${script_dir}/scripts/test_mathematica_tutorial.sh"
"${script_dir}/scripts/test_mathematica_multiprime.sh"
"${script_dir}/scripts/test_mathematica_add_one.sh"
"${script_dir}/scripts/test_mathematica_msolve_prime.sh"
"${script_dir}/scripts/test_mathematica_poly_div.sh"
"${script_dir}/scripts/test_mathematica_poly_div_wrapper.sh"

echo "FiniteFlow32 validation passed."
