# libxml2 source staging

All 68 supported ordinary releases from 2.7.4 through 2.15.3 select owned native
procedures on x86_64 Linux. No releases are declared broken. `legacy.nix`, the
original builders, original version data, construction recipe, nonnative routing
and already-owned 2.15.4 remain unchanged. The latter's unsplit debt remains.

`ordinary/2.nix` preserves source hashes and records independent procedure starts:

- 2.7: no LZMA; GNU89 for weak pthread declarations; XPath begins at 2.7.7.
- 2.8: LZMA; shared and static default; GNU89 through 2.9.4, GNU17 from 2.9.5.
- 2.10: upstream disables static by default and changes the check-local flow.
- 2.13: upstream HTTP default changes to off; LZMA remains enabled.
- 2.14: a definition records the libxml2.so.16 ABI, using the 2.13 procedure.
- 2.15: LZMA implementation removed; HTTP is only an ABI compatibility option.

Python bindings remain explicitly disabled, exactly as in the retained recipes;
ICU defaults off and iconv uses the selected libc. No generator is regenerated.
The build tools and libraries are explicit effective fields. XZ's decompressor
and linked liblzma are separate arguments because only 2.8–2.14 link liblzma.
Ordinary Python/Binutils/Patchelf are selected rather than pinned construction
providers. Existing 2.15.4 retains its explicit construction tool cycle boundary.
Source review and actual compilation must confirm compiler/API compatibility;
GNU17 is explicit, GNU89 is retained, and HARDENING-GATE-1 is OPEN_UNWAIVED.

Each independent procedure unpacks, prepares generated Autotools scripts,
configures, builds, captures raw `make check` execution and installs before the
split. `capture.py` retains exact stdout, exit status and operational logs in the
artifact. This is an **unqualified intermediate**, including when execution
failed. `classify.py` is a separate final-only input and must accept raw evidence
before the canonical output can finish. Unknown log bodies, missing summaries,
nonzero exits and failures fail closed. Known 2.15.3 strict RNG failures remain
UNWAIVED, never rewritten into PASS. The two existing corpus declarations and
latest's existing raw-audit behavior are unchanged. No claim of upstream
qualification for other versions is made. Parent review must resolve any new raw
body contract using actual immutable evidence, rather than weakening it blindly.
All 68 real make-output body contracts are pending: only a narrow summary
protocol is presently recognized. Command echoes/additional records are rejected
until reviewed, even when upstream exits zero. This is a source-stage gap and
must be resolved before representative qualification; it does not reduce the
implemented release scope.

Finalization copies the installed artifact, classifies and removes operational
reports, then relocates text, compiled catalog paths and ELF RPATHs before strip,
interpreter/development metadata and final checks. Original raw logs remain in
the immutable artifact; they are absent from final packages. Equal-width prefix
names preserve pooled strings, static member offsets and compiled lengths.
`elf.py` adapts the existing ordinary Perl ELF/string-ownership inspector as a
family-local concrete operation. It inventories dynamic string consumers before
rebasing RPATHs. Static archive bodies accept native ET_REL readonly catalog path
slots only; unsupported strings fail closed. Complete namespace, hardlink roles,
planned symlinks, frontend bytes and inspector results are checked before writes.
The constructor rejects all artifact references in the final output.

Only source/plan/override contracts, selected source-body preparation and tiny
cached-tool/helper fixtures are exercised in this stage. There are **zero new
compiled package producers**. Installed C API, static API, compression, XPath,
pkg-config and relocation suites are evaluated; their execution is parent-owned.
All historical Python/Ruby/XZ/Perl consumer, corpus, ACL, O1, hardening, full,
default, readability and strict-split gates remain unwaived.

Proposed paragraph for parent integration into STRUCTURE.md before adoption:

> A raw upstream test capture can be installed in an unqualified artifact. Keep
> execution and classification in independent input files; run raw tests before
> the split, and classify the immutable capture after copying artifacts. A
> nonpass intermediate never qualifies a canonical package. Remove operational
> reports from final outputs, preserving originals in the artifact/evidence.
> Classifier edits must reuse the compiled artifact and replay those originals.

No shared API changes are required by this implementation. Source review,
representative compilation and one integrated latest gate remain parent-owned.
