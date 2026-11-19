# TVP CI

## Run the standard checks

```sh
nix flake check --no-build
nix run .#test -- all
nix run .#test -- all --only php_8_5_12--redis_6_3_0
```

`test all` runs the [focused smoke plan](../tests/smoke.nix) in the foreground.
It uses Nix's configured job and core settings, reuses valid outputs, and
returns the result of the exact frozen run. The printed run directory holds
the logs and `result.json`. Local `test status` follows the latest run in its
state directory. Use the GitHub check for a CI run.

To run graph evaluation, flake checking and smoke locally with a dedicated
state directory:

```sh
bash ci/validate.sh .tvp-tests/ci
nix run .#test -- status --state-dir .tvp-tests/ci --json
```

See [TESTING.md](../TESTING.md) for how to choose small installed checks and
when to run opt-in upstream or full suites. The standard smoke plan includes
the declared PHP extension compatibility matrix.

## Review and merge a PR

1. Ensure the branch contains its current target tip. CI automatically
   considers repository-owned PRs, including drafts and stacked PRs.
2. Open `tvp/smoke` for the exact PR head. Review unexpectedly changed package
   producers in the graph report and use the failing suite's log to diagnose
   a check.
3. If the target advances, update your branch and wait for its new head's
   check. Squash-merge the reviewed head after the required `tvp/smoke` check
   passes. Master receives its own smoke validation.

The [CI architecture](ARCHITECTURE.md) explains revision admission, the
validation stages, and the meaning of a passing check.
