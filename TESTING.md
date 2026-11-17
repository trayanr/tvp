# Testing policy

The default question is: **does the installed package work?** Use a small number
of focused smoke checks, normally two or three for each changed package. This is
the owner's policy as of 2026-11-17 and supersedes earlier migration instructions
that treated full catalogue or upstream runs as automatic completion gates.

## Normal changes

```sh
# Declared installed checks, including the PHP extension compatibility matrix:
nix run .#test -- start --smoke --json
# Narrow it to the changed subject:
nix run .#test -- start --only perl_5_30_3
# Or one PHP/extension pair:
nix run .#test -- start --only php_8_5_12--redis_6_3_0
```

`test start` defaults to this smoke scope. The selection in
[`tests/smoke.nix`](tests/smoke.nix) contains 606 named checks across 303
subjects: two checks for each of 296 declared compatible PHP/extension pairs,
plus 14 checks across the four compiler bases, Perl, Ruby and Redis.
The owner approved the PHP extension matrix as part of standard testing and CI.
It covers every declared compatible pair, including historical PHP versions,
with small load and functional checks rather than upstream regression suites.
Other package families retain their representative smoke selection.
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
  The declared PHP extension matrix above runs in standard CI; do not expand
  other families to every version merely because they have many releases.
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

Full upstream regressions, complete package suites, other historical matrices
and the full catalogue are **opt-in**. The approved PHP extension matrix above
is part of standard testing without `--full`; it does not enable upstream
regressions. Do not start the broader suites merely to finish migration,
review a recipe, refresh a cache, or merge a smoke-validated change. Perl's
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

Use Tower's normal settings for ordinary work. Sequence heavy compilation when
needed; do not globally reduce normal concurrency. Reuse Tower and the signed NAS
cache instead of rebuilding valid outputs on the smaller CI machine.
