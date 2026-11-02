Select `variants.build-steps.json-c_0_19` for this private experiment. The
canonical recipe and aliases remain independent. One derivation runs the
source, json-c and output groups through the internal named-step runner.

The package's `withBuildSteps` composition function accepts `doCheck` and an
`editSteps` callback. For example (the executable control is in
`tests/build-steps.nix`):

```nix
trial.withBuildSteps {
  editSteps = plan:
    steps.insertAfter "json-c.build" [
      { name = "local.log"; run = "echo built >&2"; }
    ] (steps.replace "json-c.check" (old: old // {
      run = old.run + "\necho checked >&2";
    }) plan);
}
```

`steps` is `import ../../../lib/build-steps.nix`. Replacement explicitly
preserves fields. Disabled records retain names for editing and disappear
before runner inputs or scripts are projected. The control disables checking,
puts throwing tool/body values on that record, inserts a log between real
build/install operations and replaces installation with an order assertion.
No timings or probe files enter installed outputs.

Support is native x86_64 Linux, the selected modern CMake and GNU Make with
Unix Makefiles, default compiler hardening and one `out`. Source extraction,
patches, test shebangs and the persisted source epoch are explicit. CMake
includes dependency search hooks and the selected compiler's libc prefix,
Release, libdir=lib and disabled package registries. Installation uses the
generator target. Upstream shared/static, app, pointer and patch options stay
at their defaults. Upstream builds the json_parse app but does not install it;
this trial keeps that file list.

Each shell sources the existing base/input setup. The explicit fixup bridge
retains its output hooks: mode normalization, relative symlinks, shebangs,
strip and archive indexing, RPATH shrinking, temporary-path auditing, output
layout and propagation/nix-support. Only the vendored shebang/fixup helpers
run with nounset off; errexit remains on. No pre/post phase hooks order the
plan, and genericBuild is never called. This is neither a public API promise
nor evidence for historical CMake, other generators, cross builds or other
platforms. Unsupported systems omit this variant.
