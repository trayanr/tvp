# Writing an ordinary package family

This is the agreed authoring model for new ordinary families and for cleaning up
existing ones. Use `tvp.lib.packages.mkFamily`; MPFR is the complete reference.
The earlier migration to owned, split producers did not convert every family to
this authoring interface. The [rollout plan](AUTHORING-MIGRATION.md) records the
remaining base and package work.

[STRUCTURE.md](../STRUCTURE.md) defines repository layout and admission rules;
[output helpers](native-output-steps.md) and [owned tests](owned-tests.md) describe
the focused execution APIs.

## The package shape

MPFR has one family index, two complete era builders and one test suite:

```text
mpfr/
  default.nix
  build-2.4.2.nix
  build-4.0.2.nix
  tests/
    default.nix
    restore.py
    fixtures/
```

| Location | Responsibility |
|---|---|
| `default.nix` | Complete `packageRecipes` records, literal versions/hashes, one source factory, one test factory, canonical packages and generated aliases. |
| `build[-VERSION].nix` | A complete ordered procedure, its stable feature/layout/interface facts, package-specific inputs and small customization arguments. |
| Selected base | Compiler, libc/runtime, platform, Bash/Coreutils, standard tool choices and environment contributions. |
| Shared `lib/` | Execution, step/output helpers, provider tracking and test construction. |
| Package `tests/` | Assertions, fixtures and independent upstream execution/acceptance for the effective package. |

The ordinary family index lists builders and package-specific TVP dependencies.
It does not repeat the constructor, platform, base selection, standard tools or
helper/test wiring. Stable facts belong in the appropriate era builder; small
release exceptions belong in the table. Copy complete recipe records and builders
when a real difference calls for them, rather than hiding choices in a `common`
overlay or importing one era builder into another.

Use `build.nix` if the family has one procedure. Add versioned files for coherent
source/build/install eras, not simply for every release or major version. Extra
directories need a concrete purpose, such as source patches, package-specific
helpers or large release data. Construction inputs and public profiles reuse the
same procedures; they do not need duplicate `ordinary/`, `native/` or retained
implementations.

The builder's `buildFeatures`, `sourceLayout` and `installedInterface` group its
effective facts. Use descriptive groups where they help; these names are not a
requirement to add empty records to every package. Defaults are appropriate for
real local choices. A bundle overridden by every era belongs in separate builders.

The artifact contains compiled/installed production state. The final package adds
output repairs after `steps.split`. Installed tests depend on that final package;
upstream tests restore the artifact in their own derivations. A test-only edit must
not invalidate either production stage. The shared test machinery supplies the
runner; package assertions are written once per family and reused across its
versions, with separate results for different derivations.

## Definitions contain the actual choices

Each definition states its complete procedure and additional dependencies. Copy
these records where needed so each can be read independently. Avoid a shared
`common` definition or a version-switching procedure merely to reduce repetition.
Use `tvp.lib` directly; do not introduce `tvpLib = tvp.lib;` just to shorten access.

```nix
packageRecipes = tvp.lib.packages.mkDefs {
  "4.2.1" = {
    builder = ./build-4.0.2.nix;
    deps.gmp = tvp.packages.gmp_6;
  };
};
```

Real compatibility options or patches stay beside their definition, with their
reasons. Release blocks select a definition and supply versions and source hashes.
See [MPFR's definitions](../pkgs/libraries/mpfr/default.nix) and
[version and hash table](../pkgs/libraries/mpfr/default.nix).

## Register sources and tests once

Keep the version/hash table literal and construct the public sets explicitly:

```nix
versionTable = tvp.lib.packages.mkTable [
  {
    def = packageRecipes."4.2.1";
    releases = {
      "4.2.1" = "sha256-J3gHNTpnJpeJlpRa8T5Sgp46vXqaW3+yeTiU4Y8fy7I=";
      "4.2.2" = "sha256-tnugOD736KhWNzTi6InvXsPDuJigHQD6CmhprYHGzgE=";
    };
  }
];
pname = "mpfr";
family = tvp.lib.packages.mkFamily {
  inherit pname versionTable;
  source = { version, sha256 }: import <nix/fetchurl.nix> {
    url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
    inherit sha256;
  };
  tests = import ./tests;
};
canonical = tvp.lib.packages.mkVersions family;
```

```nix
in {
  recipes.mpfr = family;
  inherit canonical;
  inherit (family) instantiate;
  aliases = tvp.lib.packages.mkAliases { inherit pname versionTable canonical; };
}
```

`mkDefs` names complete definitions; `mkTable` associates each release/hash with
one of them. `mkFamily` supplies context and shared test wiring, returning recipe
arguments for `mkVersions` plus stage-local `instantiate`. Canonical construction
and alias generation remain visible in the package file. There is no releases
callback or second version list.

A test function receives `{ package, lib, context }`. It returns named test
derivations, usually through `context.mkSuite`; capability-specific tests use the
effective package's declared features. Each release gets tests of its own final
output. Writing the suite once does not reuse another version's test result.

The test runner is shared globally. MPFR's version, arithmetic and optional
Float128 assertions are declared once in [its suite](../pkgs/libraries/mpfr/tests/default.nix).
Independent upstream acceptance stays a normal test leaf, built through the shared
`context.mkUpstream { inherit package; }` checkpoint consumer. Diagnostics go to
stderr; stdout is compared exactly with the declared `expected` string. Failed
commands and pipelines stay failures. Expected trailing newlines are not supported.

## What the selected build context supplies

The catalogue binds the ordinary-family context once. Definitions do not repeat:

- the owned constructor;
- the base/compiler and platform selection;
- the standard `tvp` and `lib` helper arguments;
- Bash, Coreutils and Binutils from the selected base;
- Make, Tar, XZ, text tools, Python and Patchelf from `base.standardTools`;
- the test context, derived from the effective package.

Only declared constructor arguments receive defaults. Bound helpers and tools come
from `tvp.builder.forBase final.base`. There is no host PATH search, hook execution
or filesystem-based dependency discovery. Package-specific tools
and libraries belong in `deps`, using TVP package selectors. Common tool selections
live once in the [base's standard tool set](../bases/source-gnu/standard-tools.nix);
MPFR definitions therefore only select GMP and compatibility options.
Resolved standard providers remain visible in `tvp.declaredDependencies`.

A compatible ordinary base exposes `shell`, `coreutils`, `compiler`, `standardTools`,
platform facts and the pure environment interface. Standard defaults are resolved on each
constructor call. `.override { base = otherBase; }` recomputes the default tools;
explicit argument replacements take precedence. Replacing `base.coreutils` through
`base.override` also rebinds its baseline tool slot; an explicit `tools` replacement
remains the caller's complete choice. Named standard-tool overrides merge by role:
`base.override { standardTools.gnumake = otherMake; }` keeps the other standard
providers. Bash, Coreutils and Binutils use their canonical base fields rather than
entries in `standardTools`.

Default resolution remains lazy: a procedure receives the roles it declares, and each
step names the tools it uses. Unused standard providers are not forced or added to
that step's PATH. This preserves bootstrap direction and cache identities. A tool
building itself must select its earlier construction provider explicitly.
The currently bound context is
native x86_64 GNU/Linux. Platform support belongs to that context and to genuine
recipe restrictions, not duplicated conditionals in version tables.

Construction calls use the same family definition before a public package is created:

```nix
family.instantiate {
  version = "4.2.2";
  base = earlierBase;
  deps.gmp = earlierGmp;
}
```

This replaces dependency choices before evaluation, avoiding a lookup of the final
compiler being constructed. `tvp.baseTiers` exposes `seed`, `target`, `native` and
`full` source-owned contexts; `retained` adapts existing construction generations.
See [base tiers](../bases/tiers/README.md). MPFR's old construction recipe has been
removed; other families still keep their earlier interfaces until they are migrated. Direct `tvp.builder` calls
remain available for low-level fixtures and specialized construction work.

## Public dependencies and bootstrap cycles

Ordinary dependencies select `tvp.packages`, including an explicit version line
when compatibility or bootstrapping requires it. Such constraints state why.
Replacing a retained construction tool with an ordinary producer changes the
build inputs and can require rebuilding; identical version numbers do not imply
identical derivations.

For example, the shared base tool set selects Gawk 4.0 because Gawk 5 depends on
MPFR. Patchelf, Gzip and File also need MPFR-free AWK selections when they occur
before MPFR in that dependency graph. Their build-only AWK roles use the public
Gawk 4.0 line. This choice belongs to the base tool policy rather than each MPFR
definition. Bootstrap providers elsewhere still need earlier tools; those choices
remain explicit in their retained construction or compatibility definitions.

## Customization

`.override` replaces procedure arguments, including supplied standard defaults.
A function receives the resolved arguments. `.edit` transforms the published
specification; `.editSteps` and `.editRuntime` transform its plan and runtime.
Edits replay after argument overrides. Unknown arguments, missing step targets
and duplicate names fail. Named outputs and tests follow the customized package.
`overrideAttrs` is not an owned-package interface.

Argument overrides replace package inputs. Base edits also rebind automatic tools,
helpers, commands, metadata and attached tests from the effective specification:

```nix
mpfr.edit (spec: spec // {
  base = spec.base.override { standardTools.gnumake = myMake; };
})
```

Explicit procedure argument overrides retain precedence over defaults. Named steps
remain inspectable and support `editSteps`, including disabling `output.strip` or
inserting a command. Changing a step after the split only changes finalization.

Builder implementations bind helpers once with `tvp.builder.forBase final.base`.
The returned `steps` and `outputs` obtain implementation tools from that base; explicit
helper-call arguments take precedence. A builder therefore needs package inputs such
as `base`, `src`, `version` and `gmp`, rather than repeated Python/Binutils/Make
arguments. The builder collects dependency metadata from the bound providers used
by active steps and the runner. Helpers retain the role of their effective tool
arguments, including explicit replacements. Package authors declare their actual
step tools and package-specific `deps` once; no separate provider record is needed.
Unused standard providers and disabled steps stay lazy. Distinct providers used for
one role are retained as numbered metadata entries such as `gnumake#1` and
`gnumake#2`. Upstream-only plans are collected by their own test derivation, outside
production metadata.

The family test factory is overridable with `tests`; replacing that suite changes
validation, not package compilation. Retained factories keep their historical
interfaces. The [test reference](owned-tests.md) distinguishes these factories
from individual test derivations.

## Procedure and split boundaries

Procedures remain complete independent files. They receive resolved
`src`, `version`, providers and helpers and return `final: { ... }` specification
data. Their ordered `plan` contains named records and one `steps.split` marker.
Keep a coherent source/build/install era in its own builder instead of repeating
the same feature and layout switches in every recipe record. MPFR's
[`build-2.4.2.nix`](../pkgs/libraries/mpfr/build-2.4.2.nix) owns the older layout,
disabled Float128 and absence of pkg-config metadata;
[`build-4.0.2.nix`](../pkgs/libraries/mpfr/build-4.0.2.nix) owns the modern layout,
Float128, pkg-config metadata and SONAME 6. Both contain their complete procedure
and share generic helpers; neither imports or overrides the other. Small exceptions
remain recipe data: the extra `test-driver` in 3.1.6, older SONAME/rounding-name
interfaces and test-only C17 flags. The identical 4.2.1 and 4.2.2 choices share one
recipe record.

The effective specification groups these facts under `buildFeatures`,
`sourceLayout` and `installedInterface`. `.edit` can change a group while keeping
its other fields, for example:

```nix
tvp.packages.mpfr_4.edit (spec: spec // {
  installedInterface = spec.installedInterface // { hasPkgConfig = false; };
})
```

Generic output settings such as `stripFlags` use `.edit` or `.editSteps`; runtime
search directories use `.editRuntime`. They do not need constructor arguments in
each era builder. `.override` still changes declared recipe inputs such as GMP,
the base and upstream test policy.

These builder boundaries describe upstream eras. The artifact/final split inside
each builder describes reusable production stages. Source preparation,
compilation and installation produce the artifact. Output
relocation, stripping, interpreter/RPATH repair, wrappers and audits produce the
final package in a fresh workspace. A failed upstream test must not block either
production stage; its acceptance leaf still keeps the normal test batch red.

Single and named outputs share this boundary. Pass `outputs = final.outputs` to
`outputs.copyArtifacts`. Installed helpers accept `output = "bin"`, defaulting to
`"out"`; relative selectors and self paths belong to the selected output. Every
final output must exclude all artifact paths, including sibling artifacts.
Compiled prefix/length fields require explicit source-bound relocation. See the
[helper reference](native-output-steps.md) for precise behavior and limits.

The [low-level standalone example](examples/native-recipe.nix) demonstrates the
underlying owned constructor and installed-output operations. It explicitly
supplies wiring that `mkFamily` now provides for ordinary definitions. Building
it may realize uncached tools; `--offline` prevents fetching, not local builds.

This is an incremental API migration. Existing recipes may retain isolation debt
or known upstream failures; the new entry point does not waive them. MPFR retains a
compiled checkpoint in its artifact and runs upstream checks independently. The production checkpoint writer and test restore code are separate;
editing the test reader does not change A or F. Check flags and acceptance likewise
remain outside production. Other families may retain earlier isolation debt. Source
evaluation, a working compiler or an installed test does not establish full historical,
platform, hardening or catalogue qualification.
