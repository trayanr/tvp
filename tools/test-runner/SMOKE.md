# Focused smoke validation

Default testing answers whether the selected installed results work. Follow the
repository [testing policy](../../TESTING.md): a couple of useful checks per
package or representative builder. Catalogue mode covers every supported
release and PHP extension pair. Full upstream suites remain opt-in.

```sh
nix run .#test -- all
# Terminal JSON for automation; the same standard scope is used by CI:
nix run .#test -- all --json
nix run .#test -- status
# Narrow within the smoke selection:
nix run .#test -- all --only perl_5_30_3
nix run .#test -- all --catalogue --only php_8_5_12--redis_6_3_0
```

`all` waits in the foreground and exits zero only if every selected check passes.
Nix skips valid cached results and builds or substitutes missing outputs. Failed
checks do not cancel independent work. The command uses Nix's configured jobs
and cores without an extra preparation loop. Logs, `state.json` and terminal
`result.json` remain in `.tvp-tests/latest/` for inspection. `--json` prints the
terminal result, including the exact `run` and `runner` paths. Interrupting or
killing the foreground command stops its worker. `start` and `wait` remain
available for explicitly requested background execution.

New run plans carry display labels with both the PHP and extension versions,
and distinguish compilation, finalization, runtime composition and actual tests.
For example: `PHP 8.2.30 / Redis 6.0.2: compiling extension (38s)`.
Script-generation derivations are grouped under `Build scripts` rather than
listed as separate packages. These are display changes; package names and store
identities stay unchanged, and older run plans remain inspectable.

Live progress and `status` show separate totals for compilation, finalization,
unsplit builds, and assembly alongside suites and tests. These totals count
distinct derivations of package stages the frozen plan identifies from selected
tests. Other prerequisites can still appear in the active Nix build list.
Stages with valid outputs are ready. A stage can also be covered by a downstream
output, for example when a cached final package lets Nix skip its compilation
artifact. JSON receipts keep these counts in `stageCounts`. For linked retries,
the stage counts identify the participating attempt they describe.

The event log records when the runner observes Nix activity start and stop.
Those timestamps provide duration data for future estimates.
The heartbeat shows Nix planning before the first build or transfer, lookup
and copy counts when Nix reports them, and outstanding work grouped by kind.
Outstanding remote activities can exceed the builder's concurrent slots.
Output-ready and passed counts still use Server store validity.

The exact selection lives in [tests/smoke.nix](../../tests/smoke.nix). It reuses
existing named test derivations: C/C++ for GCC4/9/13/16 full bases, Perl's version
and compiled module loading, Ruby's version and standard library, Redis's own
checks, FreeTDS's client library and configuration checks, and two checks for
the newest compatible extension per family on the latest PHP. The plan metadata reports the
actual counts for the selected checkout.
No upstream regression test is included. Update this
explicit selection when the changed package needs different representative checks;
do not infer a policy from test names or silently include its whole suite.

Catalogue validation runs the complete declared PHP extension matrix. Local work can use
`--catalogue --only` to select one pair. Missing cached outputs may require compilation of
historical PHP engines and extensions; valid builds and test results are reused.

`smokeTests.<system>.metadata` describes the selection;
`smokeTests.<system>.all` builds it directly. The normal runner freezes
`smokeTestPlans.<system>` and retains its existing ownership, cancellation,
reporting and Nix cache reuse. Smoke state and launch receipts declare
`validationScope = "smoke"` and `full = false`. This is not full certification.
The existing full verifier deliberately cannot certify smoke receipts.

```sh
# These broader operations are explicit requests, never smoke defaults:
nix run .#test -- start --full
nix run .#test -- start --full --only perl_5_30_3
nix run .#test -- latest start --help
```

`--only` selects complete jobs from the chosen plan. In smoke mode those jobs
contain only the declared smoke leaves. With `--full`, a package job can include
its entire upstream suite. `latest` also retains all selected packages' own tests;
it does not mean a couple of checks.

The trusted Buildbot harness in `tvp-infra` pins this runner and checks each
terminal receipt. In catalogue mode it uses `smokeTests.<system>.all` as the
early check and reports `tvp/catalogue` after catalogue and NAS verification.
Smoke-only deployments report `tvp/smoke`.
