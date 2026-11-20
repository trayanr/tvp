# Testing policy

The default question is: **does the installed package work?** Use a small number
of focused smoke checks, normally two or three for each changed package. This is
the owner's policy as of 2026-11-17 and supersedes earlier migration instructions
that treated full catalogue or upstream runs as automatic completion gates.

## Normal changes

```sh
# Quick installed checks on representative releases:
nix run .#test -- all
# Every supported release and PHP extension pair:
nix run .#test -- all --catalogue
# Narrow it to the changed subject:
nix run .#test -- all --only perl_5_30_3
# Or one exact PHP/extension pair from the matrix:
nix run .#test -- all --catalogue --only php_8_5_12--redis_6_3_0
```

`test all` is the standard foreground command, also used by CI. It submits the
declared checks to Nix, reuses valid local or substituted results, waits for
independent checks even after a failure, and exits zero only when they all pass.
It uses the machine's Nix concurrency settings. Logs and the terminal result are
retained under `.tvp-tests/latest/`; separate preparation and wait commands are
not needed. `test start` remains available for background execution.

Both commands default to the smoke selection in [`tests/smoke.nix`](tests/smoke.nix).
It checks the newest compatible release of each extension on the latest PHP,
alongside checks for the four
compiler bases, Perl, Ruby, Redis and FreeTDS. Use
`nix eval --json .#php.metadata` for current pair counts and
`nix eval .#smokeTests.x86_64-linux.metadata.namedTests` for the smoke test count.
Catalogue CI runs after smoke. It covers every supported release and public
variant, including all PHP extension pairs. It requests named package and artifact
outputs explicitly. A release without installed tests fails plan evaluation.
Declared-broken releases are reported separately. The required catalogue CI
result also includes verified publication to the signed NAS cache.
[`SMOKE.md`](tools/test-runner/SMOKE.md) explains the commands and receipts.

- Reuse existing package outputs and passing checks when their exact derivation
  identities are unchanged. Test-only changes must not rebuild compilation
  artifacts; finalization changes should reuse the compiled artifact.
- Check the installed result and the behavior affected by the change. Prefer
  existing named test derivations over a whole package batch: a batch may include
  a large upstream suite.
- For focused local work, usually test the current release. Add a representative
  historical boundary only when the changed builder or interface spans different
  source layouts.
  CI owns catalogue-wide execution.
- Run cheap, relevant source checks when useful. Avoid building a new test
  framework or repeating broad validation for a narrow correction.

Examples of sufficient smoke coverage:

| Package | Focused checks |
| --- | --- |
| Perl, Ruby, Python | Run a small program; load a core module relevant to the change. |
| C/C++ compiler base | Compile and run C; compile and run C++ with an exception. Inspect the resulting binary for the requested/default hardening. |
| Compression/archive tool | Compress or archive a tiny fixture and recover identical bytes. |
| Library | Compile and run one small consumer through its installed interface. |

Expand only when a failure or a material uncertainty warrants another targeted
check. Keep real failed assertions visible; do not weaken them to obtain a pass.

## Explicitly requested comprehensive testing

Full upstream regressions and complete upstream package suites are **opt-in**.
Catalogue CI runs installed checks. Do not start upstream suites merely to
finish migration, review a recipe, refresh a cache, or merge a change. Perl's
million-test upstream regression run is an example of work that is not a normal
package smoke check.

Keep those suites available for explicit requests. Report their status honestly:
passing smoke checks does not mean that an unrun full suite passed, and does not
waive historical failures or separate policy holds. CI names and required checks
must describe the selected scope; do not publish a synthetic full-suite pass.
`test start --full` selects the old comprehensive plan. `--full --only PACKAGE`
still selects a complete package suite and can include its upstream tests.
`test latest` is also broader than smoke; do not use it as an automatic fallback.

## Build resources

Use Nix's normal concurrency for ordinary work and reuse valid outputs from
configured signed caches. Sequence heavy compilation when resource constraints
call for it. CI uses the configured Nix builders.

Production build, install and test commands take their concurrency budget from
`NIX_BUILD_CORES`; Nix controls the number of simultaneous derivations through
`max-jobs`. Avoid literal worker counts and hidden serial defaults. Fix missing
prerequisite ordering directly when parallel execution exposes a race. Explicit
test fixtures may use fixed counts to verify jobserver or override behavior.
Document genuine early-bootstrap ordering constraints separately. Check actual
build commands as well as Nix configuration when investigating slow execution.
