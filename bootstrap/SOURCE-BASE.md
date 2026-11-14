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
MPC 1.4.1 use owned recipes. MPFR uses the public family's modern
`build-4.0.2.nix` procedure, instantiated with this earlier compiler and GMP. Their
shared-only defaults are preserved. The explicit evidence endpoints require GMP
200 PASS, MPFR 196 PASS
and two named decimal-float SKIPs, and MPC 75 PASS. These count upstream test
programs, not internal assertions; changed compiler capabilities require fresh
qualification of those expectations.

MPFR compilation/install produces A and saves its compiled source checkpoint.
Finalization produces F independently. `mpfr.tests.upstream` restores A in a private
workspace, executes `make check`, and retains its status, raw log and individual
records. `evidence.mpfr` collects these and applies the existing strict count/skip
checks. It depends on upstream acceptance; requesting MPFR alone no longer runs its
upstream suite. GMP/MPC still retain their earlier inline-check evidence layout.
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
No setup hooks are installed or sourced. Internal GLib's charset alias default
is bound in source to the selected GNU libc's `lib` directory. Upstream requires
no alias file for glibc; its missing-file fallback and `CHARSETALIASDIR` override
remain intact. A probe linked to the actual vendored object checks the opened
path, C/C.UTF-8 codesets, and present/missing override files. Finalization does
not rewrite executable constants. Split compilation artifacts remain reusable.

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

## Opt-in CMake prerequisites

`source-cmake-prerequisites.nix` composes Perl 5.44.0, OpenSSL 4.0.1,
zlib 1.3.2, Bzip2 1.0.8, XZ 5.8.4 and Zstd 1.5.7 against the same selected
GNU base. Only Perl and OpenSSL introduce new recipes; the four codecs reuse
the existing owned recipes. CMake itself is a later stage.

```sh
nix build -f bootstrap/source-cmake-prerequisites.nix perl
nix build -f bootstrap/source-cmake-prerequisites.nix openssl zlib bzip2 xz zstd
nix build -f bootstrap/source-cmake-prerequisite-tests.nix consumer sourceOverridePerl sourceOverrideOpenssl
nix build -f bootstrap/source-cmake-prerequisites.nix evidence.perl evidence.openssl evidence.zlib evidence.bzip2 evidence.xz evidence.zstd
```

Perl retains its shared interpreter, core XS and truthful Config/ExtUtils tool
metadata. Its reference closure therefore includes development compiler tools;
that closure is reported separately from the bounded interpreter/libperl/XS
ELF generation. OpenSSL uses this Perl only for building, retains serial make,
and installs shared libraries and provider modules under its final prefix.
Its generated wrappers bind owned Perl/Bash explicitly. The OpenSSL version
diagnostic reports the compiler basename and original flags; raw build logs
retain the full invocation, avoiding a toolchain reference from native libcrypto.
The Perl Pod::Html test helper binds its hardcoded diff lookup to declared
Diffutils so its expected-failure assertions retain their upstream semantics.
Its harness uses the existing Nix core count and upstream parallel scheduling.
Runtime edits apply to the interpreter, libperl and core XS. Finalization makes
read-only libraries writable temporarily and restores their installation modes,
including on failure. The strict observer checks each installed ELF and its
actual loader resolution. A small copied-library fixture verifies runtime path
edits and mode restoration without compiling a second interpreter.
Both ports use a single derivation stage because installed paths contain that
prefix. Their runtime edits rebuild the derivation.

Sibling evidence outputs retain raw upstream phase logs. Zstd keeps its existing
artifact split and exposes artifact logs through a separate evidence observer.
Its upstream scope remains the five explicitly named CLI tests, not the full
Zstd suite. Installed consumers exercise shared/static codec roundtrips, real
pkg-config interfaces, shared-libperl embedding, a fresh ExtUtils XS build,
provider loading and a local TLS handshake with application data over memory
BIOs. Source overrides use alternate archives without rebuilding an interpreter.
The separate origin/runtime observers preserve the earlier audits and keep the
compiler's development capability outside native executable permissions.

Owned CMake is an opt-in single-stage tool with its installed CTest, CPack and
module tree. It retains the canonical TLS and four system-codec choices and
exports the pure development-prefix provider through the owned specification.
Bootstrap per-codec selectors accompany the cache flags so `--no-system-libs`
retains the selected exceptions.
JSON-C reuses its existing recipe and split finalization.

```
nix build -f bootstrap/source-cmake.nix cmake
nix build -f bootstrap/source-cmake.nix jsonC
nix build -f bootstrap/source-cmake-tests.nix consumer sourceOverrideCmake sourceOverrideJson runtimeJson
nix eval --json -f bootstrap/source-cmake-tests.nix contracts
python3 bootstrap/source-cmake-origin-audit.py > origin.json
python3 bootstrap/source-cmake-runtime-audit.py origin.json
```

The consumer checks both generators, rebuilds and failures, installed APIs,
CPack codec roundtrips, locally verified HTTPS and four upstream RunCMake script
families. This is a bounded upstream subset; production `BUILD_TESTING` stays
off. Successful phase logs live in CMake's `evidence` output and JSON-C's build
artifact. Consumer logs have a separate `evidence` output. Runtime auditing keeps
module source and build/development references separate from native ELF roles.
