libxcrypt 4.4.36 and 4.5.0–4.5.2 share the unchanged `build-4.4.36.nix`
recipe and Perl 5.44.0 definition. Generated configure is shipped; Python and
Passlib are needed only to regenerate upstream's known-answer tables. Normal
all-hashes, obsolete ABI, feature defaults and compiler flags are preserved.
`libxcrypt`/`libxcrypt_4` select 4.5.2; `libxcrypt_4_4` stays at 4.4.36.

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
