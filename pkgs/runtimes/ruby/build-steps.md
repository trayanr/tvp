# Owned Ruby procedures

Start with the [owned authoring guide](../../../lib/NATIVE-RECIPES.md) for the
builder API. The public Ruby 4.0.6 [definition](default.nix) selects
[owned/build-4.0.6.nix](owned/build-4.0.6.nix). Its build-steps variant uses that
procedure with a separately selected retained base; do not assume the canonical
and variant specifications have the same base.

The production plan prepares source, configures, compiles and installs, then
splits at `ruby.finalize`. Finalization copies the artifact, relocates embedded
prefixes, repairs launchers and ELF lookup, compresses manuals and checks paths.
Compiled load paths require Ruby's explicit [finalizer](owned/finalize.py);
generic text relocation alone is insufficient. Final-only provider edits can
reuse compilation when they do not change any prefix command or input.

Use `.override { zlib = tvp.canonical.zlib_1_3_1; }` to replace a declared build
input. Use an actual current step name for procedure edits, for example:

```nix
ruby.editSteps (tvp.builder.steps.insertAfter "ruby.relocate" [
  { name = "local.verify-ruby"; run = ''test -x "$out/bin/ruby"''; }
])
```

Edits replay after argument overrides. Tools, library providers and JIT flags
are explicit constructor/specification data. Disabling both YJIT and ZJIT
removes Rust from active tools and dependency declarations. Named
`runtime.openssl`, `runtime.zlib`, `runtime.libyaml` and `runtime.libffi` select
scoped ELF providers. `runtime.libraries` is their derived summary; edit the
supported named providers rather than replacing that summary. Changing lookup
paths does not relink extensions or prove ABI compatibility.

Installed tests consume the final Ruby. The bounded upstream `test-basic` test
is an independent [test leaf](tests/upstream.nix) in the normal suite, not a
`ruby.check` production step. A failed upstream leaf keeps the batch red without
invalidating the artifact or final package. This is a bounded check, not the full
Ruby upstream suite. Test factories and native controls live in [tests](tests);
version-specific JIT, gem, extension and host limitations remain explicit there.
