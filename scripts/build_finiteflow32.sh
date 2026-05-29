#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"

prefix="${PREFIX:-${repo_root}/_install/finiteflow32}"
build_dir="${BUILD_DIR:-${repo_root}/_build/finiteflow32}"
build_type="${CMAKE_BUILD_TYPE:-Release}"
cmake_bin="${CMAKE:-cmake}"
jobs="${JOBS:-}"
mathlibinstall="${MATHLIBINSTALL:-${prefix}/lib/finiteflow32/mathematica}"

case "${prefix}" in
  /*) ;;
  *)
    echo "PREFIX must be an absolute path; got: ${prefix}" >&2
    exit 2
    ;;
esac

if ! command -v "${cmake_bin}" >/dev/null 2>&1; then
  echo "cmake not found. Install CMake or set CMAKE=/path/to/cmake." >&2
  exit 127
fi

cmake_prefix_path="${CMAKE_PREFIX_PATH:-}"
if [[ -n "${DEPS_PREFIX:-}" ]]; then
  cmake_prefix_path="${DEPS_PREFIX}${cmake_prefix_path:+;${cmake_prefix_path}}"
elif [[ -z "${cmake_prefix_path}" && "$(uname -s)" == "Darwin" && -d /opt/homebrew ]]; then
  cmake_prefix_path="/opt/homebrew"
fi

configure_args=(
  -S "${repo_root}"
  -B "${build_dir}"
  -DCMAKE_BUILD_TYPE="${build_type}"
  -DCMAKE_INSTALL_PREFIX="${prefix}"
  -DMATHLIBINSTALL="${mathlibinstall}"
  -DFFLOW_MATHEMATICA="${FFLOW_MATHEMATICA:-ON}"
  -DFFLOW_PYTHON="${FFLOW_PYTHON:-OFF}"
  -DFFLOW_USE_UINT32_PRIMES="${FFLOW_USE_UINT32_PRIMES:-ON}"
)

if [[ -n "${cmake_prefix_path}" ]]; then
  configure_args+=(-DCMAKE_PREFIX_PATH="${cmake_prefix_path}")
fi

if [[ -n "${FFLOW_USE_FLINT:-}" ]]; then
  configure_args+=(-DFFLOW_USE_FLINT="${FFLOW_USE_FLINT}")
fi

if [[ -n "${CMAKE_OSX_ARCHITECTURES:-}" ]]; then
  configure_args+=(-DCMAKE_OSX_ARCHITECTURES="${CMAKE_OSX_ARCHITECTURES}")
fi

if [[ -n "${MATHEMATICA_ROOT_DIR:-}" ]]; then
  configure_args+=(-DMathematica_ROOT_DIR="${MATHEMATICA_ROOT_DIR}")
elif [[ -n "${Mathematica_ROOT_DIR:-}" ]]; then
  configure_args+=(-DMathematica_ROOT_DIR="${Mathematica_ROOT_DIR}")
elif [[ "$(uname -s)" == "Darwin" && -d /Applications/Wolfram.app ]]; then
  configure_args+=(-DMathematica_ROOT_DIR="/Applications/Wolfram.app")
fi

if [[ -n "${CMAKE_ARGS:-}" ]]; then
  # CMAKE_ARGS is intentionally shell-split so callers can pass ordinary
  # cmake options such as: CMAKE_ARGS="-DFOO=ON -DBAR=/path".
  # shellcheck disable=SC2206
  extra_cmake_args=(${CMAKE_ARGS})
  configure_args+=("${extra_cmake_args[@]}")
fi

"${cmake_bin}" "${configure_args[@]}"

build_args=(--build "${build_dir}" --target install)
if [[ -n "${jobs}" ]]; then
  build_args+=(--parallel "${jobs}")
else
  build_args+=(--parallel)
fi
"${cmake_bin}" "${build_args[@]}"

log_dir="${prefix}/share/finiteflow32/build-logs"
mkdir -p "${log_dir}"
dynlog="${log_dir}/dynamic-libraries.txt"

{
  echo "FiniteFlow32 dynamic library inspection"
  echo "prefix=${prefix}"
  echo "build_dir=${build_dir}"
  echo "date=$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo

  libs=()
  while IFS= read -r lib; do
    libs+=("${lib}")
  done < <(find "${prefix}" -type f \( \
    -name 'libfiniteflow32*.so*' -o \
    -name 'libfiniteflow32*.dylib' -o \
    -name 'finiteflow32mlink*.so*' -o \
    -name 'finiteflow32mlink*.dylib' \
  \) | sort)

  if [[ ${#libs[@]} -eq 0 ]]; then
    echo "No finiteflow32 dynamic libraries found under ${prefix}."
  fi

  for lib in "${libs[@]}"; do
    echo "== ${lib}"
    case "$(uname -s)" in
      Darwin)
        if command -v otool >/dev/null 2>&1; then
          echo "-- otool -L"
          otool -L "${lib}" || true
          echo "-- LC_RPATH"
          otool -l "${lib}" | grep -A2 LC_RPATH || true
        else
          echo "otool not found; skipped macOS dynamic library inspection."
        fi
        ;;
      Linux)
        if command -v ldd >/dev/null 2>&1; then
          echo "-- ldd"
          ldd "${lib}" || true
        else
          echo "ldd not found; skipped Linux dependency inspection."
        fi
        if command -v readelf >/dev/null 2>&1; then
          echo "-- readelf RPATH/RUNPATH/NEEDED"
          readelf -d "${lib}" | grep -E 'RPATH|RUNPATH|NEEDED' || true
        else
          echo "readelf not found; skipped ELF dynamic section inspection."
        fi
        ;;
      *)
        echo "Dynamic library inspection is not implemented for $(uname -s)."
        ;;
    esac
    echo
  done
} | tee "${dynlog}"

echo "FiniteFlow32 installed in ${prefix}"
echo "Dynamic library inspection written to ${dynlog}"
