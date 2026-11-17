# Focused smoke validation

Default testing answers whether the selected installed results work. Follow the
repository [testing policy](../../TESTING.md): a couple of useful checks per
changed package or representative builder, with broad suites only on explicit request.

```sh
nix run .#test -- start --json
# Equivalent explicit scope, also used by CI:
nix run .#test -- start --smoke --json
nix run .#test -- status
nix run .#test -- wait
# Narrow within the smoke selection:
nix run .#test -- start --only perl_5_30_3
```

The exact selection lives in [tests/smoke.nix](../../tests/smoke.nix). It reuses
existing named test derivations: C/C++ for GCC4/9/13/16 full bases, Perl's version
and compiled module loading, Ruby's version and standard library, and Redis /
PHPRedis loading and roundtrips. Sixteen named tests run across eight subjects.
No upstream test is included. Update this
explicit selection when the changed package needs different representative checks;
do not infer a policy from test names or silently include its whole suite.

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
