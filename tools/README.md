# Repository tools

All six apps are copied by `tools/lib/owned-cli.nix`, a direct derivation run by
TVP Bash with TVP coreutils. It installs explicit Bash shebangs and checks each
script with `bash -n` and ShellCheck (a borrowed build-time validator). It uses
no stdenv setup, wrapper hooks or compiler. Text manifests use `builtins.toFile`.

The four shell commands retain `errexit`, `nounset` and `pipefail`, and prepend
their declared tools in order to the caller's PATH. The Python entrypoints exec
TVP Python, forward every argument, and set `TVP_DEPENDENCIES_SYSTEM` or
`TVP_TEST_SYSTEM` from the selected native platform. They leave PATH alone.
The helper supports these scripts only; it is not a general packaging API.

Explicit runtime utilities and interpreters are TVP packages except jq, which
has no TVP recipe. Commands that query Nix use the caller's host Nix API.
Inherited bootstrap closures and the test runner's external strace boundary
remain separate from this packaging change. Ruby's extension tests retain an
owned GCC 13 consumer compiler as a control against GCC 16-built Ruby.

`tvp-test verify --run /absolute/frozen/run --output report.json` reads one
terminal full attempt without running status, evaluating source, building or
writing run caches. It checks reporting, derivation outputs and the current
aggregate/suite/test links, including validity of secondary outputs. Reports use
`tvp.validation-report/v1`; input hashes reference large inventories. Output files
are immutable: a conflicting report or an input alias is refused.

For exported evidence use `--plan plan.json --state status.json --adapter ci-status`
(the raw adapter is the default). Exported status may have an observation time
after completion and must include source, exclusions,
run and suite counts; local worker evidence is explicitly unavailable. Store links
are always observed on the executing host, never inferred from exported link rows.
Use `--expect-revision`, `--expect-source` and `--expect-system` for external
bindings. `--reference-plan` compares the entire reviewed plan; `--revision-only`
permits only its revision field to differ for squash replay.

`--graph-before` and `--graph-after` use the existing graph comparison semantics
and are informational. Optional `--invariants` JSON has schema `1` and exact
`graphEntries`, `planJobs`, `skipped` and/or `graphDelta` expectations. It supplies
policy data without changing CI policy. `--log` and `--prepare-log` attach execution
observations; missing logs mean unknown. Cached outputs and a successful report
establish neither fresh execution, source approval nor ABI compatibility.

`nix run .#status -- --migration` reports evaluated constructor, selected-base,
artifact/final split and actual public latest-selector coverage. It returns before
the legacy whole-store closure scan. `--migration --json` emits
`tvp.migration-status/v1`; `--migration --family zlib` shows exact release rows.
Declared-broken canonical releases and public variants are included in the ordinary
policy denominator and labelled separately. Production adapters, bases, bootstrap
and compositions remain outside it, requiring separate audits. There is no overall
completion percentage or inferred test/admission result.

Facts are baked into a context-free manifest during Nix evaluation. Starting via
`nix run` may evaluate and build the small CLI once; executing its installed
`bin/tvp-status --migration` only reads that manifest with selected TVP Python.
It never evaluates, builds, realizes, queries Nix or traverses the store. Existing
no-argument status and legacy `--json` retain their store measurement behavior.
`--help` explains migration options without measuring the store.

Private workflow evidence is opt-in only:
`nix run .#status -- --migration --workflow /absolute/progress.json`.
No workflow file is discovered automatically or included in the store manifest.
The schema-1 adapter displays a small allowlist of claims: pause/current step,
accepted older ports and their distinct qualification categories, pending batches,
CI, hardening/split gates and downstream holds. Missing values stay unknown;
invalid counts or inconsistent accepted accounting fail. Family filtering affects
repository facts only. Workflow and outside-scope facts remain global.

Workflow binding compares available path/revision/tree/NAR fields in
`workingBaseline` against the baked source. It reports `matching-source`,
`different-source` or `unbound`, with the recorded baseline and update time.
A tooling-only commit can differ from a previously qualified workflow baseline.
Even a matching binding certifies neither fresh execution nor acceptance. Selected
source-base metadata does not prove all bootstrap inputs are source-built; strict
split eligibility does not close full-validation, hardening or default-switch gates.

Focused tests (with Python already available):
`python3 -B -m unittest discover -s tools/status -p 'test_*.py'`.
Packaged boundary/sentinel tests:
`python3 -B tools/status/smoke.py /absolute/path/bin/tvp-status`.
These tests do not build packages or run migration validation.
