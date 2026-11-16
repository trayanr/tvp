# PHP owned family

On native x86_64 Linux, all 190 canonical releases use `tvp.builder`. The six
independent historical root procedures preserve the actual construction
boundaries: bundled SQLite2 without PDO at
5.0; external PDO plus Flex at 5.1; shipped scanners at 5.2; external SQLite3
and crypt at 5.3; no external crypt dependency at 7.1; pkg-config discovery at
7.4. The existing native 8.5.12 procedure remains independent. Definition
options retain their C dialect, configure-probe flags, installation ordering,
feature guards and dependency constraints. Source tables and hashes are unchanged.

Construction callers use this same family with explicit earlier inputs; duplicate
old indexes and caller factories are removed. Historical profiles retain their
OpenSSL/libxml2 constraints. This cleanup adds no architecture support or
historical dependency compatibility claim.

Each owned procedure installs the production package before `steps.split`.
Finalization copies the artifact, relocates embedded prefixes, repairs shell
interpreters and runtime search paths, strips runtime ELF files, exports
development metadata and checks paths. PHP embeds its prefix in CLI/CGI
binaries as well as phpize, php-config, headers and phar launchers. The existing
`artifactName` capability gives A and F equal-width store names; `relocate.py`
rejects unequal widths and preserves file times. Nix rejects references from F
to A. Runtime provider edits preserve A and rebind dependency metadata and tests.

Historical installed tests reuse `tests/default.nix` and its fixtures through
the effective owned `testContext`. The shared overridable factory handles caller
configuration. `tests/native.nix` keeps the latest coverage, including extension
compilation and four upstream PHPTs. Its owned upstream test extracts only the
runner and those fixtures from the declared source and runs the installed F
CLI/CGI. Test fixtures, execution and acceptance do not feed A or F. No build
tree is retained for testing. The four PHPTs are a bounded upstream subset,
not the full upstream suite.

`tests/contracts.nix { pkgs, tvp }` supplies pure whole-family plan, edit,
provider, projection and test-binding controls, plus the caller-context probe.
The existing `recipe-split-contracts` and `split-named-outputs` checks cover
constructor transport and exclusion behavior. Normal package tests remain in
`testBatches.x86_64-linux.php_VERSION`.

Recorded pre-cleanup qualification covered PHP 8.5.12 and its 25-leaf normal
batch, including the signed-PHAR helper and four PHPTs. The other 189 releases
were uncompiled. Source ownership and split compliance do not qualify historical
releases or outputs whose construction inputs changed in the current cleanup. Full, hardening,
default, machine readiness and merge admission remain held; CI and NAS publication
remain off. Exact producer bindings and command results are in the external PHP
wave evidence and handoff, rather than copied historical runtime proofs.
