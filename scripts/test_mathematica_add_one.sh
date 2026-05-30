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

case "$(uname -s)" in
  Darwin)
    export DYLD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib/finiteflow32/mathematica${DYLD_LIBRARY_PATH:+:${DYLD_LIBRARY_PATH}}"
    ;;
  Linux)
    export LD_LIBRARY_PATH="${prefix}/lib:${prefix}/lib/finiteflow32/mathematica${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
    ;;
esac

exec "${wolframscript}" -script "${repo_root}/tests/mathematica/add_one.m"
