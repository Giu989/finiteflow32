#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
prefix="${PREFIX:-${repo_root}/_install/finiteflow32}"

case "${prefix}" in
  /*) ;;
  *)
    echo "PREFIX must be an absolute path; got: ${prefix}" >&2
    exit 2
    ;;
esac

wolframscript="${WOLFRAMSCRIPT:-}"
if [[ -z "${wolframscript}" ]]; then
  if [[ -n "${MATHEMATICA_ROOT_DIR:-}" && -x "${MATHEMATICA_ROOT_DIR}/Contents/MacOS/wolframscript" ]]; then
    wolframscript="${MATHEMATICA_ROOT_DIR}/Contents/MacOS/wolframscript"
  elif [[ -n "${Mathematica_ROOT_DIR:-}" && -x "${Mathematica_ROOT_DIR}/Contents/MacOS/wolframscript" ]]; then
    wolframscript="${Mathematica_ROOT_DIR}/Contents/MacOS/wolframscript"
  elif [[ "$(uname -s)" == "Darwin" && -x /Applications/Wolfram.app/Contents/MacOS/wolframscript ]]; then
    wolframscript="/Applications/Wolfram.app/Contents/MacOS/wolframscript"
  elif command -v wolframscript >/dev/null 2>&1; then
    wolframscript="$(command -v wolframscript)"
  elif command -v WolframScript >/dev/null 2>&1; then
    wolframscript="$(command -v WolframScript)"
  else
    echo "WolframScript not found. Install Mathematica/Wolfram Engine or set WOLFRAMSCRIPT=/path/to/wolframscript." >&2
    exit 127
  fi
fi

export FINITEFLOW32_PREFIX="${prefix}"

if [[ -z "${MSOLVE:-}" ]] && command -v msolve >/dev/null 2>&1; then
  export MSOLVE="$(command -v msolve)"
fi

if [[ -z "${MSOLVE:-}" || ! -x "${MSOLVE}" ]]; then
  echo "msolve executable not found. Install msolve or set MSOLVE=/path/to/msolve." >&2
  exit 127
fi

tmpdir="$(mktemp -d /private/tmp/finiteflow32-msolve-prime.XXXXXX)"
input_file="${tmpdir}/input.ms"
output_file="${tmpdir}/output.ms"

export FINITEFLOW32_MSOLVE_EXTERNAL=1
export FINITEFLOW32_MSOLVE_INPUT="${input_file}"
export FINITEFLOW32_MSOLVE_OUTPUT="${output_file}"

case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib/finiteflow32/mathematica${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
    ;;
  Linux)
    export LD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib/finiteflow32/mathematica${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    ;;
esac

"${wolframscript}" -script "${repo_root}/tests/mathematica/msolve_prime_compat.m"

"${MSOLVE}" -f "${input_file}" -o "${output_file}" -n 1 -v 0

if [[ ! -f "${output_file}" ]]; then
  echo "msolve did not produce an output file." >&2
  echo "msolve input file left at: ${input_file}" >&2
  exit 1
fi

output="$(tr -d '[:space:]' < "${output_file}")"
if [[ "${output}" != "[1]:" ]]; then
  echo "Expected msolve normal form output [1]: but received: ${output}" >&2
  echo "msolve input file left at: ${input_file}" >&2
  echo "msolve output file left at: ${output_file}" >&2
  exit 1
fi

rm -rf "${tmpdir}"
echo "finiteflow32 Mathematica msolve prime compatibility test passed"
