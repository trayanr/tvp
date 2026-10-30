PCRE2 10.44, 10.47, 10.48 and 10.49 share the unchanged 10.44 Autoconf
recipe. The moving `pcre2` and `pcre2_10` aliases select 10.49; exact 10.44
consumers, including GNU Grep, remain pinned. Optional readline, libedit,
zlib and bzip2 support remains disabled. Normal outputs contain shared
8/16/32-bit libraries and the POSIX wrapper; tests build a separate static
companion without changing the normal outputs.

[10.47](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.47) adds
`pcre2_next_match`, `PCRE2_CONFIG_EFFECTIVE_LINKSIZE` and default Linux symbol
versioning. [10.48](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.48)
updates Unicode to 17.0 and includes the scoped security and correctness fixes
listed in its NEWS. Reported Unicode versions are 15.0.0 (10.44), 16.0.0
(10.47), and 17.0.0 (10.48/10.49).

[10.49](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.49) is a
security-only release over 10.48: its minimal correction addresses
[GHSA-r9hj-j2rw-4q3m](https://github.com/PCRE2Project/pcre2/security/advisories/GHSA-r9hj-j2rw-4q3m),
an out-of-bounds write when an application supplies a growable custom JIT
stack and matches an attacker-controlled pattern with unusually high JIT
stack usage. Upstream identifies 10.48 and earlier as affected. Historical
versions here retain their original behavior; no fixes are backported.
Passing these tests does not establish complete security assurance.

The C consumers compare interpreter and JIT captures in all three widths,
check UTF/UCP, API boundaries, shared-library identity, Linux SONAMEs and
symbol versions, and independent static/POSIX linkage. Bounded upstream
fixtures from [#912](https://github.com/PCRE2Project/pcre2/pull/912) and
[#841](https://github.com/PCRE2Project/pcre2/pull/841) retain these historical
expectations: the former misses in JIT on 10.44/10.47; the latter truncates the
mixed Unicode class match on 10.47. Both match correctly on 10.48/10.49.

Supplemental unmodified `make check` on x86_64 Linux reports four runners per
release: three pass (`RunTest`, `pcre2posix_test`, `pcre2_jit_test`), one fails
(`RunGrepTest`), zero runner skips. `RunGrepTest` requires the absolute
`/bin/echo` for script callouts, unavailable in the validation environment.
Its remaining sections after that failure are untested. `RunTest` also reports
locale and width/feature-specific omissions; runner-level zero skips does not
mean every subcase ran. No runners or expected upstream outputs are modified.

The family tracker accepts only complete `pcre2-N.N` tags and preserves version
strings such as `10.00`. The upstream tool strips peeled-ref markers and
deduplicates tags. The observed 26 stable tags give four packaged and 22 missing
versions, including 10.45/10.46, which are outside this addition. Tag availability
does not verify older release archives; no unavailable-release claims are made.
