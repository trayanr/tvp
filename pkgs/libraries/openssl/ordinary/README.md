# Ordinary OpenSSL upstream isolation

The five complete procedures cover 213 supported ordinary releases. Six broken
0.9.6 releases, native newest 3.6.3/4.0.1 and the retained constructionRecipe keep
their original procedures and test factories. They remain upstream-isolation
UNAUDITED. CI and canonical runtime qualification are off.

A compiles and installs production products, then saves a bounded prepared native
tree under `nix-support/upstream-build-tree`. The existing single split gives F
an independent finalizer. F copies the artifact, immediately removes the checkpoint,
and performs the existing source-bound manual restoration, equal-width prefix
relocation, interpreter/runtime binding, stripping, development metadata repair,
RPATH and path/reference checks. No test raw output or fixture is installed in F.
The checkpoint helper and manifest are honest production inputs.

T restores A into a private writable tree, applies `testPatches` through
`testPatchTool`, adapts test scripts with `testPrepareScript`, and constructs the
upstream fixtures. R independently restores T and captures the full native serial
`make -j1 test` workload, with the selected base environment unchanged. R preserves
both native output bytes and status, including nonzero statuses. Its receipt binds
the status and output size/hash. Missing, malformed, inconsistent, empty or nonzero
capture is rejected by U. No failure allowlist, date adjustment, workload filter or
clock override is supplied. A valid failed R is evidence, never successful U.

`tests/native-default.nix` attaches U only to ordinary specifications with
`doCheck = true`. U uses the required effective `package.testContext.mkTest` and
supported specification edits for validation metadata. Normal suites and package
batches include U. Installed consumers still consume F. `doCheck = false` removes
the upstream workload gate and reports `DISABLED_UPSTREAM_WORKLOAD`; it does not
change A/F or claim successful upstream coverage. Override/edit reconstruction
reattaches the factory to the effective specification and runtime providers.

## Source-supported target boundaries

All 213 pinned source archives were cached and inspected/prepared without fetching,
configuring or compiling a canonical package. The task evidence records each pin.
The production make selectors are visible in each complete procedure; no generic
recipe or configure/make-all replay constructs the validation tree.

| Procedure | Production build and install | Private fixture construction |
| --- | --- | --- |
| 0.9.7 | `all` with `DIRS=$(TVP_PRODUCTION_DIRS)` for 0.9.7; this is the original upstream DIRS with only `test` removed, preserving the release-specific fips/sigs/shared marker. Before 0.9.7e use the original `install`, with the same DIRS restriction; later use `install_sw`. For 0.9.8 use `build_libs build_apps build_tools openssl.pc libssl.pc libcrypto.pc`, then `install_sw`. | 0.9.7: `DIRS=test all`; 0.9.8: `build_tests`. |
| 1.0.0 | `build_libs build_apps build_tools openssl.pc libssl.pc libcrypto.pc`, then `install_sw`. | `build_tests`. |
| 1.1.0 | `all` and `install_sw`, restricting LIBS/SHLIBS/PROGRAMS/ENGINES to upstream INSTALL_* lists. In early 1.1.0 install_sw depends on all, so the restrictions also apply during install. | Original unrestricted `build_programs build_engines`. |
| 3.0.0 | `build_sw` and `install_sw`, restricting LIBS/SHLIBS/PROGRAMS and MODULES to upstream installed libraries, applications, engines and providers. | Original unrestricted `build_programs build_modules`. |
| 4.0.0 | Same installed-set restrictions with `build_sw` and `install_sw`; engines remain absent according to upstream feature data. | Original unrestricted `build_programs build_modules`. |

Unified `build_tests` is an alias for `build_programs`, not a portable fixture-only
target. Default build_sw/all constructs noinst test programs; module lists also
contain noinst test providers, and libraries include static libtestutil. Production
restrictions select the upstream INSTALL_* sets, keeping all shipped products.
For 3.x/4.x, production build and install also pass a concrete
`GENERATED_MANDATORY` list from configured `configdata.pm`, excluding only the
`test/` and `fuzz/` roots. This keeps production headers, metadata and provider
products while excluding the global `provider_internal_test.cnf` fixture.
Command-line selection propagates to recursive install makes. It changes neither
the saved Makefile/configdata nor private T/R, which retain unrestricted generation.
The 4.0.0 procedure uses Nix's core allowance for production compilation and keeps
installation and upstream tests serial. Its protocol-specific checkpoint manifest
also retains the generated CMake files and their build/install Perl metadata;
changing those requirements leaves older release producers unchanged.
The original unrestricted Makefiles/configuration survive in the checkpoint, so T
can build the real tests without reconfiguring production or disabling tests in
Configure. Make may regenerate identified metadata or relink in private T/R;
minimal retention, no-rebuild behavior, reuse cost and speedup remain unqualified.

Production compatibility includes cStandard for real historic C identifiers,
forceGccName for domd, shared/library layout, existing feature data and hardening
policy. The three warning suppressions for 0.9.8s/1.0.0f ECDSA fixtures and
1.1.1q/r v3ext fixtures are `testCompileFlags`, applied through the selected compiler
wrapper only in T/R. There are no definition patches in this ordinary family.
`sourceHelper` remains the production patch/preparation seam. `testPatches` is an
independent validated patch/reason list. Test Perl, extra tools, compile flags,
preparation, restore, capture, runner, environment, classifier and expectation are
independent effective specification fields. An unused patch-tool edit with an
empty patch list is intentionally inert; adding an already-present tool is also
inert. Active providers are measured by producer/context identity, not labels.

Source preparation retains production Configure/Makefile/generator/installed-helper
adaptations and compiler-diagnostic closure repair. Test/fuzz trees, OpenSSL Test
Perl modules, raw runner/wrapper scripts and identified historical test scripts are
adapted only in private T. Construction Perl remains a real production dependency;
runtime Perl remains independently bound for installed helpers. Compiler-free
closure is false and is not claimed here.

## Retained tree and restoration

`build-state.json` explicitly bounds the retained source directories, top-level
configuration and generated file patterns. It keeps configured Makefiles,
configdata, original artifact prefix/epoch, generated headers/objects/static/shared
libraries/apps/engines/providers/dependencies, production Perl build modules and
test sources/fixtures. It excludes VCS, workspace history, installed duplicates,
raw results, top-level logs and temporary databases. This conservative native tree
is not a proven minimal checkpoint.

The PAX archive and layout metadata preserve modes, nanosecond mtimes, relative
internal links and layout. Namespace checks reject external links, hardlinked
files and special nodes. Restore checks the complete archive/member namespace
before extraction. Store links are never made writable. A private sandbox path
is preserved when available; otherwise only generated Makefile/Makefile.ssl,
configdata.pm and dependency .d metadata is rebased. Binary objects and the
configured prefix are unchanged. T and R get independent private copies.

## Qualification limits

Source identities and tiny markers do not certify new A/F outputs. Earlier six
of eight representative qualifications apply only to parent 977bcc58 identities;
retain those roots and the two original certificate-expiry nonpasses (1.0.0f and
1.1.0g) unchanged. Both remain unqualified. First real pilots after independent
review are 0.9.7c and 4.0.0; their A/F/T/R/U handles are recorded in the task handoff
and are NOT_RUN. No canonical OpenSSL, provider, compiler or runtime was built or
fetched in this source task. Full/global/strict isolation and all promotion holds
remain false and unwaived. Artifact/final split accounting is a separate measure.

Shared branch-reconciliation changes are STRUCTURE.md, lib/upstream-test-isolation.nix,
lib/default.nix, default.nix and flake.nix. The policy retains SQLite quick/veryquick
semantics and adds the actual OpenSSL protocols/fields without fake SQLite inputs.
No SQLite recipe or split baseline is ported from the sibling source.
