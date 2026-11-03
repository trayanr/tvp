Canonical JSON-C 0.19 and `variants.build-steps.json-c_0_19` use the same
`tvp.builder` recipe. Customize arguments with `.override`, specification data
with `.edit`, or the ordered plan with `.editSteps`:

```nix
package.editSteps (tvp.builder.steps.insertAfter "json-c.build" [
  { name = "local.log"; run = "echo built >&2"; }
])
```

The explicit plan unpacks the selected release, applies the POSIX byte fixture
patch, prepares the selected test shell, then configures, builds, checks and
installs with `steps.cmake`. It preserves Unix Makefiles, the selected Make
executable, Release, libdir=lib, disabled package registries and the generator's
install target. `cmakeOptions` holds editable flags and source/build directories.
The selected CMake tool contributes pure prefix discovery over
declared library interfaces and the selected base libc. Native environment
prefixes use colons; CMake cache lists use semicolons.

All 28 upstream CTest cases run by default. `doCheck = false` skips test-shell
preparation and execution; disabled command payloads remain lazy. Shared/static,
app, pointer and patch options retain upstream defaults. Upstream builds the
json_parse app but does not install it. The output has headers, both libraries,
pkg-config and relative CMake exports, with no installed CLI.

Compilation installs an internal artifact. One explicit split starts a fresh
final workspace: copy independently, relocate only `.pc` text, strip ELF and
archives, restore the archive index, configure RPATHs, publish the public
development interface, and check symlinks and runtime paths. The source epoch
is exported in `nix-support/source-date-epoch`. Nix rejects references from the
finished output back to its internal artifact.

JSON-C requires base/self/libm only. `runtime.libraries` stays empty; conflicting
or unknown runtime settings fail. `runtime.dlopenDirectories` configures
additional ELF lookup directories through `.editRuntime`, without claiming new
linkage. Finalization edits reuse the complete compilation derivation. Installed
shared/static C, pkg-config and CMake consumers test the final copied output.

The owned path executes no inherited setup or phase hooks. Each named command
has a fresh shell and temporary directory. Argument overrides replay accumulated
specification, step and runtime edits; tests and provenance bind to the edited
output. There is no `withBuildSteps` or `overrideAttrs` interface. Coverage is
native x86_64 Linux with the selected modern CMake and GNU Make.
