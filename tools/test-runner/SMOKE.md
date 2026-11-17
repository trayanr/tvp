# Focused smoke validation

Default testing answers whether the selected installed results work. Follow the
repository [testing policy](../../TESTING.md): a couple of useful checks per
package or representative builder, including every declared compatible PHP
extension pair in standard testing and CI. Full upstream suites remain opt-in.

```sh
nix run .#test -- all
# Terminal JSON for automation; the same standard scope is used by CI:
nix run .#test -- all --json
nix run .#test -- status
# Narrow within the smoke selection:
nix run .#test -- all --only perl_5_30_3
nix run .#test -- all --only php_8_5_12--redis_6_3_0
```

`all` waits in the foreground and exits zero only if every selected check passes.
Nix skips valid cached results and builds or substitutes missing outputs. Failed
checks do not cancel independent work. The command uses Nix's configured jobs
and cores without an extra preparation loop. Logs, `state.json` and terminal
`result.json` remain in `.tvp-tests/latest/` for inspection. `--json` prints the
terminal result, including the exact `run` and `runner` paths. Interrupting or
killing the foreground command stops its worker. `start` and `wait` remain
available for explicitly requested background execution.

The exact selection lives in [tests/smoke.nix](../../tests/smoke.nix). It reuses
existing named test derivations: C/C++ for GCC4/9/13/16 full bases, Perl's version
and compiled module loading, Ruby's version and standard library, Redis's own
checks, and all 296 declared compatible PHP/PHPRedis pairs. The matrix contributes
592 load and Unix-socket roundtrip checks; the seven other subjects contribute
14 checks, for 606 named tests across 303 subjects.
No upstream regression test is included. Update this
explicit selection when the changed package needs different representative checks;
do not infer a policy from test names or silently include its whole suite.

Standard CI runs the complete declared PHP extension matrix. Local work can use
`--only` to select one pair. Missing cached outputs may require compilation of
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

CI explicitly requests `--smoke` and posts `tvp/smoke`. The trusted harness rejects
launch or terminal scope mismatches. Deploy the reviewed harness and matching tools
revision, then change the protected context from `tvp/full` to `tvp/smoke` while
keeping strict up-to-date and other branch protections. Never fabricate a full pass.
