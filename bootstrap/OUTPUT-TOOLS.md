# Standalone output-tool qualification

These private, opt-in endpoints use the reduced GNU checkpoint from
`gnu-environment.nix`. They do not select the newer libc capability profile or
change catalogue packages, base defaults, compilers, or public selectors.

```
nix build --file bootstrap/output-tool-prerequisites.nix patchelf --no-link -L
nix build --file bootstrap/output-tool-prerequisites.nix mpfr consumer --no-link -L
nix build --file bootstrap/output-tool-contracts.nix unpack --no-link -L
nix eval --json --file bootstrap/output-tool-contracts.nix assertions
python3 bootstrap/output-tool-origin-audit.py
```

Patchelf 0.19.2 uses the catalogue's release archive, hash and GPL-3.0-or-later
licence. Its final executable is linked directly with the owned loader and
explicit GNU runtime paths, then stripped with owned binutils. No previous
Patchelf participates, and it does not rewrite its own installed ELF. Selected
release test scripts bind directly to owned Bash, preserving shebang arguments. The
separate `evidence` output retains configure, build, install and test logs.

The native BUILD floor explicitly selects existing source-owned Make, sed,
grep, Gawk, Diffutils and Findutils. Archive tools and Python 3.12.5 also retain
their existing source-owned MUSL-hosted identities. Their execution does not
assert GNU ABI compatibility. A test-only `ldd` adapter invokes the exact owned
GNU loader; it has no system search or borrowed executable.

Raw full Patchelf check results retain failures involving the compiler
fixture RPATHs: `no-rpath.sh` expects none, and `shared-rpath.sh`
expects one string shared with a symbol. The raw logs and fixture ELF metadata
are retained. A separate three-test recheck removes the no-rpath fixture's
RPATH and links the libc-free shared-string fixture directly with owned `ld`.
All three rechecks pass. This does not turn the raw full suite into a pass;
architecture-dependent skips also remain recorded.

MPFR 4.2.2 calls the existing recipe through `lib/builder.nix`, with normal spec
and step edits for declared configure tools and explicit Findutils. The actual
upstream check runs before installation. The full artifact/output split runs
Python's Autotools preparation, text relocation, ELF stripping, libtool cleanup,
authoritative RPATH composition, development metadata, symlink and path checks.
The installed consumer declares only MPFR; its public development metadata
supplies GNU GMP headers and libraries. The consumer's separate `evidence`
output retains its link/CRT map without adding the compiler to runtime. Nix
rejects final references to the
artifact output. Python qualification covers the modules used by these helpers,
not SSL, SQLite, ctypes or a general interpreter capability profile.

New unpack calls may select `findutils`; omitted arguments preserve the previous
step text and tools. New independently composed bases may set ordered,
contextual `runtimeDirectories`; the explicit list (including an empty list)
overrides the old `cc.libc` / `cc.cc` fallback. Coreutils remains the explicit
floor for sorting and epoch handling. The contracts exercise xz/gzip archives,
a known epoch, missing Findutils, runtime order/context and malformed metadata.

This is a helper/package checkpoint, not a complete base, compiler fixed point,
new-libc target adapter or full conformance result. Matching new libc runtimes
and a separate target adapter remain later work.
