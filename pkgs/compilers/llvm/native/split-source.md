# LLVM 23.1.4 installed artifact boundary

The ordinary public procedure installs its complete native LLVM/Clang/LLD profile
into A. Production disables upstream test preparation. The independent validation
plan uses the same effective source, compiler, CMake options and libraries with
upstream tests enabled, builds FileCheck/not, and runs the original Assembler and
Bitcode checks. The existing `{ package }` test factory registers this raw-failing
validator in the normal suite. Neither A nor F consumes it.

F first copies A using scalar `TVP_ARTIFACT_ROOT` transport. Equal-width store
basenames preserve compiled string lengths and native object/archive offsets.
The recipe-specific adapter reuses Ruby's guarded native readonly-path operations,
libxml2's ar container parser, and Perl's ELF dynamic-string/namespace finalizer.
It accepts native readonly path slots, validates archive containers, preserves
internal aliases and fails on unsupported prefix-bearing LTO/bitcode or serialized
payloads. It never broadly replaces arbitrary binary bytes. Existing strip,
RPATH, script binding, GCC-view and Clang wrapper operations follow relocation.
Resource directories, all target backends and development outputs remain installed.
The existing compiler interface and alias wrapper installer is unchanged.

Raw `nix-support/CMakeCache.txt` stays in `package.artifact`; F removes the copied
cache before relocation. It is provenance, not operational metadata to rewrite.
The public final output must exclude the artifact prefix. Runtime/provider edits
used only by finalization, finalizer edits and upstream-check edits reuse A.
Effective source, build compiler, linked library/header and configure edits
invalidate it. Production and upstream source hashes are unchanged.

`tests/contracts.nix` and `tests/split-source.nix` are bounded evaluation contracts.
`tests/split-fixtures.py` executes the selected copy command on tiny data, then
checks synthetic native archive/text/alias relocation and unsafe-payload rejection.
It runs no compiler, LLVM executable or upstream check. These are source-level
contracts only: both changed producers and the independent validator remain
UNCOMPILED/UNQUALIFIED. Unexpected real installed shapes fail closed; historical
nonpasses and admission/hardening holds are not waived.
