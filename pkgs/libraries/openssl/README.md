# OpenSSL ordinary source staging

The 213 supported legacy releases now select complete native source-GNU recipes
in `ordinary/`. The six 0.9.6 broken releases remain on their exact retained
construction definitions. Original version tables, constructors and build files
remain available through `constructionRecipe`; other hosts retain that route.
Existing owned 3.6.3 and 4.0.1 profiles are unchanged, including their unsplit debt.

The procedure starts are 0.9.7 (make depend, historical installation), 1.0.0
(make depend and domd's gcc name), 1.1.0 (unified build), 3.0.0 (providers), and
4.0.0 (no c_rehash). Definition data retains the C dialect, pointer/implicit-call
warning exceptions, the 0.9.8 format-hardening exception, and the 1.1.0–g Perl
5.28 File::Glob constraint. Latest compatible ordinary Perl is used elsewhere.
Build Perl and runtime Perl are independent effective inputs. Compiler protection
flags are explicitly selected through the existing source-GNU hardening adapter;
this is source ownership, **not** hardening equivalence or qualification.
HARDENING-GATE-1 remains OPEN_UNWAIVED.

Each procedure unpacks, prepares, configures, builds serially, runs upstream tests,
and installs shared/static libraries, headers, engines/providers as provided by
that release, and development metadata before `steps.split`. A nonzero upstream
exit fails the artifact; there is no classifier or tolerated-failure conversion.
The raw output and exit receipt are retained in the immutable artifact only.
The final package removes those operational files, relocates equal-width self
paths, binds runtime scripts, strips and finalizes development/ELF metadata.
`doCheck = false` is an explicit customization, never qualification evidence.
OpenSSL 3.0.4's CVE/RSA status and named test exclusion remain unchanged and
UNWAIVED. No upstream crypto is patched and no conformance claim is made.

Preparation and finalization are separate file inputs. `source.py` owns only
script/make-input edits and diagnostic compiler basename reporting, preserving
all reported flags. Historical Latin-1 script comments are explicitly declared;
newer sources use strict UTF-8. Dangling internal source FIPS aliases are inert
inputs, never followed for writes. Unknown interpreter forms and unsafe links
fail closed. The finalizer validates the entire namespace and all hardlink roles
before mutation. Equal-width substitutions preserve compiled string lengths and
pooled suffix addresses. Runtime ELF dynamic strings include symbol, dependency,
version-needed **and version-definition** consumers; overlapping RPATH ownership
is rejected. Static archives use a separate ET_REL operation: member lengths,
indices, addresses and symbol/relocation records do not move. Unknown self-string
locations fail closed. Constructor output checks exclude artifact references.

`tests/native-default.nix` remains the universal family interface. Ordinary ports
add installed shared/static SSL/SHA1 consumers and provider checks guarded at the
whole-test level. The shared latest-specific contract stays unchanged for the
existing latest profiles. The additional compile-free guard fixture exercises
unsafe namespaces, hardlink roles, encodings, inspector failure and archive
rejection. Metadata evaluation is not test execution or package compilation.

Proposed parent STRUCTURE paragraph: OpenSSL keeps complete version-start
procedures and an installed-artifact split. Build and runtime Perl bindings are
separate. Equal-width self-path relocation covers runtime versioned ELF and
static ET_REL archive members, while raw upstream evidence remains only in the
artifact. Runtime-only and final-helper edits preserve the artifact; source,
compiler and configure edits invalidate it. Source-only staging does not close
consumer, hardening or upstream-test holds.

Proposed shared API integration: extract the retained Perl namespace/text/audit
operations into a shared pure inspection module, and review the OpenSSL
`elf.py` extension for GNU version definitions plus `archive.py` for ET_REL
self-string ownership. This child reuses Perl's narrow tree/text/audit primitives
as an explicit final-only input; it never invokes a Perl recipe or finalizer.
No shared file is modified here. Source review must decide the shared location
before adoption. The repository-wide RPATH finalizer's loader-token preservation
policy is also parent-owned; this stage does not change it.

This is a source-stage candidate: zero new compiled package producers. Independent
source review, representative compilation, named consumer executions and one
integrated latest gate are parent-owned. Existing Perl consumer holds (including
eight OpenSSL 1.1.0–g identities), historical Python/Ruby/XZ holds, calendar raw
nonpasses, and ACL/GCC/hardening/O1/full/default/readability/strict-split gates
remain unwaived. Exact representative proposals and source-preflight receipts
are recorded in the external immutable implementation handoff.
