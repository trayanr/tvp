# Writing an ordinary package family

Use `tvp.lib.packages.mkFamily` for new ordinary families. MPFR is the first
migrated family. [STRUCTURE.md](../STRUCTURE.md) defines repository layout and
admission rules; [output helpers](native-output-steps.md) and
[owned tests](owned-tests.md) describe the focused execution APIs.

## Definitions contain the actual choices

Each definition states its complete procedure and additional dependencies. Copy
these records where needed so each can be read independently. Avoid a shared
`common` definition or a version-switching procedure merely to reduce repetition.

```nix
defs = {
  "4.2.1" = {
    builder = ./ordinary/build-4.2.1.nix;
    deps.gmp = tvp.packages.gmp_6;
  };
};
```

Real compatibility options or patches stay beside their definition, with their
reasons. Release blocks select a definition and supply versions and source hashes.
See [MPFR's definitions](../pkgs/libraries/mpfr/default.nix) and
[release blocks](../pkgs/libraries/mpfr/releases.nix).

## Register sources and tests once

The family entry point connects the table to one source factory and one test suite:

```nix
family = tvp.lib.packages.mkFamily {
  pname = "mpfr";
  inherit defs;
  releases = import ./releases.nix;
  source = { version, sha256 }: import <nix/fetchurl.nix> {
    url = "https://mirrors.kernel.org/gnu/mpfr/mpfr-${version}.tar.xz";
    inherit sha256;
  };
  tests = import ./tests/family.nix;
};
```

It returns `canonical`, `aliases` and `recipes.<pname>`. The release function
receives `{ defs }` with the constructor's definition names attached. A test
function receives `{ package, lib, context }`. It returns named test derivations,
usually through `context.mkSuite`; capability-specific tests use the effective
package's declared features. Each release gets tests of its own final output.
Writing the suite once does not reuse another version's test result.

The test runner is shared globally. MPFR's version, arithmetic and optional
Float128 assertions are declared once in [its suite](../pkgs/libraries/mpfr/tests/family.nix).
Independent upstream acceptance stays a normal test leaf. Diagnostics go to
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

Only arguments declared by a procedure are supplied. There is no host PATH
search, hook execution or arbitrary dependency discovery. Package-specific tools
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

Older `mkVersions` callers retain their explicit constructor/base/helper protocol
while they are migrated. Frozen construction modules keep their complete pinned
calls. They do not silently acquire ordinary defaults. Direct `tvp.builder` calls
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

Use argument overrides to replace a base or dependency. A generic specification
edit retains its constructor arguments; adding an unused field does not create
an operative input. Commands and dependency metadata must read the same effective
published providers.

The family test factory is overridable with `tests`; replacing that suite changes
validation, not package compilation. Retained factories keep their historical
interfaces. The [test reference](owned-tests.md) distinguishes these factories
from individual test derivations.

## Procedure and split boundaries

Procedures remain complete independent version-start files. They receive resolved
`src`, `version`, providers and helpers and return `final: { ... }` specification
data. Their ordered `plan` contains named records and one `steps.split` marker.
Source preparation, compilation and installation produce the artifact. Output
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
or known upstream failures; the new entry point does not waive them. MPFR's later
procedures still have retained inline upstream checks. Source evaluation, a
working compiler or an installed test does not establish full historical,
platform, hardening or catalogue qualification.
