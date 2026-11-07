PCRE2 10.49 selects the complete native `native/build-10.49.nix` procedure
on x86_64 Linux. Older releases and other platform routes retain the 10.44
Autoconf procedure. Frozen compiler construction explicitly selects the complete
captured recipe. Ordinary Grep uses moving `pcre2_10` and its retained 3.11
consumer keeps its historical behavior tests.

The canonical native output remains shared-only: 8/16/32-bit engines, Unicode,
JIT and the POSIX wrapper, plus pcre2grep/pcre2-config and four pkg-config modules.
The declared `static` option builds a separate static companion for installed
API consumers. Native checks bind upstream's four `/bin/echo` callouts to the
explicit Coreutils provider; historical procedures and fixtures remain intact.

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

Unmodified `make check` initially reported three runner passes and one failure
per release: `RunGrepTest` calls an unavailable `/bin/echo`. A validation-only
rerun replaced its four helper paths with owned Coreutils 9.5 echo, preserving
the test patterns and expected outputs. All four runners then passed on all
four releases, including the remaining grep sections. Locale and width/feature
omissions remain; zero runner skips does not mean every subcase ran. Original
failure logs are retained in the validation evidence.

The family tracker accepts only complete `pcre2-N.N` tags and preserves version
strings such as `10.00`. The upstream tool strips peeled-ref markers and
deduplicates tags. The observed 26 stable tags give four packaged and 22 missing
versions, including 10.45/10.46, which are outside this addition. Tag availability
does not verify older release archives; no unavailable-release claims are made.
