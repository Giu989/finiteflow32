# FiniteFlow32 Stage 1 Build and Mathematica Validation

FiniteFlow32 is a fork of FiniteFlow. Stage 1 keeps the original arithmetic
unchanged and focuses on a reproducible local build, local install, renamed
public-facing artifacts, and automated Mathematica validation.

## Dependencies

- CMake 3.12 or newer.
- A C and C++ compiler with C++11 support.
- GMP.
- FLINT or `flint-finiteflow-dep` is optional. If FLINT is not found, the
  project builds with `FFLOW_USE_FLINT=0` behavior.
- Mathematica or Wolfram Engine with `wolframscript` for the Mathematica tests.

This repository does not vendor FLINT or `flint-finiteflow-dep`. To use a
specific FLINT variant, point CMake at its prefix:

```bash
CMAKE_PREFIX_PATH=/absolute/dependency/prefix \
PREFIX="$PWD/_install/finiteflow32" \
./scripts/build_finiteflow32.sh
```

You can also use the shorter `DEPS_PREFIX` variable:

```bash
DEPS_PREFIX=/absolute/dependency/prefix \
PREFIX="$PWD/_install/finiteflow32" \
./scripts/build_finiteflow32.sh
```

On macOS, if neither `CMAKE_PREFIX_PATH` nor `DEPS_PREFIX` is set and
`/opt/homebrew` exists, the build script passes `/opt/homebrew` as the CMake
prefix path.

On macOS, if `MATHEMATICA_ROOT_DIR` is not set and `/Applications/Wolfram.app`
exists, the build script passes that app as `Mathematica_ROOT_DIR`. This keeps
the LibraryLink headers/libraries aligned with the default test runtime.

To disable FLINT explicitly:

```bash
FFLOW_USE_FLINT=OFF PREFIX="$PWD/_install/finiteflow32" ./scripts/build_finiteflow32.sh
```

## Build

From a clean checkout:

```bash
PREFIX="$PWD/_install/finiteflow32" ./scripts/build_finiteflow32.sh
```

The build script configures CMake in `_build/finiteflow32`, installs into the
requested prefix, and writes dynamic library diagnostics to:

```text
$PREFIX/share/finiteflow32/build-logs/dynamic-libraries.txt
```

The script does not require root privileges.

## Mathematica Tests

Run the smoke test:

```bash
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_smoke.sh
```

Run the tutorial-derived integration test:

```bash
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_tutorial.sh
```

Run the full Stage 1 validation pipeline:

```bash
PREFIX="$PWD/_install/finiteflow32" ./validate_finiteflow32.sh
```

If `wolframscript` is not on `PATH`, set:

```bash
WOLFRAMSCRIPT=/absolute/path/to/wolframscript \
PREFIX="$PWD/_install/finiteflow32" \
./scripts/test_mathematica_smoke.sh
```

The test wrappers use `WOLFRAMSCRIPT` when it is set. Otherwise, on macOS they
prefer `${MATHEMATICA_ROOT_DIR}/Contents/MacOS/wolframscript` and then
`/Applications/Wolfram.app/Contents/MacOS/wolframscript` before falling back to
`wolframscript` on `PATH`. This avoids mixing a Mathematica build from one app
with a separate WolframScript runtime from another app.

The test sources are ordinary `.m` files in `tests/mathematica/`, so they can
also be opened and evaluated from the Mathematica GUI. When
`FINITEFLOW32_PREFIX` is not set, they infer the prefix from the checkout and
look for `_install/finiteflow32`. In the GUI they do not call `Exit[0]` after a
successful run, so the kernel stays open for inspection.

If Mathematica is unavailable, the test scripts fail clearly with:

```text
WolframScript not found. Install Mathematica/Wolfram Engine or set WOLFRAMSCRIPT=/path/to/wolframscript.
```

## Installed Layout and Renames

Stage 1 renames and installs the primary public-facing artifacts so this fork
can coexist with an upstream FiniteFlow install:

| Upstream name | FiniteFlow32 name or path |
| --- | --- |
| CMake project `finiteflow` | `finiteflow32` |
| Native library target `fflow` / `libfflow` | `finiteflow32` / `libfiniteflow32` |
| Mathematica LibraryLink target `fflowmlink` | `finiteflow32mlink` |
| Mathematica package context `FiniteFlow`` | `FiniteFlow32`` |
| Mathematica package file | `$PREFIX/share/finiteflow32/mathematica/FiniteFlow32.m` |
| Mathematica LibraryLink directory | `$PREFIX/lib/finiteflow32/mathematica` |
| Installed headers | `$PREFIX/include/finiteflow32/fflow` |
| Optional Python CFFI module | `_cffi_finiteflow32` |
| Optional Python module file | `finiteflow32.py` |

The C++ namespace remains `fflow`, the C API entry points remain `ff*`, and
the internal source include path remains `fflow/...` in Stage 1. Those are
documented public surfaces that may need a later compatibility decision, but
they are not renamed during Stage 1 because doing so would be a broad API and
source-level change unrelated to build reproducibility.

For installed C/C++ headers, use this include root:

```bash
-I$PREFIX/include/finiteflow32
```

Existing header includes such as `<fflow/capi.h>` then resolve under the
FiniteFlow32-specific include prefix and do not overwrite an upstream
`$PREFIX/include/fflow` tree.

## Dynamic Library Handling

CMake sets the install RPATH to `$PREFIX/lib` and enables link-path RPATH
usage. The Mathematica test wrappers also set runtime library paths explicitly:

- macOS: `DYLD_LIBRARY_PATH=$PREFIX/lib:$PREFIX/lib/finiteflow32/mathematica`
- Linux: `LD_LIBRARY_PATH=$PREFIX/lib:$PREFIX/lib/finiteflow32/mathematica`

The wrappers set these variables themselves and do not rely on `.bashrc`,
`.zshrc`, Mathematica notebooks, or Mathematica `init.m`.

The build script records platform-specific diagnostics:

- macOS: `otool -L` and `otool -l | grep -A2 LC_RPATH`
- Linux: `ldd` and `readelf -d | grep -E 'RPATH|RUNPATH|NEEDED'`

## Common Failures

- `GMP not found`: install GMP or set `CMAKE_PREFIX_PATH`/`DEPS_PREFIX`.
- Wrong FLINT variant found: set `CMAKE_PREFIX_PATH` or disable FLINT with
  `FFLOW_USE_FLINT=OFF`.
- `WolframScript not found`: install Mathematica/Wolfram Engine or set
  `WOLFRAMSCRIPT`.
- `LibraryFunction::version` or `LibraryFunction::initerr`: the Mathematica
  runtime used by `wolframscript` may not match the Mathematica installation
  used at build time. Set both `MATHEMATICA_ROOT_DIR` and `WOLFRAMSCRIPT` to
  the same Wolfram installation.
- Mathematica cannot find `FiniteFlow32``: verify
  `$PREFIX/share/finiteflow32/mathematica/FiniteFlow32.m` exists and run the
  provided test wrapper rather than launching Mathematica manually.
- Mathematica cannot load `finiteflow32mlink`: inspect
  `$PREFIX/share/finiteflow32/build-logs/dynamic-libraries.txt` and verify the
  wrapper is setting the platform runtime library path.
