# PHP owned family

On native x86_64 Linux, all 190 canonical releases use `tvp.builder`. The six
independent historical procedures in `ordinary/` preserve the construction
boundaries in the retained `build-*.nix` files: bundled SQLite2 without PDO at
5.0; external PDO plus Flex at 5.1; shipped scanners at 5.2; external SQLite3
and crypt at 5.3; no external crypt dependency at 7.1; pkg-config discovery at
7.4. The existing native 8.5.12 procedure remains independent. Definition
options retain their C dialect, configure-probe flags, installation ordering,
feature guards and dependency constraints. Source tables and hashes are unchanged.

`legacy.nix`, the root build procedures and `constructionRecipe` retain the
original construction routes, including non-native selection. Historical
profiles retain their selected OpenSSL/libxml2 providers; ownership migration
is not a dependency compatibility upgrade.

Each owned procedure installs the production package before `steps.split`.
Finalization copies the artifact, relocates embedded prefixes, repairs shell
interpreters and runtime search paths, strips runtime ELF files, exports
development metadata and checks paths. PHP embeds its prefix in CLI/CGI
binaries as well as phpize, php-config, headers and phar launchers. The existing
`artifactName` capability gives A and F equal-width store names; `relocate.py`
rejects unequal widths and preserves file times. Nix rejects references from F
to A. Runtime provider edits preserve A and rebind dependency metadata and tests.

Historical installed tests reuse `tests/default.nix` and its fixtures through
an owned `testContext`. Retained callers still use their supplied legacy test
context. `tests/native.nix` keeps the latest coverage, including extension
compilation and four upstream PHPTs. Its owned upstream test extracts only the
runner and those fixtures from the declared source and runs the installed F
CLI/CGI. Test fixtures, execution and acceptance do not feed A or F. No build
tree is retained for testing. The four PHPTs are a bounded upstream subset,
not the full upstream suite.

`tests/contracts.nix { pkgs, tvp }` supplies pure whole-family plan, edit,
provider, projection and test-binding controls, plus the legacy-context probe.
The existing `recipe-split-contracts` and `split-named-outputs` checks cover
constructor transport and exclusion behavior. Normal package tests remain in
`testBatches.x86_64-linux.php_VERSION`.

Qualification for this migration is deliberately limited: 190 releases evaluated,
with 189 historical releases uncompiled. Only PHP 8.5.12 was built and its 24
registered tests executed (including the four PHPTs). Source ownership and split
compliance do not establish historical runtime qualification. Full, hardening,
default, machine readiness and merge admission remain held; CI and NAS publication
remain off. Exact producer bindings and command results are in the external PHP
wave evidence and handoff, rather than copied historical runtime proofs.
