All four public Libxcrypt releases use one complete `build.nix` procedure.
The release table selects a real TVP Perl dependency: shipped Make rules use
Perl for production symbol/header generators. Python/Passlib are still not
needed to regenerate known-answer tables. The 4.4.36-only GCC15+ ascii64
warning demotion remains explicit; all other Werror and hardening stay enabled.
Normal all-hashes, obsolete ABI, shared/static and feature defaults are kept.

A configures, compiles, installs and saves its compiled source checkpoint. F
copies A, drops the checkpoint and performs output/runtime repair. Independent
U restores that checkpoint and prepares only test frontends before make check.
One installed suite reuses the existing ABI/API/vector/old-consumer assertions.

`retained.nix` preserves the exact historical 4.4.36 ABI-control constructor and
lazy test closure. It is intentionally not replaced with the public ordinary
4.4.36 producer. The direct `build-4.5.2.nix` bootstrap entry point stays in place
and unchanged. The old `tests/upstream.nix` stdenv validation companion also
remains for construction callers; ordinary U is `tests/checkpoint-upstream.nix`.

The original `crypt` test remains unchanged. Additional Linux probes check the
exact loaded library, crypt.h/pkg-config consumers, compatibility links,
SONAME and versioned function exports against 4.4.36. A binary linked against
4.4.36 also runs against each addition without relinking. The configured ABI
has `GLIBC_2.2.5`, `OW_CRYPT_1.0`, `XCRYPT_2.0`, `XCRYPT_4.3` and `XCRYPT_4.4`
on x86_64 Linux; release 4.5 does not imply an `XCRYPT_4.5` node.

Bounded dummy-password vectors from upstream 4.5.2 exercise crypt, crypt_r,
crypt_rn and crypt_ra, separate reentrant buffers, invalid settings and short
buffers. Deterministic upstream entropy fixtures cover salt generation and
classification. SM3 crypt and SM3-yescrypt are enabled by the existing
all-hashes policy in 4.5; 4.4.36 explicitly tests rejection and logs those
unsupported algorithm cases as SKIP. Upstream #209 aliasing controls preserve
4.4.36's failure tokens/overwritten phrase and prove corrected behavior in 4.5.
These historical outcomes are not runtime patches or whole-release failures.

`tests/upstream.nix` is a separate validation companion that runs unmodified
`make check` and retains configuration, summary and individual PASS/SKIP logs.
Its default shared configuration matches normal static-library policy;
`static = true` additionally exercises upstream's static/renaming symbol tests.
Observed x86_64 Linux counts (total/pass/skip): shared 4.4.36 = 46/44/2,
shared 4.5.x = 55/53/2; static companions = 48/46/2 and 57/55/2 respectively.
The skips are getrandom-fallbacks (arc4random_buf compiles out that fallback)
and symbols-compat (no system-provided libcrypt in the compiler search path).
The independent ELF comparison and old-consumer check cover the declared
4.4.36 compatibility baseline directly. Normal shared builds omit the two
static tests. Companion outputs are validation artifacts, not normal libraries.

Coverage is native x86_64 Linux. Exact-library/ELF probes log SKIP on non-Linux
targets. No Valgrind/ASAN, cross-architecture, optional platform or focused -O3/LTO
coverage is claimed. The 4.5.1 version-script and 4.5.2 explicit_bzero/SHA1 fixes
do not change normal producer flags. No known-answer tables were regenerated.

Tracking uses full-match `vN.N.N` tags from besser82/libxcrypt and the existing
peeled-ref deduplication. The observed stable set has 58 tags: four packaged,
54 missing. Only the three added archives were rechecked against published
asset digests and embedded versions; tag availability does not authenticate
all historical archives. 4.4.37/4.4.38 are outside this expansion. A development
NEWS entry for 4.5.3 is not a verified stable release. No unavailable-release
claims are inferred from a failed fetch.


## Current authoring validation

The historical observations above retain their original scope. The current
family-authoring pass qualifies only the selected outputs recorded in
`lib/MIGRATION-LOG.md`; it does not replay every historical release or waive
filesystem/platform skips.
The current 4.5.2 artifact/final and ten non-ABI leaves pass. Its exact retained
4.4.36 ABI comparison is NOT_RUN because that fixture needs an uncached historical
compiler generation (MIG-017). The normal batch remains incomplete.
