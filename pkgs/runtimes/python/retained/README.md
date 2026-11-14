# Public Python source migration

All 13 x86_64-linux public rows have independent source-owned procedures and an
installed-artifact/final split. This is source evidence only: every newly migrated
row remains **UNCOMPILED / UNQUALIFIED**. Recipe-policy compliance does not prove
compilation, upstream acceptance, installed behavior or runtime closure purity.

The full-profile boundaries are:

- 3.5–3.6: setup.py module exclusions and extension detection.
- 3.7–3.11: Setup.local exclusions, setup.py extension detection and explicit
  include/library prefixes; per-definition configure options stay effective.
- 3.12: configure-selected extensions, including crypt/libxcrypt.
- 3.13: crypt and its provider removed upstream.
- 3.14: Zstd added.
- 3.15: external Mpdecimal added.

The definitions retain OpenSSL 1.1 for 3.5–3.7, OpenSSL 3.3 for 3.8–3.9, and
Python 3.5's Ncurses 6.4 with identically bound Readline. The public python-build
3.12.5 profile retains its reduced TLS/archive modules and no pip; python-minimal
3.12.5 retains no third-party extension libraries. Neither profile inherits the
full procedure.

Installation belongs to the artifact. Copying, equal-width relocation of compiled
prefixes and bytecode paths, shebang/runtime-shell repair, target-interpreter
bytecode regeneration, stripping, runtime search paths and development metadata
belong to finalization. Source, tool, library and disabled-module edits reach the
effective specification. Final-only edits reuse the installed artifact. Upstream
and developer-interface fixtures remain independent test derivations. Whole-test
feature guards retain older embedding interfaces and dependency-specific tests;
the existing 3.15 measured-payload controls stay specific to that profile.

`tests/contracts.nix` is a pure 13-row evaluation covering the split, edits,
profiles, dependency boundaries and direct/function/public-output test factories.
`tests/test_output_helpers.py` exercises tiny synthetic installed trees, bytecode
and linkage parsing without building CPython or a compiler.

The frozen construction route is intentionally separate:
`bases/source-gnu.tools.python` → `bootstrap/source-python-meson.nix` →
`python-build/owned/build-3.12.5.nix`. That owned file, the legacy procedures and
test factories, all three constructionRecipe routes, and bootstrap/dependency
selection are retained. The status-only interpreter selection is unchanged.

No build/runtime/default-switch gate is waived. Full build and upstream validation,
including inherited construction failures and hardening, belongs to later root
review and foundation integration.
