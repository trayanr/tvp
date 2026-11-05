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
separate evidence output. The source base's linker contributes GNU ld
`-rpath-link` directories through the ordinary tool environment API. It derives
them from the expanded public interfaces, so an MPC-only consumer needs no
special compiler arguments for indirect libraries under the target sysroot. Programs execute with `env -i`, without library-path
overrides. The separate origin and runtime audits extend the existing strict
per-generation observers and retain their negative controls.

This remains x86_64 Linux only, with the existing hardening and static-PIE
limitations. It does not promote a public base, change ordinary producers or
defaults, rebuild compiler frontends/libc/runtimes, or establish full conformance,
self-hosting, a fixed point, or reproducibility.

## Opt-in build tools

`source-build-tools.nix` supplies owned-step pkg-config 0.29.2 and Ninja 1.13.2.
The canonical definitions and public defaults remain unchanged. Build and inspect
these endpoints independently:

```sh
nix build --impure -f bootstrap/source-build-tools.nix pkgConfig
nix build --impure -f bootstrap/source-build-tools.nix ninja
nix build --impure -f bootstrap/source-build-tools.nix evidence.pkgConfig evidence.ninja
nix build --impure -f bootstrap/source-build-tool-tests.nix consumer sourceOverridePkgConfig sourceOverrideNinja
```

Pkg-config uses bundled internal GLib and GNU17, retaining upstream warnings.
Its compiled default `.pc` path is empty because store installations have no
shared global development prefix. The existing `lib/pkg-config-environment.nix`
provider is exported through the owned specification's `buildEnvironment` field.
`base.environment { tools = [ pkgConfig ]; libraries = [ mpc ]; }` supplies
`PKG_CONFIG`, empty PATH/SYSROOT overrides, and only the resolved public MPC,
GMP, and MPFR development directories. Explicit module directories still work.
No setup hooks are installed or sourced. Internal GLib's compiled libcharset
fallback directory is rebased during finalization; the byte operation validates
one NUL-terminated store `/lib` constant, retains its allocation size, and changes
no executable instructions. Split compilation artifacts remain reusable.

Ninja binds the existing store-shell patch to source-owned GNU Bash. The existing
minimal musl Python bootstraps it and runs the upstream syntax tests. Python
remains a BUILD helper: the optional Python web browser feature is disabled, and
installed `ninja_syntax.py` is nonexecutable source data with its unused shebang
removed. The upstream manual source and license are retained. There is no
`/bin/sh` or `/usr/bin/env` runtime fallback.

The raw upstream scope is the complete 30-test pkg-config discovery suite
(`check/`, excluding bundled GLib's own tests), and Ninja's nonempty upstream
`misc/ninja_syntax_test.py` subset. Ninja's C++ harness requires GoogleTest,
absent from the pinned archive; it is not built. Its terminal-output suite also
requires PTY/`script` helpers outside this selected floor. These limits do not
constitute full Ninja coverage.

The installed owned project exercises C/C++ arithmetic using actual pkg-config
flags and Ninja execution. It removes the environment's duplicate library flags
so public discovery is required. Direct GMP/MPFR calls request those modules in
addition to MPC; MPC's private dependencies do not become dynamic direct-link
flags automatically. Header changes rebuild both object files and change program
results; subsequent builds do no work. A failing command returns Ninja status 23,
with the raw child status 23 retained in Ninja output. The project verifies the
exact Bash, installed module import, clean-environment execution, loader and ELF
metadata. Build logs, selected `.pc` files, command lists, link maps and test
statuses live in separate evidence outputs. Alternate real archives prove source
overrides reach both unpack steps. Evaluation contracts cover final base and
environment edits, provider export, and artifact-preserving runtime edits.

The separate build-tool construction and per-generation runtime audits retain
the arithmetic-stage audits and negative controls. BUILD compiler/Python tools
are never permitted in the new native runtime. Prior shell runtime uses its own
loader; the capability-libc tools and consumers use the new loader and matching
GCC runtime libraries. These endpoints make no promotion, full-conformance,
self-hosting, fixed-point, or reproducibility claim.
