Gawk 5.3.0, 5.3.1 and 5.4.0 reuse the 4.1.4 recipe and its pinned GMP,
MPFR, Readline and Ncurses dependencies. Latest remains 5.4.1.

The tests retain the original version, arithmetic and linkage checks. Additional
coverage includes printf and POSIX regexes across historical releases, exact
installed-header extension compilation/loading from 4.1 onward (API majors
1/2/3/4), MPFR precision where enabled, and CSV quoting, embedded newlines and
CRLF from 5.3 onward. UTF-8 assertions explicitly use the selected libc's owned
C.utf8 data; they do not establish coverage of other locales. PMA tests from 5.2
use fresh private backing files and retain PASS/SKIP status and diagnostics.

For 5.4, tests distinguish default MinRX submatches from the retained
`GAWK_GNU_MATCHERS=1` engine and cover wide shifts, hex floats, POSIX array
length, `@nsinclude` and traditional record splitting. With owned C.utf8,
IGNORECASE comparisons `σ ~ /ς/`, `ς ~ /σ/`, `Σ ~ /ς/`, `ς ~ /Σ/` produce
`0 0 1 0` with MinRX in **both 5.4.0 and 5.4.1**, versus `1 1 1 1` with the
GNU engine. This bounded observation preserves historical behavior; 5.4.0's
`README_d/README.matchers` describes the many-to-one case-folding limitation.

Upstream tracking captures complete directory-index hrefs, then accepts only
numeric `gawk-VERSION.tar.{gz,bz2,xz,lz}` filenames. Fixtures check extraction,
rejection of surrounding junk and prereleases, and deduplication across formats.
