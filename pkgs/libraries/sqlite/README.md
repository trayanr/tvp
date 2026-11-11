# SQLite source staging

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
and API), 3.1.1 (Tcl install and beta/pkg-config distinction), 3.3.14 (first generated
amalgamation), 3.6.11 (install/relink patch and newer pkg-config), 3.47.2 (last
autoconf), 3.48.0 (first autosetup), and 3.53.3 (most recent legacy/runner).
Patch/permission-only edge releases need not all be compiled: their source fixtures
and evaluated options are retained for review. Parent review may reduce or expand
this set from measured compatibility evidence before authorizing builds.

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
