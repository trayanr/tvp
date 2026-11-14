# Tcl ordinary owned procedures

On native x86_64 Linux all 82 supported releases select owned installed-artifact
splits. Releases, hashes, status records and Tcl8 consumer selectors are unchanged.
This is source coverage: every changed release remains **UNCOMPILED**, and its
runtime remains **UNQUALIFIED**. It grants no broader admission or default switch.

`legacy.nix` preserves the accepted definitions and construction factory. The
original `build-8.0.2.nix`, `build-8.6.0.nix`, source-bootstrap procedure under
`owned/`, and bootstrap test fixtures remain independent and unchanged.

The complete ordinary procedures preserve the historical construction boundary:

- `ordinary/build-8.0.2.nix` serves 8.0.2–8.5.19. It has no zlib dependency or
  bundled-package target. Original gnu89 options, 8.0p2 reported version, source
  URL alternatives, and the two historical compatibility patches remain explicit.
- `ordinary/build-8.6.0.nix` serves 8.6.0–8.6.17 and 9.0.x. It requires zlib and
  builds binaries, libraries, documentation and bundled packages with the newly
  built interpreter. Original configure defaults, unwinder options and tcl.pc
  version exceptions remain selected by the retained definitions.
- `native/build-8.6.18.nix` retains the current Tcl8 ABI, private headers, stubs
  and full Itcl/SQLite/TDBC/Thread installation.
- `native/build-9.1.0.nix` retains its distinct Tcl9 ABI and Thread3 bundle.

Each production plan installs before `steps.split`. Copying, equal-width prefix
rebasing, installed shebangs, ELF interpreter/RPATH repair, stripping, development
propagation and path checks follow the split. Compiled Tcl library-path constants
and their lengths require `artifactName` to match the final name's width. The
small Tcl relocator changes only that prefix in installed bin/lib/include/data/
manual/support paths, including static/stub archives and tclConfig.sh. Tcl9 ZIP
script images remain disabled under the existing degraded status; ZIPFS commands
are not disabled. No installed build-tree checkpoint is needed.

`.override` changes declared inputs; `.edit` reads the effective `tools`,
`libraries`, source, options and base. `.editRuntime` can replace the runtime
shell, loader, library providers and declared dlopen paths without rebuilding the
artifact. The dependency projection and tests follow effective providers.
`tests/default.nix` supplies the shared test bodies and whole-test guards to both
owned `testContext` and retained caller overrides. Native ABI/package tests remain
version-specific because their installed interfaces differ.

The two current native upstream controls are normal registered tests against the
final output, separate from production. They unpack a private test source, build
only the native `tcltest`/dltest fixtures against installed core/stub libraries,
and use upstream all.tcl runners with installed package providers. The 9.1 offline
oracle patch is test-only. Source, patch, shell, Python, preparation, runner and
expectation edits affect validation alone. `doCheck = false` removes the whole
upstream test while preserving production identities. Raw statuses, summaries,
fixture errors and the existing external-client classification remain visible.
These newly separated runners have not been executed or qualified.

Earlier release test guards and nonpasses remain in force. In particular, 8.0 has
no ARE control; pre-8.5.16 releases have no pkg-config control; pre-8.6 has no zlib
control. Historical construction failures have not been cured or waived. Tcl9's
script-image status and external MySQL/ODBC/PostgreSQL client boundaries remain
explicit limits. Tests newly using installed providers may expose further failures
at later authorized qualification; source evaluation cannot establish outcomes.

Source-only controls are in `tests/contracts.nix` (all 82 evaluated split plans,
focused edits and every registered test derivation) and `tests/output-contract.py`
(tiny byte/layout/Makefile and failure-summary fixtures). They compile and run no
Tcl, dependency, consumer or upstream test. Full/latest catalogue runs, runtime
qualification, CI and NAS publication remain outside this draft.
