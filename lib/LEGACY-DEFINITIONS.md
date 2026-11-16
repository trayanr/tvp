# Remaining authoring boundaries

All 110 ordinary family indexes now define their releases independently through
`mkFamily`. Construction callers use the same family's `instantiate` method with
explicit earlier inputs. No ordinary index imports an old table or exports
`constructionRecipe`. All 1,535 canonical rows and five public variants have
owned artifact/final splits. The twenty declared-broken statuses are unchanged;
structural compliance does not make those sources buildable.

The cleanup removed 136 obsolete indexes and 559 files in their detached source
closure. Actual source-bootstrap procedures and their helpers remain where they
are needed. [MIG-034](MIGRATION-DECISIONS.md#mig-034--uniform-package-families-and-construction-callers)
records scope, changed inputs and validation limits.

## Check the current source

```sh
python3 -B tools/definition-inventory.py --include-untracked
python3 -B tools/definition-inventory.py --include-untracked --json
nix eval --offline .#checks.x86_64-linux.uniform-package-families.drvPath
```

The scanner reads Python/Git source data without evaluating or building packages.
It reports lexical matches and references, not runtime liveness. The evaluated
check requires the shared family origin for every registered version and rejects
captured old indexes. Split admission separately checks the actual evaluated A/F
plans. Migration status reports these facts without claiming runtime qualification.

The package-source screen now finds zero `mkDefs`, `packageArgs`, `mkDerivation`
or `standardTools` declarations/usages under `pkgs/`. The remaining `mkDefs`
examples are two library compatibility fixtures. Private local-stdenv and older
base adapters support low-level tests and the closed source-bootstrap ladder;
they no longer supply ordinary package-family definitions.

## Explicit exceptions and later decisions

- Mirror/archive fallback: Gettext, GDBM, Libffi, Ncurses, Readline, Perl, Tcl and SQLite
  retain their current source-fetch policies until one shared fetch implementation
  supports all declared alternatives and retries. GNU Config also uses the
  existing Git fetch backend. A single-URL builtin fetcher is not a reason to
  discard fallback availability. Source backend choice is separate from package
  procedure/constructor uniformity.
- Source bootstrap: `bootstrap/` and the directly imported `owned`/`native`
  prerequisites still describe actual earlier construction stages. Replacing
  these requires preserving the bootstrap DAG and validating the corresponding
  compiler/provider changes; ordinary packages do not recursively select themselves.
- Real earlier inputs: ACL's GCC13, broken Readline's GCC9, broken Zlib's GCC4,
  compiler seeds, JDK's binary seed, build-host Perl and test harnesses remain
  explicit where they express real capability or construction constraints.
- Existing named profiles remain selectors. They can share a procedure and even
  an output with a canonical release when their effective inputs are identical;
  no artificial compiler/tool difference is introduced just to keep them distinct.
- Runtime and upstream limits remain separate: unbuilt compiler versions,
  source-reconstruction test debt, source-driver bind-now failures, historical
  upstream nonpasses and broad admission holds are not waived by this cleanup.

Tools are selected through `base.tools`, system facts are resolved in
`bases/platforms`, and test construction comes from the shared family factory.
Future package-specific API exceptions should be recorded here rather than hidden
in another retained index or caller adapter. CI/NAS resumption was authorized at
migration closeout; actual operational state is recorded in deployment receipts.
