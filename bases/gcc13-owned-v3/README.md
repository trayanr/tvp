# Owned native build contract

`bases.default` and `bases.gcc13-owned` select `gcc13-owned-v3`. This is a
consumer protocol revision of v2: GCC 13.3.0, binutils 2.42, glibc 2.39,
the tool floor and patchelf are the same derivations. The old owned and v2
construction environments remain pinned internally. Wrapper constructor defaults
still select the original scripts; the frozen construction identity check guards
against accidentally rebuilding that chain. Public compatibility bases remain
available where packages actually use them.

The supported execution mode is native x86_64 Linux with glibc. Cross compilation,
other architectures and other ABIs are rejected by the existing platform contract.

## Compiler flags and hardening

`NIX_CFLAGS_COMPILE`, `NIX_CFLAGS_LINK` and `NIX_LDFLAGS` use whitespace-separated
words, without shell evaluation or shell quote processing. Pass arguments containing
spaces directly in argv or through response files. Compile flags precede user
arguments; link flags follow them, with the existing driver/linker marker preventing
duplicate additions. The wrappers supply owned headers, library search paths and
the dynamic loader for dynamic executables.

The unchanged hardening defaults are bindnow, fortify, format, pic, relro,
stackprotector and strictoverflow. `hardeningEnable`/`hardeningDisable` retain the
stdenv selection rules, including `hardeningDisable = [ "all" ]`. Structured
attributes' computed arrays become exported scalar values, including an explicit
empty value. Direct `NIX_HARDENING_ENABLE` selects whitespace-separated options;
an unset value selects defaults and an empty value disables them.

Hardening compile flags precede environment and user compile flags, preserving
explicit overrides. Fortify applies when the effective optimization flags enable
optimization, including `-O`, `-Oz`, environment flags and response files. A later
`-O0` disables it. Optional PIE hardening does not override PIC for shared libraries,
relocatable links or static modes.

Response files use GCC's nested, quote and backslash grammar, including GCC's
acceptance of unmatched quotes and trailing escapes at EOF. Original arguments
are forwarded to GCC. Classification uses an owned MIT helper built with the
pinned owned parent. Expansion is limited to 64 nested files, 100000 expanded
arguments and 16 MiB of combined parsing/expansion work. Cycles and I/O errors fail
the wrapper before compilation. Missing files stay literal for GCC to diagnose.
Responses must be stable regular files: devices, pipes, explicit stdin/fd paths
and embedded NUL bytes are rejected. Reading a stream during classification would
consume it before GCC's second read.

Static and static-PIE response flags suppress wrapper-supplied dynamic loader and
runtime paths just as direct flags do. The frozen toolchain has a separate native
limitation: a static PIE with an explicit RPATH can crash even when linked directly
with raw GCC. For such links, clear automatic `NIX_LDFLAGS` RPATHs and avoid explicit
RPATH arguments. The wrapper continues to forward user flags.

## Debug information and installed runtime paths

`separateDebugInfo = true` requests debug compilation, a SHA1 build ID, extraction
into the `debug` output's `lib/debug/.build-id`, and stripping of the installed
binary. The binutils hook exports `READELF` and `OBJCOPY`. Both the compiler driver
and standalone linker add `--build-id=${NIX_BUILD_ID_STYLE:-sha1}` only when
`NIX_SET_BUILD_ID` is exactly `1` and the link is not relocatable. Other links keep
their existing build-ID defaults. The vendored debug-extraction hook expects a
40-digit SHA1 ID; alternate styles are a direct linker interface, not an extension
of that hook.

Fixup shrinks unused ELF RPATHs across outputs. Declare directories needed by
`dlopen` in `runtimeLibraryPaths`; they must exist and resolve inside `/nix/store`.
Both traversal escapes and store symlinks escaping the store fail fixup. Valid
entries are restored as canonical paths. Ordinary store paths, split outputs,
relative `$ORIGIN` RPATHs and the explicit `dontShrinkRpaths` opt-out retain their
existing behavior. Dependency propagation, strict dependency roles and hook order
continue to use the existing stdenv setup.

Run `testBatches.x86_64-linux.base-gcc13-owned-v3` for compiler, C++, static,
response, hardening, debug, fixup and ownership regressions. The selection,
construction-preserved, native-platform-interface and bootstrap-independent checks
cover the generation boundary; the original v2 suite remains on its internal base.
