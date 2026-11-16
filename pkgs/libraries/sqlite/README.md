# SQLite family

`default.nix` lists every supported release in inline recipe/release records.
The public family uses the selected owned base, its named earlier build tools,
one Fossil source resolver and one installed-test factory. Tcl8 and Readline
remain explicit TVP dependencies; fixture-only zlib retains its existing TVP
selection. No public compiler, CMake, Ninja or other heavy generation is activated.

## Complete procedures

- `build-3.0.0.nix`: Fossil/autoconf through3.47.2. Upstream make chooses its own
  multi-file/amalgamation generators. Those prerequisites do not require another
  identical package builder.
- `build-3.48.0.nix`: autosetup through3.53.3, its renamed configure interface,
  Tcl stub/runtime layout and process-isolated veryquick runner.
- `build-3.53.4.nix`: the existing latest installed profile, configure assertions,
  no-zlib production contract, Tcl stub extension and native consumer assertions.
  It retains its independent source-reconstruction upstream plan; it is not
  represented as having the older profiles' retained checkpoint protocol.

The37 inline definition records describe source/patch/interface compatibility
boundaries, not37 builder implementations. GNU17/implicit-declaration allowances,
Tcl string-result support, common-symbol compatibility, configure permissions,
reported alpha/beta versions, pkg-config spelling and test-fixture relinking
remain exact choices. `buildFeatures`, `sourceLayout` and `installedInterface`
group effective production facts. Standard-tool changes go through the effective
base or steps; genuine dependencies and grouped facts remain editable.

## Existing independent validation

The268 historical ordinary releases retain their specialized A/F/T/R/U graph:
A configures/builds/installs and saves the allowlisted tree; F copies A, removes
its checkpoint and finalizes installed products; T restores A, applies test-only
patches and builds testfixture; R privately restores T and captures quick.test
or veryquick output; U accepts only the existing strict classifier result.
No test command, test patch, capture policy or classifier is moved into A/F.

`ordinary/build-state.py`, `ordinary/retained-state.json`, `ordinary/prepare.py`,
`ordinary/finalize.py`, `ordinary/capture.sh`, `ordinary/classify.py` and the
specialized test restore/prepare/runner files keep their existing source paths
and bytes. This directory now holds implementation inputs/protocol documentation,
not a second public definition table or delegated builder implementation.
The historical isolation document remains `ordinary/README.md`.

The3.53.4 profile retains its current independent U implementation, selected
process-isolated workload and installed test set. Its U reconstructs sources;
that existing isolation debt is explicit and is not silently upgraded here.

`tests/installed.nix` contains the common assertions once and selects whole tests
for actual installed API/profile differences. Test bodies, expected results,
strict error handling, historical known failures and skips remain unwaived.
The historical profile keeps its indexed-integer regression; latest3.53.4 keeps
its native feature/Tcl/discovery contracts without acquiring a new test policy.

## Construction callers and broken releases

Construction callers use `family.instantiate` with explicit earlier bases and
dependencies. The duplicate tables, old stdenv procedures and caller factory have
been removed. The ordinary directory contains active protocol helpers, not a
second package index.

Broken 3.2.8 keeps its hash, status, reason and needs: upstream omits `src/os_unix.h`.
It now has an owned split plan in the same family, which does not repair the
incomplete archive or qualify that release.

## Recorded bounded validation

All 269 supported definitions and source/edit/isolation contracts evaluate.
The earlier comparison covered 270 production identities against its pre-authoring
source; those identities are not an acceptance requirement for the current cleanup.
The recorded 3.53.4 normal batch passed all 19 leaves, including its upstream route.
That receipt applies to its bound inputs. Changed outputs are not newly qualified
by this source cleanup.
Native source-reconstruction debt is MIG-018; historical failures and all broader
holds remain unwaived. Existing proofs apply only to their bound producer IDs.
