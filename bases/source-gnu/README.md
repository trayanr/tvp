# Source-GNU owned base

This explicitly selected native x86_64 GNU/Linux base selects the complete
source-built GCC and its matching C++ runtime. It does not change
`tvp.bases.default` or aliases.
Direct import needs neither nixpkgs nor the ordinary package catalogue:

```nix
let
  candidate = import ./bases/source-gnu { };
  inherit (candidate) base builder tools toolchain;
in {
  compiler = base.compiler;
  shell = base.shell;
  runtime = base.runtimeDirectories;
  environment = base.environment {
    tools = [ tools.make tools.pkgConfig ];
    libraries = [ myLibrary ];
  };
}
```

`builder.base { name; platform; compiler; shell; tools; coreutils ? null; standardTools ? {}; }`
returns pure base data and an environment composer. The ordinary-family context binds
this base once. Bash, Coreutils and Binutils come from its canonical fields; Make,
Tar, XZ, text tools, Python and Patchelf come from its named `standardTools` set.
Version definitions select package-specific dependencies such as MPFR's GMP.

The ordinary catalogue selects public TVP tool roles once in
[standard-tools.nix](standard-tools.nix). Direct source-GNU imports retain independent
construction-tool defaults. A procedure receives only the standard roles it declares;
its steps list the tools they use. Named defaults are lazy and are not appended to
every step's PATH. The existing `tools` list supplies the minimal baseline PATH.
The shell precedes that baseline; explicit step tools precede the floor. Tools may
contribute pure `buildEnvironment` data. The compiler supplies CC/CXX, Binutils
commands, libc and target runtime directories. There are no setup hooks.
The selected linker in `inputs.nix` explicitly contributes GNU ld's indirect
DSO lookup flags; the generic composer does not choose a linker policy.

Replace a whole toolchain with `base.override { compiler = otherDriver; }`.
It reconstructs the environment, commands and runtime directories together.
`base.override { coreutils = otherCoreutils; }` also replaces the previous provider in
the baseline tool list, unless an explicit replacement `tools` list is supplied.
`base.override { standardTools.gnumake = otherMake; }` replaces that named role
while keeping the other standard tools. Bash, Coreutils and Binutils remain tied
to `shell`, `coreutils` and `compiler`; using those names in `standardTools` is rejected.
Tools building themselves must select earlier construction providers explicitly.
A nested record overlay cannot rebind a captured environment. Use
`base.environment { overrides.values.CC = "/explicit/compiler"; }` for an
invocation-specific replacement; this alone does not replace the C++ runtime.
Only the declared native platform is supported. Incomplete or contradictory
compiler metadata fails during construction.

`toolchain` names the raw compiler, selected driver, libc, Binutils and matching
runtime output. `tools` names the retained source-owned Bash, Coreutils, Make,
archive/text tools, pkg-config, Ninja, CMake, Python, Meson, Patchelf, M4, Perl
and Texinfo. They retain their earlier measured host generations. They were
not rebuilt with the full target compiler. Versions come from those selected
package objects. Earlier host dependencies do not become target runtime
providers by being reachable from a build tool.

Start new recipes with the [current authoring guide](../../lib/NATIVE-RECIPES.md)
and its split example. The retained qualification fixture
[tests/consumer.nix](tests/consumer.nix) is deliberately unsplit; it exercises
explicit tools and public library discovery, not the current authoring boundary.
Its definition selects authoritative owned GMP, MPFR, MPC and JSON-C procedures,
with ordinary source-shell and logging
edits in [tests/packages.nix](tests/packages.nix). GMP retains shared and static
archives; MPFR/MPC retain their recipes' shared-only policy. CMake Make/Ninja
and Meson consumers exercise installed interfaces.

```sh
nix build --file bases/source-gnu/tests/packages.nix consumers
nix build --file bases/source-gnu/tests/probes.nix consumer
```

Recipes keep `override`, `edit`, `editSteps` and `editRuntime`. Output operations
consume declared runtime directories. Public development requirements control
header/pkg-config discovery; applications using MPFR symbols directly declare
MPFR as well as MPC. Selecting this base does not establish package qualification
or change the public default base.
Driver construction sharing and retirement of legacy recipe adapters remain
separate work. The retained full-GCC upstream evidence has known failures and
kernel-specific limits; this small consumer qualification adds no broader
compiler-conformance claim.
