# Source-owned full native GCC

`import ./source-full-gcc.nix {}` selects a separate GCC 16.2 C/C++ bootstrap.
`compiler` is the raw compiler and matching runtimes; `driver` selects their
headers, startup files, libraries and the capability GNU libc. `composition`
reconstructs the source base with that driver. Existing defaults and catalogue
compiler definitions retain their identities.

The authoritative procedure is `pkgs/compilers/gcc/owned/build-16.2.0.nix`.
It performs a non-lean three-stage bootstrap, requires object comparison, restores
stage3 once, runs the configured upstream suites, and installs GCC's target
libraries. It enables release checking, LTO, plugins, the analyzer, ISL/Graphite,
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

This first procedure keeps construction and upstream execution together. Test-tool
changes therefore change its derivation. It claims neither safe configured-tree
relocation nor independent check-only cache reuse. The evidence output retains
stage flags/configuration, comparison output and stage2 object hashes, complete
upstream logs/summaries, and make statuses. Nonzero upstream results are retained
as outcomes; installed capability checks do not turn them into passes.

`source-full-gcc-validation.nix` supplies the installed capability endpoint and
evaluation-only customization contracts. `source-full-gcc-upstream.py` reconciles
raw result records, unique completed summary footers and JSON, requiring real
coverage for all six independent suites. Quadmath and sanitizers have integrated
compiler cases and installed runtime probes, rather than separate invented counts.
The origin and runtime observers require the prior Graphviz/Python/core observers
and independently preserve their overlap. Historical host tools retain their own
runtime permissions; final consumers must use the newly built compiler runtimes.

The test floor also builds genuine `file`/libmagic 5.48 from its pinned source;
GCC's native linkage test executes it. The Python profile precedes the selected
raw Python tools on PATH, keeping validation modules and `python3-config` together.
The driver searches the installed compiler library prefix before libexec so its
plugin-directory query finds the SDK headers as well as executable plugins.

`libbacktraceChecks` in the validation composition separately executes the matching
support sources with the installed compiler and retains Automake results. These
scratch test objects do not replace production bootstrap objects. Its LTO tests
measure the current compiler rather than inheriting an older disabled-LTO result.
TSan, LSan and HWASan have separate compiler/runtime observations; a configured
runtime need not be usable on every host kernel.

The first measured full run retains 19 FAIL and 2 XPASS outcomes, freshly reproduced
and classified; strict upstream conformance is false. Its six completed summaries
contain 511250 PASS, 4118 XFAIL and 7237 UNSUPPORTED with no ERROR/UNRESOLVED.
Compared with the earlier control, genuine SARIF validation adds 109 passing
records and the native linkage fixture adds one. Three analyzer assembly fixtures
select only `x86_64-pc-linux-gnu`; the required `unknown` vendor tuple changes their
35 assertion results to 15 unsupported invocation records. The C++ module result
also embeds the changed build path. Separate libbacktrace execution passes all
38 tests, including `btest_lto`. HWASan loads but this host kernel rejects its tagged
address ABI; TSan and LSan execute successfully.
