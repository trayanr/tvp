# TVP CI

## Run the standard checks

```sh
nix flake check --no-build
nix run .#test -- all
nix run .#test -- all --catalogue --only php_8_5_12--redis_6_3_0
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
when to run catalogue checks and opt-in upstream suites. The complete PHP
extension compatibility matrix runs in catalogue mode.

## Review and merge a PR

1. Ensure the branch contains its current target tip. CI automatically
   considers repository-owned PRs, including drafts and stacked PRs.
2. Open the required TVP check for the exact PR head. Review unexpectedly changed package
   producers in the graph report and use the failing suite's log to diagnose
   a check.
3. If the target advances, update your branch and wait for its new head's
   check. Squash-merge the reviewed head after the required check passes.
   Master receives separate validation. Smoke-only deployments post `tvp/smoke`.
   Catalogue deployments post `tvp/catalogue` after NAS verification.

The [infra repository](https://github.com/trayanr/tvp-infra) owns Buildbot
configuration, deployment, and cache publication. TVP owns the package and
test plans invoked by CI.
