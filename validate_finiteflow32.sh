#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${PREFIX:-${script_dir}/_install/finiteflow32}"

export PREFIX="${prefix}"

"${script_dir}/scripts/build_finiteflow32.sh"
"${script_dir}/scripts/test_mathematica_smoke.sh"
"${script_dir}/scripts/test_mathematica_tutorial.sh"

echo "FiniteFlow32 validation passed."
