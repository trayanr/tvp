# Standalone early construction

This private construction entrypoint builds a usable native x86_64 C compiler
and Mes libc from one **229-byte AMD64 hex0 seed**. It is the first milestone,
not a complete modern TVP base. It does not participate in the catalogue or
change any base, selector or frozen construction input.

Run from the repository root:

```sh
nix-instantiate --eval --strict bootstrap -A compiler.drvPath
nix build --file bootstrap compiler --no-link -L
nix build --file bootstrap libc --no-link -L
nix build --file bootstrap tests.consumer tests.versions --no-link -L
python3 bootstrap/audit.py > executable-inputs.json
```

Python and the Nix CLI in the audit are observer tools, never production build
inputs. `negative.nix` contains expected
failures to realize individually: `ambient-shell`, `ambient-env`, `missing-stage`,
`wrong-stage`, `seed-hash`, `seed-mutation`; evaluate `source-hash` to test tree hash rejection.

## Construction boundary

The only native binary input is the pinned seed in `provenance.json`. Nix's
builtin downloader fetches it and the pinned archives; its builtin tarball
fetcher obtains six source-only Stage0 components. Source gitlinks come from
Stage0-posix Release_1.9.1, resolved to an immutable commit. No seed repository
or recursive bundle of other prebuilt binaries is imported. Stage0 tree hashes
are recursive hashes; archive hashes are flat hashes; the executable seed hash
is a recursive NAR hash and also has a recorded flat SHA256 and byte size.

`adapter.nix` uses `builtins.derivation`, with empty PATH by default. The earliest
steps invoke hex assemblers directly, then a source-built Kaem interpreter.
Later Kaem recipes receive only their declared Stage0 tool directories. Builder
scripts retain derivation contexts through a source-built text writer, so their
compiler/library references remain explicit recursive input edges. Source-built
stages disable substitution. Nix's evaluator, downloader, store/daemon, sandbox
and the host Linux kernel are explicit trust/execution boundaries. This native
selection needs x86_64 Linux execution; it uses no intermediate 32-bit ABI.

The private stages are hex0/hex1/hex2, M0, cc_amd64, M2-Planet, mescc-tools and
Kaem, Mes 0.27.1/MesCC and libc, then bootstrappable TinyCC feature stages and
TinyCC `cb41cbf` with repeatedly rebuilt Mes libc. The consumer statically links
that libc and exercises allocation, strings, calls, arithmetic and stdio.

## Provenance and checks

Recipes are adapted from nixpkgs revision
`97059e5ecd707df94f104cfd77b0ac0e2c14881c`, with no evaluation import of that
repository. `COPYING.nixpkgs`, `COPYING.GPL3`, per-file notices and
`provenance.json` retain attribution, source licenses and immutable upstream
live-bootstrap recipe references. Inline source changes and the supplied Mes
C files are part of the reviewed recipes. The additional Mes wait-status
initialization handles M2's word-sized `int` versus Linux's 32-bit status write.

The seed-built hex0 must match its fixed-output hash. Successive TinyCC/libc
rebuilds follow upstream's feature ladder. The upstream `versions` chain only
runs each compiler's version command; it does not compare their bytes. The
observer audit walks all input derivations, checks downloader pins, classifies
builders and PATH origins, and rejects native executable files in source trees.
It establishes input provenance, not diverse double compilation or a general
trust proof. Mes libc is a bootstrap libc with limited POSIX coverage.

The repository's `bootstrap-audit-contracts` check tests the observer's rejection
rules offline. Compiler and consumer realization are separate targeted checks.

Next comes the source-built shell/make/text/archive tool ladder, the TinyCC/musl
transition, GCC 4.6 C then C++, GCC 10, and a modern compiler satisfying GCC's
C++14 prerequisite. Owning the full stdenv/base, later-generation comparisons,
runtime seed exclusion and coherent candidate/catalogue validation remain
required before any proposal to change the default base.
