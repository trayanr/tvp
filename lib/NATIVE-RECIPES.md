The native recipe adapter is an internal, opt-in experiment for one native
output. MPFR 4.2.2 and Fontconfig 2.18.3 have opt-in variants. Existing canonical, frozen and JSON-C
builds use their existing paths.

Recipes are explicit argument functions returning package data and an ordered
plan of named records. `lib/native-recipe.nix` retains the function, current
arguments and ordered edits outside the derivation. For example:

```nix
((tvp.variants.build-steps.mpfr_4_2_2.override {
  gmp = tvp.packages.gmp_6_2_1;
}).editSteps (steps.insertAfter "mpfr.build" [ {
  name = "local.log";
  run = ''echo built >&2'';
} ])).editSteps (steps.replace "mpfr.check" (old: old // { enabled = false; }))
```

Unknown arguments fail. Each override regenerates the recipe and replays all
edits once, in order. Edits precede active selection and input projection;
disabled payloads remain lazy. Both routes rebind tests and dependency metadata,
including output projections. Customized selections are marked as overrides.
Generic `overrideAttrs` is not a supported customization interface. JSON-C's
private `withBuildSteps` keeps its replacement-callback semantics.

The selected base supplies both outer stdenv and child compiler/setup. Tools
map to nativeBuildInputs and libraries to buildInputs in each fresh shell;
inherited setup hooks still provide compiler/search behavior. The helpers
explicitly unpack, set source epoch, configure/build/check/install and finalize.
Finalization calls retained fixup helpers for shebangs, relative symlinks,
stripping/archive indexes, RPATH shrinking, temporary-path auditing and declared
development propagation. This is a bridge, not replacement setup machinery.

This opt-in runner creates and deletes a fresh TMPDIR for each active step after
bounded process-group cleanup. Shared workspace and installed files survive.
Only runner-created directories are deleted. Cleanup failure is reported and
turns success into failure; primary command failures and external cancellation
retain their result. Existing best-effort logs, first cancellation signal and
ordinary non-detaching process-group limits apply. Detached processes are outside
the contract.

`runtime.libraries` is a checked expectation, separate from development
propagation and linker configuration. A test exports only the installed output's
reference graph and compares context-free expected paths against that graph.
It adds no expected-library references to the installed output. The MPFR tests
also compile and run installed consumers, including float128. Closure membership
alone does not establish ABI compatibility. Use runtime output paths explicitly
when a dependency separates development and runtime outputs.

`variants.build-steps.fontconfig_2_18_3` uses the modern native Meson helper.
Its `fontconfig.prepare`, `fontconfig.configure`, `fontconfig.build`,
`fontconfig.check`, `fontconfig.install` and `output.fixup` records are editable.
For example, `.override { doCheck = false; }` skips execution of upstream tests
while retaining their configured targets. Ninja and pkg-config overrides set
`NINJA` and `PKG_CONFIG` explicitly, including when Meson's launcher supplies
embedded defaults. The generator Python remains a separate recipe input from
Meson's interpreter. Source preparation and finalization remain explicit steps.
The installed tests use an isolated BDF fixture and private font/cache paths.
