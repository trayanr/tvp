# Opt-in source base consumers

`source-base.nix` constructs base data from the owned bootstrap, capability-libc
GNU target driver, and matching GCC runtimes. The runner floor contains only
GNU Bash and Coreutils. Recipe tools remain explicit step inputs. Construction
uses the owned `lib/builder.nix` factory and `builtins.derivation`; it does not
import the flake, nixpkgs, setup hooks, or `mkDerivation`.

To replace the compiler, call the constructor with `compiler = selectedCompiler`.
This reconstructs `base.environment` with the selected compiler and its runtime
directories. A plain nested `base // { stdenv = ...; }` overlay cannot rebind the
old environment closure. The compiler must provide the existing native
`bintools`, `libc`, `libcTools`, `defaultHardeningFlags`, and `runtimeDirectories`
interface. No new overlay or override framework is introduced.

Build the standalone chain directly, in order:

```sh
nix build --impure -f bootstrap/source-consumers.nix gmp
nix build --impure -f bootstrap/source-consumers.nix mpfr
nix build --impure -f bootstrap/source-consumers.nix mpc
nix build --impure -f bootstrap/source-consumers.nix evidence.gmp evidence.mpfr evidence.mpc
nix build --impure -f bootstrap/source-consumer-tests.nix consumer
```

GMP 6.3.0 uses native assembly, source-built M4 1.4.21, shared/static libraries,
and C++. Its configure probes deliberately use GNU17 with GCC 16. MPFR 4.2.2 and
MPC 1.4.1 reuse the existing owned recipes through ordinary specification and
step edits. Their shared-only defaults are preserved. All three execute upstream
suites: GMP 200 PASS; MPFR 196 PASS and 2 SKIP (the decimal64/decimal128 conversion
tests require unavailable compiler decimal-float support); MPC 75 PASS. Evidence
collectors gate these raw counts and individual test records, not just `make`
exit status. These are upstream test programs, not counts of internal assertions.

Compilation artifacts retain configure/build/check/install logs, raw upstream
logs and test records. Named `evidence` endpoints collect them without recompiling.
Finalized libraries remove this evidence, relocate development metadata, and
use explicit owned strip, archive, RPATH, path, and symlink operations. Split
artifacts and multiple named outputs are never combined. The original GMP public
header is retained as evidence; only its `__GMP_CC` diagnostic command string is
normalized to `cc (TVP capability GNU target GCC 16.2.0)`. ABI declarations and
feature macros remain intact. This avoids making build compiler paths runtime
dependencies while recording their exact provenance separately.

Installed C/C++ consumers request only MPC's public library interface. The owned
environment expands its declared MPFR/GMP development requirements. Consumers
exercise large integers, directed 512-bit rounding, complex arithmetic, C++
exceptions, and installed static GMP/GMPXX archives. Link maps, include/CRT
selection, ELF metadata, loader traces, and actual process mappings belong to a
separate evidence output. The MPC-only link derives GNU ld `-rpath-link`
directories from that expanded public interface, as required under the target
sysroot; these are link-time flags. Programs execute with `env -i`, without library-path
overrides. The separate origin and runtime audits extend the existing strict
per-generation observers and retain their negative controls.

This remains x86_64 Linux only, with the existing hardening and static-PIE
limitations. It does not promote a public base, change ordinary producers or
defaults, rebuild compiler frontends/libc/runtimes, or establish full conformance,
self-hosting, a fixed point, or reproducibility.
