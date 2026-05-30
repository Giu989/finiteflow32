#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
prefix="${PREFIX:-${repo_root}/_install/finiteflow32}"
build_dir="${BUILD_DIR:-${repo_root}/_build/finiteflow32}"
cmake_bin="${CMAKE:-cmake}"

if [[ -z "${MSOLVE:-}" ]] && command -v msolve >/dev/null 2>&1; then
  export MSOLVE="$(command -v msolve)"
fi

if [[ -z "${MSOLVE:-}" || ! -x "${MSOLVE}" ]]; then
  echo "msolve executable not found. Install msolve or set MSOLVE=/path/to/msolve." >&2
  exit 127
fi

FFLOW_USE_UINT32_PRIMES=ON PREFIX="${prefix}" BUILD_DIR="${build_dir}" \
  "${repo_root}/scripts/build_finiteflow32.sh"

"${cmake_bin}" --build "${build_dir}" --target testpoly_reduction --parallel
"${build_dir}/testpoly_reduction"
