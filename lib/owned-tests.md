# Owned tests

`tvp.lib.tests.forBase { builder; base; coreutils; }` binds the owned builder,
selected base and explicit Coreutils. Bash comes from `base.shell`. Catalogue
factories select this context explicitly. Retained factories and aggregate test
infrastructure can still use the legacy helpers; selecting this context does not
rewrite those callers.

From the repository root, with the qualified `base`, `coreutils` and `mpc` selected:

```nix
let
  tests = tvp.lib.tests.forBase {
    builder = tvp.builder;
    inherit base coreutils;
  };
  suite = tests.mkSuite {
    package = mpc;
    libraries = [ mpc ];
    tests.arithmetic = {
      script = ''
        "$CC" ${./pkgs/libraries/mpc/tests/fixtures/arithmetic.c} -lmpc -lmpfr -lgmp -o arithmetic
        ./arithmetic
      '';
      expected = "25";
    };
  };
in tests.mkBatch { name = "mpc"; inherit suite; }
```

`mkTest` requires `package`, `name`, `script` and string `expected`. The package's
bin output is on PATH. Additional command tools use `tools`; development and
public transitive dependencies use `libraries`. `environment` supplies explicit
`base.environment` overrides (`values`, `flags`, `paths`). Suite defaults for
these three fields can be replaced by a case declaration. The selected base
supplies the compiler, Binutils, shell, runtime and baseline tools. There are no
setup hooks or inferred dependencies.

On a returned owned test, `.override` currently accepts `package`, `tools` and
`libraries`. `script`, `expected`, `environment` and the test name are captured
when `mkTest` is called. Reconstruct the test or suite to change those options;
they are not additional `.override` arguments. Package customization rebuilds its
attached tests through the package's factory.

The script runs with the owned runner's `errexit`, `nounset`, `pipefail` and
`inherit_errexit`. A failed command or pipeline aborts the test, including an early
failure followed by matching output. Successful stdout has trailing newlines
removed by Bash command substitution and is compared exactly to literal
`expected`; an empty string is intentional and valid. Expected trailing newlines
therefore fail. Mismatches print expected and actual text to stderr. The result
file contains the compared value followed by one newline. Stderr remains a log.

Suites expose only named leaves. Batch links point to those exact outputs and
`testSuite` retains the same leaves for the generic test plan and result verifier.
Names use letters, digits, `.`, `_`, `+`, `-` and start with a letter or digit.
`package`, `testName`, `compiler`, `passthru` and `tvp` provenance remain inspectable;
`tvp.declaredDependencies` records the package/tools/libraries by role. These are
owned outputs with no `stdenv` compatibility interface.

`lib/tests/owned-tests.nix` checks the pure interface.
`lib/tests/owned-tests-native.nix` qualifies real commands, C/C++, providers and
strict failure behavior with the opt-in source GNU base. Its negative derivations
are separate from the passing suite. The attached `owned-tests` check runs their
actual runners in subprocesses, without nested Nix builds.

Ordinary `mkFamily` callers declare their suite once with `tests = import ./tests/family.nix;`.
The function receives `{ package, lib, context }` and uses `context.mkSuite`, normally
with `libraries = [ package ];` and scripts invoking `"$CC"` or `"$CXX"`. Each version
gets distinct tests of its own final output. The shared suite declaration reuses code;
a cached test result is reused only when its derivation identity is unchanged.

The ordinary context comes from the effective package. The family constructor supplies
it, so definitions do not repeat `testContext` or standard test tools. The normal
catalogue builds the batch with that same context. Argument `override`, `edit` and
`editSteps` reconstruct it from the current specification's base, Bash and Coreutils.
Use argument overrides when replacing the base or providers so standard defaults are
resolved together. The family factory supports `.mkTests.override { tests = replacement; }`;
this replaces the suite function, not package compilation.

Retained low-level definitions can still opt in explicitly:

```nix
testContext = package:
  tvp.lib.tests.fromPackage { builder = tvp.builder; inherit package; };
```

A base or shell replacement must provide a compatible native tool interface. Public
development libraries expand transitively. Context functions remain outside serializable
package metadata and named test leaves. The final all-batch and plan writer still use
legacy infrastructure. The new family interface does not rewrite those callers.
