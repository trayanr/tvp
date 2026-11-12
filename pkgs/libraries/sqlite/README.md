# SQLite source staging

Ordinary releases before 3.6.10 opt into Tcl8's retained string-result API with
`USE_INTERP_RESULT`. Those sources access `Tcl_Interp.result`; 3.6.10 replaces the
accesses with public result functions. The native definition adds the compiler
option without changing retained recipes, test coverage or the selected Tcl.

Releases before 3.5.6 also use `-fcommon`: their test header declares
`pager3_refinfo_enable` in multiple translation units. The native definition at
3.5.6 removes that option when upstream removes the global. Retained definitions
and the shared version table keep their original data.

The ordinary x86_64-linux table now selects owned, installed-artifact procedures
for all 268 supported legacy releases, 3.0.0 through 3.53.3. Declared-broken 3.2.8
keeps its original definition, status and debt row. The already-owned 3.53.4
procedure, source and tests stay independent and unchanged; its unsplit debt is
still explicit. Non-native callers and constructionRecipe retain the original
complete table, builders, URLs, hashes, patches and test factory.

`ordinary/build-3.0.0.nix` owns the Fossil/autoconf procedure through 3.47.2.
It lets each source's own make rules choose the multi-file build, Lemon and keyword
generators, or generated amalgamation. Amalgamation tooling appears at 3.3.14;
this changes upstream make's prerequisites, not the package's ordered commands.
Historical GNU17/implicit-declaration flags, configure permissions, format
hardening exceptions, pkg-config major/minor versions and 3.1.0alpha/3.1.1beta
reported versions remain original definition data. Original patch records and
bytes are reused. The explicit early config_TARGET_* arguments bind installed
Tcl8/Readline while later TEA configure consumes --with-tcl. No FHS provider is
selected. Tcl installation begins at 3.1.0; the install command preserves
TCLLIBPATH as well as TCLLIBDIR for the two upstream installation interfaces.

`ordinary/build-3.48.0.nix` owns autosetup's --all/Readline/Tcl interface through
3.53.3. The upstream process-isolated veryquick runner and its jobs database are
used here. The autoconf generation uses its quick.test entry point; this
intentionally preserves that source's tests and exclusions rather than borrowing
new test scripts. New upstream failures/skips receive no waiver. Fixture-only
zlib/Tcl compiler flags apply solely to building testfixture. CLI, shared/static
libsqlite3, headers, pkg-config (where shipped), and Tcl extension installation
remain enabled as in the original procedures. Lemon remains an upstream generator;
no substitute amalgamation is downloaded.

The visible order is unpack, guarded source preparation/patches, configure,
build, raw upstream execution, install, split, copy, acceptance, text relocation,
manual compression, strip, RPATH repair, development metadata and final checks.
All commands use effective final specification fields. Ordinary Readline/Tcl
selectors keep moving normally; only host construction tools retain their
explicitly constrained source-GNU generations. Native tests reuse the historical
suite and its whole-test API guards, with installed shared/static/C++ consumers
and an owned Tcl-extension discovery check from 3.1.0 onward. The latest-only
3.53.4 feature contracts are not applied to historical APIs.

Source preparation (`prepare.py`), raw execution (`capture.sh`), acceptance
(`classify.py`), and installed text repair (`finalize.py`) are distinct file inputs.
A final classifier edit replays raw output and exit status without recompiling.
The modern artifact also keeps the unmodified runner log/database. A failed raw
intermediate is unqualified: the final derivation rejects nonzero, absent,
duplicate, zero-case or nonpassing summaries and additional failure records.
Operational reports are removed from the final package only after acceptance;
immutable originals remain in the installed artifact. No log is rewritten to PASS.
For the process-isolated runner, final replay opens the retained database read
only through the copied target's installed SQLite CLI. The minimal construction
Python does not need a SQLite extension or another compiler generation. Every completed job and its
output must match the runner log; database totals must match the native aggregate
and wrapper summary. Per-job counters replay the runner's unanchored summary
extraction and its one-case default for summaryless auxiliary commands. Truncated,
duplicate or nonzero job results are rejected even when all stored totals agree.
Unknown Unicode decorations before a counter reject instead of approximating
the native Tcl character tables; Unicode platform text after it remains allowed.
Missing, unfinished or contradictory evidence is rejected.

The text mutator validates canonical roots, internal symlinks, the complete file
namespace, hardlink counts and every alias's role, regular UTF-8/no-NUL metadata,
and special files before its first write. It changes metadata in place to preserve
internal hardlinks. ELF operations use the existing output primitives rather than
a second SQLite ELF parser. Constructor exclusion checks reject any remaining
artifact reference. Unsupported ELF layouts or runtime paths fail closed; this
stage does not certify runtime relocation.

Source-stage evidence: all 268 supported cached archives were inspected for
metadata and procedure texts; eight boundary fixtures exercised preparation only,
and all five retained patch bytes applied to their chosen sources. Other releases
have not run full source preparation. No configure/compiler/package tests were
executed. Seven representative interfaces exercise pure final/artifact identity
controls. Python helper fixtures execute separately. All package producers remain
uncompiled in this stage; evaluated splits are not runtime qualification.

The parent's minimum compilation proposal is 3.0.0 (oldest multi-file generator
and API), 3.1.1 (Tcl install and beta/pkg-config distinction),
3.6.11 (default amalgamation, install/relink patch and newer pkg-config), 3.47.2 (last
autoconf), 3.48.0 (first autosetup), and 3.53.3 (most recent legacy/runner).
Patch/permission-only edge releases need not all be compiled: their source fixtures
and evaluated options are retained for review. Parent review may reduce or expand
this set from measured compatibility evidence before authorizing builds.
The presence of amalgamation tooling in 3.3.14 does not mean the default build
uses it; upstream's default changed later. Source fixtures cover that distinction.

HARDENING-GATE-1 stays OPEN_UNWAIVED. Source-GNU's empty default hardening list is
not equivalent to the retained stdenv policy. All consumer, upstream, full/latest,
strict-split, O1 and default-switch holds remain unwaived. Source acceptance,
representative compilation and one integrated latest gate belong to the parent.

## Proposed STRUCTURE addition for parent integration

A family may stage every supported release in one source batch while retaining
complete independent version-start procedures at genuine operation boundaries.
Upstream make-owned generator changes need not fork identical package plans;
release options and patch facts stay explicit. When upstream result acceptance
needs a classifier, capture unmodified output plus exit status before the installed
artifact split, and classify through an independent final-stage input. Failed raw
intermediates are unqualified. Keep immutable raw evidence in the artifact and
remove operational reports from public outputs only after acceptance. Prove that
classifier and finalizer changes reuse the artifact, while source, compiler,
provider, flags and preparation changes invalidate it. This proposal changes no
shared builder API and requires parent documentation/source review before adoption.

Legacy fixture compatibility remains explicit definition data. The 3.0.0–3.2.2
and 3.2.5–3.5.6 libtool launchers relink the test fixture at execution, so their
raw test step repeats the selected Tcl/zlib fixture link environment. The
3.2.3–3.2.4 direct-link exception and 3.5.7 default-amalgamation boundary keep
that environment disabled. Installed package features do not change.

For 3.6.7–3.6.11 only, the test VFS callback returns the function-pointer type
already required by that release's `xDlSym` API. The two-line source patch matches
upstream 3.6.12 and keeps the callback body unchanged. These are native-only
compatibility boundaries; the retained construction definitions stay exact.
Source/identity checks do not replace canonical upstream and installed tests.

The native runtime-compatibility definitions make five measured repairs explicit.
The 3.0.0–3.0.6 pager/B-tree test adapters preserve complete host pointers in both
directions. The 3.0.0–3.3.7 test interpreter initializes Tcl before clock calls.
The 3.1.0–3.3.13 corruption fixtures use upstream's later RDWR correction so seek
writes modify the intended header. The 3.1.1–3.7.5 engine computes a negative
integer's serialization magnitude with defined unsigned arithmetic, including
INT64_MIN. The 3.46.0–3.47.2 recovery fixture removes a previous test's output
before saving its input snapshot. Patch-context boundaries are definition data;
no versioned builder imports another recipe.

The shared ordinary installed suite adds an indexed-integer regression covering
the minimum/maximum 64-bit values and smaller boundary values. Original failed
raw reports remain retained. These declared source/fixture patches preserve
expectations and fault loops; new raw reports describe the patched source,
not a pristine upstream checkout. Canonical qualification is still required.

Test portability patches cover 97 supported releases through 3.7.6.3. They retain
all original failures as historical evidence; the candidate's patched producers
still require canonical execution. Broken 3.2.8 remains excluded.

The 3.0.0 private test fixture compiles pragma.c and enables its lock diagnostics
under SQLITE_TEST, following 3.0.1, with a matching pager declaration. The release
library keeps its debug policy. Releases 3.0.0–3.0.7 sort only the two attach2
leftover-journal membership assertions, following 3.0.8; an extra journal still
fails. Releases 3.0.0–3.5.8 compare the entire callback expression error to a direct
Tcl reference, following 3.5.9. Releases 3.0.7–3.5.5 correct only the zero-hex
alternate-form reference to padded zero, matching the existing formatter and
3.5.6's explicit vector. All original format calls and values remain.

Releases 3.1.0–3.6.1 construct fresh strings for the original 5/7 TEXT inputs,
keeping SQL, blob bytes and expectations. Releases 3.2.3–3.7.6.3 append then remove
a character to construct an actual empty string for types3-1.1; the original
empty value and string/TEXT expectation remain. The removal uses the generic Tcl
command through a list evaluation: the compiled empty-replacement shortcut can
return a typeless empty object, while the generic command constructs a string.
Releases 3.5.9–3.7.6.3 backport
3.7.7's realnum support verbatim within nan.test, using it only for numeric
infinity assertions. SQL CAST-to-text, signs, types, NULL and payload assertions
remain exact. Four NaN patch contexts preserve the changing source case lists;
complete native definitions at 3.0.8, 3.5.9, 3.6.3, 3.6.18 and 3.7.7 record the
new source boundaries without changing either ordered procedure or providers.
