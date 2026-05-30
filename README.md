FiniteFlow32
============

FiniteFlow32 is a fork of FiniteFlow. The current pipeline provides a renamed,
reproducible local build, a 32-bit-prime mode, native arithmetic validation,
and Mathematica reconstruction validation.

Stage 1 commands:

```bash
PREFIX="$PWD/_install/finiteflow32" ./scripts/build_finiteflow32.sh
./scripts/test_finiteflow32_arithmetic.sh
./scripts/test_poly_reduction.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_smoke.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_tutorial.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_multiprime.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_add_one.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_msolve_prime.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_poly_div.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_poly_div_wrapper.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_leading_monomials.sh
PREFIX="$PWD/_install/finiteflow32" ./scripts/test_mathematica_groebner.sh
```

Or run the complete build/install/test pipeline:

```bash
PREFIX="$PWD/_install/finiteflow32" ./validate_finiteflow32.sh
```

See [docs/finiteflow32-build.md](docs/finiteflow32-build.md) for dependency
selection, installed layout, dynamic library handling, Mathematica validation,
and the Stage 1 rename audit.

Upstream FiniteFlow notes follow.

FiniteFlow
==========

A proof-of-concept implementation of the `FiniteFlow` framework.

FiniteFlow is a framework for defining and executing numerical
algorithms over finite fields and reconstructing multivariate rational
functions from numerical evaluations. Within this framework, complex
algorithms are easily defined by combining basic building blocks into
computational graphs, known as dataflow graphs. This allows to easily
implement complex methods over finite fields from high-level languages
and computer algebra systems, without being concerned with the
low-level details of the numerical implementation. Multivariate
analytic results are then reconstructed from these numerical
evaluations. The algorithm sidesteps the appearance of large
intermediate expressions and can be massively parallelized.

It is based on the following publication:

- Tiziano Peraro, *FiniteFlow: multivariate functional reconstruction
  using finite fields and dataflow graphs*,
  [arXiv:1905.08019](https://arxiv.org/abs/1905.08019)

This implementation is written in C++ and includes C, Python and
Mathematica interfaces.


Installation
------------

### Dependencies

#### CMake

FiniteFlow uses the CMake build system, which comes preinstalled on
many systems, or can be installed with available package managers for
most Linux distributions and using Homebrew for macOS.  Binary
installers for several operating systems, as well as additional
information, can be found at [https://cmake.org/](https://cmake.org/).


#### GMP

GMP is preinstalled on many systems.  A `gmp` package is available on
many Linux distributions and on Homebrew for macOS.  For more
information see [https://gmplib.org/](https://gmplib.org/).


#### FLINT (optional)

FiniteFlow can optionally use the FLINT library for computing
multiplicative inverses.  For the installation of FLINT you have two
options:

- Install the full FLINT library.  Installation packages are available
  for some Linux distributions (including Debian/Ubuntu) and macOS.
  See [http://www.flintlib.org/](http://www.flintlib.org/) for more
  information about FLINT and its installation.

- Alternatively, you can install the `flint-finiteflow-dep` library, a
  stripped down version of FLINT which includes the dependencies
  needed by FiniteFlow.  Unlike the full FLINT library, this version
  has no external dependency besides GMP and can therefore be easier
  to install from source (see the README file of
  `flint-finiteflow-dep` for more information).  You can obtain it at
  this [link](https://github.com/peraro/flint-finiteflow-dep).

If FLINT is not found, FiniteFlow will be compiled without using it.  If you have FLINT installed but you want to disable it, call `cmake` with the option `-DFFLOW_USE_FLINT=0`.


### Installing FiniteFlow

FiniteFlow uses the CMake build system.  In order to install
FiniteFlow in a default installation path, you can use the command
```
cmake . && make install
```

On Apple Silicon Macs (with M1 processor or newer) add the option `-DCMAKE_OSX_ARCHITECTURES=arm64` to the `cmake` command.

In order to install FiniteFlow in a custom path, or specify a
different path for its dependencies use
```
cmake -DCMAKE_INSTALL_PREFIX=/installation/path/prefix \
      -DCMAKE_PREFIX_PATH=/dependencies/installation/path/prefix \
      -DMATHLIBINSTALL=/mathematica/interface/installation/path .
make install
```
where you can omit any of the options in order to pick a default value
for them.

In order to use the Python 3 interface, add the option `-DFFLOW_PYTHON=1` to the `cmake` command (note that it requires the `cffi` Python package, see [these instructions](pythonapi/README.md) for more details).

In order to use FiniteFlow from the Mathematica interface, consider
adding the following to your Mathematica `init.m` file
```
(* the next two lines are only needed if a custom MATHLIBINSTALL path was chosen when running cmake *)
$FiniteFlowLibPath = "/mathematica/interface/installation/path"
If[Not[MemberQ[$LibraryPath,$FiniteFlowLibPath]],$LibraryPath = Flatten[{$LibraryPath, $FiniteFlowLibPath }]];

(* the next two lines are needed to locate FiniteFlow.m, if not already in your $Path *)
$FiniteFlowPath = "/path/to/finiteflow/mathlink"
If[Not[MemberQ[$Path,$FiniteFlowPath]],$Path = Flatten[{$Path, $FiniteFlowPath }]];
```


Tutorials, examples and FAQ
---------------------------

A tutorial using the Mathematica interface is included, in the file
[mathlink/tutorial.wl](mathlink/tutorial.wl).  Tutorials using the
Python interface are included in the directory
[pythonapi/tutorials](pythonapi/tutorials/README.md).

Additional packages and examples are in the repositories [finiteflow-mathtools](https://github.com/peraro/finiteflow-mathtools), [finiteflow-pytools](https://github.com/peraro/finiteflow-pytools) and [ff_native_ext_template](https://github.com/peraro/ff_native_ext_template).

A list of frequently asked questions is in the file [FAQ.md](FAQ.md).
We kindly ask users to read it before reporting an issue.
