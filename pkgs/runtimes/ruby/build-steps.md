# Opt-in Ruby 4.0.6

`variants.build-steps.ruby_4_0_6` uses the canonical source, GCC 16 base,
libraries and default YJIT/ZJIT choices. The canonical package is unchanged.
Its inline `steps.sequence` plan includes source layout, configure/build,
upstream `test-basic`, gem directory preparation, installation, consumer setup
metadata and selected output operations. This is native x86_64 Linux only.

Use `.override { zlib = tvp.packages.zlib_1_3_1; }` to change recipe inputs.
Use `.editSteps (steps.replace "ruby.check" (old: old // { enabled = false; }))`
to edit a named record. Edits replay after overrides. Tools, libraries, JIT
flags and `doCheck` are recipe arguments. Disabling both JITs removes Rust from
active tools and dependency declarations without evaluating it.

The generic native adapter accepts inert `passthru` data, with runner-owned
`tvp`, `runtime` and `buildStepRunner` taking precedence. Recipes supplying
passthru get final metadata and tests mirrored in `.passthru` on the package,
`.out` and `.all`, including customized packages. `dependencyNames` can be a
list or a function of the resolved specification; existing list calls retain
their behavior. Ruby's consumer setup hook is an explicit compatibility record.

The ELF helpers accept optional positive `elfKinds`: `runtime` or
`relocatable`. Omitting it retains the old runtime-only implementation exactly.
The new selection validates native objects even when excluding them, strips
selected objects with declared binutils, and gives only runtime ELF to RPATH
operations. Objects cannot be selected for RPATH operations. Tool failures and
malformed ELF fail the build. The unchanged runtime operations still validate
headers, selected RPATH tools and runtime lookup paths.

Ruby installs 32 objects as bundled gem sources. They retain debug stripping;
99 runtime ELF files receive stripping, RPATH shrinking and lookup-path audits.
No archive operation is selected. The two known manuals preserve `gzip -c -n`
compression, whether rbinstall supplies plain or already compressed pages.
Executable Ruby launchers, including nested gem launchers, select this output's
`bin/ruby`. Nonexecutables, templates, examples and other interpreters retain
their bytes. This intentionally improves nested launcher behavior in an empty
environment; it is an observable change from the canonical control.

The 16 shared Ruby consumers remain attached, including the independent GCC 13
extension consumer, JITs, gem discovery and extension linkage. Additional tests
check the actual runtime closure, empty-environment launchers and setup-hook
discovery. `checks.ruby-build-steps` covers metadata, customization, lazy Rust
selection and focused native object/manual fixtures. `test-basic` is a bounded
upstream check, not the complete upstream suite.
