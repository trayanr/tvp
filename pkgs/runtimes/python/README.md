# Public Python family

The 11 general-purpose releases and two reduced public profiles use inline
nameless definitions and the implicit family constructor/base/helper/test model.
Tcl/SQLite/OpenSSL and every other actual dependency stay explicit TVP selections.
Earlier standard tools come from the effective base. The public runtime Bash,
public pkg-config and installed-helper Grep retain their distinct actual roles.

Six complete general-purpose procedures preserve real profile boundaries:
3.5 setup.py exclusions;3.7 Setup.local with setup.py extension detection;
3.12 configure-selected extensions and crypt;3.13 crypt removal;3.14 Zstd;
3.15 required external Mpdecimal. Stable facts are grouped in `buildFeatures`,
`sourceLayout` and `installedInterface`; narrow release exceptions are in the
table. Upstream module choices are a separate test-only `upstreamPolicy`.

`python-minimal/build.nix` and `python-build/build.nix` are complete independent
public reduced-profile procedures. Their pinned old `build-3.12.5.nix` files and
the direct `python-build/owned` bootstrap provider are deliberately unchanged.
Their disabled-module sets, no-pip/no-test-extension profile, static embedding
interfaces, TLS/archive differences and loader/config-helper repairs remain.

All profiles retain their installed-artifact/final split, equal-width artifact
name, bytecode/prefix relocation, shell rebinding and target-interpreter cache
regeneration. Runtime shell/library changes remain distinct from construction
providers. Standard-tool customization uses the effective base or selected steps.
Actual module/library/interface facts remain editable through grouped fields.

`tests/installed.nix` contains one general-purpose suite. The two reduced profiles
share `tests/build-profiles.nix`, with whole-profile guards for their actual TLS
and archive assertions. Existing fixtures and expectations are reused.
Independent upstream checks still run against installed F. TLS closure patches
still apply only to private copied test/ctypes trees. No new checkpoint, runner,
classifier, test exclusion or waiver is introduced.

Current default build/install targets also compile test scaffolding and, in newer
CPython, execute extension-import validation. That source-bound production behavior
is retained as explicit isolation debt; no claim of test-free compilation is made.
Broad regression suites remain independent installed tests. Minimal/build keep
`--disable-test-modules`; full Python keeps its complete existing installed payload.

Construction callers use `retained-construction.nix`, six byte-identical
`retained/build-*.nix` files, the original `3.nix`, and the unchanged old installed
factory. Direct bootstrap and GCC13 frozen selections are not redirected.
Original source-stage documentation is `retained/README.md`.

All 13 public production artifact/final identities match the pre-authoring
producers. Python 3.15.2 and the two public 3.12.5 reduced profiles pass their
normal batches (27, 14 and 10 leaves respectively). Historical releases are not
qualified by these results. The observer now checks actual scoped split admission
instead of a stale global debt count; final-only Binutils probes edit final steps
without claiming that a construction-base compiler edit can reuse A. Existing
qualification holds remain unwaived.
