# Source-owned full native GCC

`import ./source-full-gcc.nix {}` selects the full GCC 16.2 C/C++ construction
generation using earlier source-owned providers. `compiler` is the installed
compiler and matching runtimes; `driver` selects their headers, startup files,
libraries and capability GNU libc. `composition` reconstructs the source base
with that driver.

The authoritative procedure is
[`pkgs/compilers/gcc/native/build-16.2.0.nix`](../pkgs/compilers/gcc/native/build-16.2.0.nix),
shared with public GCC16. Construction selects its earlier base and dependencies
before the public full base exists; it does not keep a second compiler procedure.
Production performs a non-lean three-stage bootstrap, requires object comparison,
restores stage3 once and installs GCC's target libraries. It enables release
checking, LTO, plugins, the analyzer, ISL/Graphite,
POSIX threads, system zlib and Zstd. It builds no Rust or other language frontend.
The earlier checkpoint is only the stage1 compiler; no target runtime archives
are copied from it.

Source preparation applies the pinned regular-library/header-layout patch,
explicit program/linker prefix ordering, and removal of implicit system paths.
The supplemental libgcc copyback patch updates its in-tree staging rule to use
`libdir`, matching the layout patch's renamed installation variable. Without it,
libgcc archives land under a nested absolute prefix instead of the build compiler's
search directory. The selected libc loader and source shell interpreters are bound
explicitly.

## Production and validation boundary

Production prerequisites are imported directly from `source-full-gcc-prerequisites.nix`.
Raw construction Python supplies production commands. The Python validation profile,
DejaGNU, Expect, flock, Graphviz and fonts belong to independent upstream execution
and acceptance. Compatibility exports `harness`, `file` and `testSources` remain
lazy for existing public callers.

`compiler.artifact` retains `nix-support/production` provenance and the configured
build-tree checkpoint. `steps.split` follows installation/checkpoint; finalization
copies and repairs the installed package without copying that test/provenance tree.
The driver reads `compiler.artifact/nix-support/production/builtin.specs` at build
time. Its installed specs and wrappers must refer to the selected final compiler
and runtimes; final-output audits still need to verify that artifact paths do not
leak into the runtime.

`compiler.tests.upstream-audit` uses the shared GCC test factory to restore a private
checkpoint, execute the suites with test tools and classify their retained raw
results. Production does not consume this test. Production comparison/configuration
records stay in the artifact; make-check statuses, summaries and acceptance records
belong to the independent test derivations. A failed upstream gate remains a failure
of the normal validation batch.

This boundary changes the full compiler, driver, full-base and dependent producer
identities. Earlier native and seed providers must remain exact. This is a real
construction change requiring its initial compiler qualification, not an
identity-preserving file cleanup. The separated native boundary passed the local
qualification described below; historical receipts alone do not certify it.

`source-full-gcc-validation.nix` supplies the installed capability endpoint and
customization/isolation contracts, together with independent upstream acceptance
and the normal batch. The shared GCC classifier checks captured raw records and
known-result expectations. The older `source-full-gcc-upstream.py` remains an
inspector for retained historical reports. Quadmath and sanitizers have integrated
compiler cases and installed runtime probes, rather than separate invented counts.
The historical origin/runtime observers retain assumptions about earlier graphs
and runner protocols. They are deferred review work, not qualification of this new
split. See [MIG-001 and the other open decisions](../lib/MIGRATION-DECISIONS.md).

The test floor also builds genuine `file`/libmagic 5.48 from its pinned source;
GCC's native linkage test executes it. `file` remains configure-visible until its
production role is established from source-bound evidence. During upstream execution
the Python profile precedes raw Python tools, keeping validation modules and
`python3-config` together without putting the profile into private production.
The driver searches the installed compiler library prefix before libexec so its
plugin-directory query finds the SDK headers as well as executable plugins.
The installed plugin `configargs.h` retains the compiler's exact configuration
stamp. Its configured prefix is identity data, not a runtime path: rebasing that
stamp makes `plugin_default_version_check` reject otherwise matching plugins.

`libbacktraceChecks` in the validation composition separately executes the matching
support sources with the installed compiler and retains Automake results. These
scratch test objects do not replace production bootstrap objects. Its LTO tests
measure the current compiler rather than inheriting an older disabled-LTO result.
TSan, LSan and HWASan have separate compiler/runtime observations; a configured
runtime need not be usable on every host kernel.

## Local qualification of the separated pipeline

On 2026-11-14 one full compiler build completed configure, bootstrap/comparison,
installation and checkpoint creation. Finalization and the selected driver passed;
the driver runtime closure excludes the compiler artifact. The checkpoint occupies
1,870,499,840 bytes and restores the native sandbox root `/build/workspace`.

The installed capability endpoint passed all eleven capability groups, including
plugin loading, and libbacktrace recorded 38 PASS results. The normal batch checks
installed capabilities plus separate GCC and libbacktrace acceptance leaves. An
initial plugin-stamp finalization defect was repaired using the cached artifact;
neither that repair nor the test-only corrections rebuilt the compiler.

The independent upstream run reproduced the original full-compiler counts:
511250 PASS, 4118 XFAIL, 7237 UNSUPPORTED, 19 FAIL and 2 XPASS across six completed
summaries, with no ERROR/UNRESOLVED. The unchanged known-result classifier passed;
those failures remain unwaived and strict upstream conformance remains false.

The following interpretation of the historical comparison still applies.
Compared with the earlier control, genuine SARIF validation adds 109 passing
records and the native linkage fixture adds one. Three analyzer assembly fixtures
select only `x86_64-pc-linux-gnu`; the required `unknown` vendor tuple changes their
35 assertion results to 15 unsupported invocation records. The C++ module result
also embeds the changed build path. Separate libbacktrace execution passes all
38 tests, including `btest_lto`. HWASan loads but the host kernel rejects its tagged
address ABI; TSan and LSan execute successfully. Qualification is bounded to this
native construction context. The whole ordinary catalogue, historical origin/runtime
observers and additional platforms were not qualified by this run.
