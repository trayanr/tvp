# Writing an owned recipe

Start here for the current `tvp.builder` API. [STRUCTURE.md](../STRUCTURE.md)
defines catalogue layout, release routing and admission rules. The
[output helper reference](native-output-steps.md) and
[test reference](owned-tests.md) describe the focused APIs. Retained construction
procedures are separate controls, not templates for new recipes.
The supported execution target is native x86_64 GNU/Linux.

## A complete small example

[examples/native-recipe.nix](examples/native-recipe.nix) is a standalone example
using the explicitly selected [source-GNU base](../bases/source-gnu/README.md).
It compiles a C program, installs `out` and `bin`, splits before packaging,
creates a launcher from an editable runtime message and attaches two installed
tests. It imports neither nixpkgs nor the ordinary catalogue.

From the repository root, inspect or build the example:

```sh
nix eval --offline --raw --file lib/examples/native-recipe.nix package.artifact.drvPath
nix build --offline --file lib/examples/native-recipe.nix package
nix build --offline --file lib/examples/native-recipe.nix batch
```

Evaluation does not compile. Building may realize the example's selected base and
tools if they are absent; `--offline` prevents fetching, not local dependency
builds. This example's tests exercise its installed program and metadata. They
do not qualify the compiler, other recipes or historical releases.

The essential plan is visible in the recipe:

```nix
plan = [
  # Configure/build/install with explicit environment records.
  (steps.split "example.finalize")
  (outputs.copyArtifacts {
    coreutils = final.coreutils;
    outputs = final.outputs;
  })
  (outputs.template {
    python = final.python;
    output = "bin";
    path = "bin/example";
    template = launcher;
    values = { /* explicit template values */ };
  })
];
```

This excerpt shows the boundary; the linked file includes the enabled commands
on both sides and the complete template values required for evaluation.

## Specification and customization

A procedure accepts an attribute set of constructor arguments and returns either
specification data or `final: { ... }`. `final` is the effective specification
after edits. Publish editable fields explicitly and derive command records from
the selected environment:

```nix
(final.base.environment final.environment) // {
  name = "example.build";
  run = ''"$CC" ${final.src} -o answer'';
}
```

`environment`, named `environments`, `runtime` and `plan` are specification data.
Their exact fields are defined by each recipe. Adding an arbitrary field with
`.edit` does not make it an operative input. Dependency metadata must describe
the same effective providers consumed by commands.

| Operation | Use it for |
| --- | --- |
| `.override { dependency = replacement; }` | Replacing a declared constructor argument. A function of current arguments is also accepted. |
| `.edit (spec: spec // { ... })` | Editing fields the procedure explicitly publishes and consumes. |
| `.editRuntime (runtime: runtime // { ... })` | Editing that recipe's supported runtime choices. |
| `.editSteps (steps.replace "name" update)` | Replacing a named operation; insertion, deletion and disabling use the same editors. |

Edits accumulate in order and replay after argument overrides. Unknown constructor
arguments, missing step targets and duplicate step names fail. Tests, provenance
and named-output projections are reconstructed from the customized package.
`overrideAttrs` is not an owned-package API.

For a real dependency replacement, with `tvp` already imported:

```nix
tvp.canonical.mpfr_4_2_2.override {
  gmp = tvp.canonical.gmp_6_2_1;
}
```

GMP is a compilation dependency, so this may change the artifact and final output.
The example does not promise compatibility for arbitrary replacement versions.

For a final-only change in the standalone example:

```nix
let example = import ./lib/examples/native-recipe.nix { };
in example.package.editRuntime (runtime: runtime // { message = "custom answer"; })
```

Its compiled program stays exact; only packaging and the rebound tests change.
Runtime edits to another recipe preserve compilation only when its active prefix
does not consume those fields. An ELF lookup edit does not relink code or prove
ABI compatibility. Ruby, for example, exposes named runtime providers and derives
`runtime.libraries` from them; callers edit a supported named provider.

## Splits and named outputs

Every new or migrated package needs an artifact/finalization split. Put source
preparation, configuration, compilation and installation before it. Put installed
path relocation, stripping, interpreter/RPATH repair, wrappers and final checks
after it. Upstream-test construction, execution and acceptance belong in separate
validation derivations, not in either production stage. A failed upstream test
must still fail the normal batch while allowing the package to be built.

The prefix produces `package.artifact`. The suffix runs in a fresh workspace.
Required handoff files must be retained explicitly; process state does not carry
across steps. Each command has a fresh shell and temporary directory. The runner
owns logging, failure and cancellation handling; there are no inherited phase or
setup hooks. One split is supported, with enabled commands on both sides.

The default output list is `[ "out" ]`; `[ "out" "bin" ]` and other declared
named outputs work with the same split. Names must be unique, context-free,
nonreserved lowercase shell identifiers, with `out` first. All artifact outputs
share one derivation; all final outputs share another. Every command receives the
declared output paths. Multioutput variables are readonly and cannot be set in
step `env`.

Pass `outputs = final.outputs` to `outputs.copyArtifacts` for either one or several
outputs. Installed repair helpers accept `output = "bin"`, defaulting to `"out"`.
Relative selectors and self paths then belong to that output. Text and
authoritative RPATH rebasing use its matching artifact prefix; sibling-output
mappings require explicit recipe policy. Repeated operations need distinct step
names. See the [helper reference](native-output-steps.md) for selectors and limits.

The runner supplies readonly `TVP_ARTIFACT_ROOT` and, for named splits,
`TVP_ARTIFACT_OUTPUTS`. Recipe authors normally consume these through the copy and
repair helpers. Every final output must exclude references to **all** artifact
outputs; Nix enforces this, including sibling artifacts. `package.artifact` is a
build handle, not a runtime dependency. Compiled prefix/length fields and other
binary formats require a source-bound relocation operation; generic text repair
does not handle them.

## Tools, libraries and tests

Select a base explicitly. `base.environment` supplies the compiler, shell and
baseline tools; name additional tools and libraries in the recipe's environment.
Tools can contribute pure `buildEnvironment` data. Public library requirements
belong in `development`; runtime lookup providers remain separate. No provider
executes hooks or recursively activates arbitrary tools. See
[source-GNU](../bases/source-gnu/README.md) for native platform and base selection,
and [STRUCTURE.md](../STRUCTURE.md#inputs-discovery-and-runtime-roles)
for provider composition.

Attach a required test factory to a catalogue definition. Use
`tvp.lib.tests.fromPackage { builder = tvp.builder; inherit package; }` so tests
follow the effective base, Bash and Coreutils. The standalone example shows this
as `testContext` plus `mkTests`. Its suite is an attribute set of named leaves;
`mkBatch` links those exact leaves. Installed tests consume the final package,
and an independent strict upstream leaf remains in the normal suite when required.

Tests declare an exact `expected` string. Stdout is the compared result; send
diagnostics to stderr. A failed command remains a failure even if a later command
could print the expected result. Test-script or expectation edits should not
invalidate package compilation. The [test reference](owned-tests.md) covers
tools, libraries, environment overrides and current customization limits.

For catalogue integration, keep source hashes and version tables in the family
definition, complete version-start procedures in their own files, and tests in
the family test factory. [MPFR's definition](../pkgs/libraries/mpfr/default.nix)
and [procedure](../pkgs/libraries/mpfr/build-4.2.2.nix) illustrate the current call
interface. Version-specific upstream nonpasses, unavailable host capabilities,
binary adapters and frozen construction controls retain their explicit limits;
source evaluation or a passing installed test does not waive them.
MPFR's retained inline upstream check is isolation debt; its call interface does
not make that check placement a template for new procedures.
