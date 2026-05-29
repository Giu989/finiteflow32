#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
prefix="${PREFIX:-${repo_root}/_install/finiteflow32}"
build_dir="${BUILD_DIR:-${repo_root}/_build/finiteflow32}"
cmake_bin="${CMAKE:-cmake}"

case "${prefix}" in
  /*) ;;
  *)
    echo "PREFIX must be an absolute path; got: ${prefix}" >&2
    exit 2
    ;;
esac

if [[ ! -f "${build_dir}/CMakeCache.txt" ]] ||
   ! grep -q '^FFLOW_USE_UINT32_PRIMES:BOOL=ON$' "${build_dir}/CMakeCache.txt"; then
  FFLOW_USE_UINT32_PRIMES=ON PREFIX="${prefix}" BUILD_DIR="${build_dir}" \
    "${script_dir}/build_finiteflow32.sh"
fi

"${cmake_bin}" --build "${build_dir}" --target testfiniteflow32_arithmetic --parallel
"${build_dir}/testfiniteflow32_arithmetic"
