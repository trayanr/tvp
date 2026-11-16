# ACL releases

All four public releases share the complete `build.nix` procedure. The 2.3.0
and 2.3.1 rows select `tvp.bases.gcc_13.full`: a source-built GCC13 driver with
source-owned Binutils, libc and construction tools. The former borrowed GCC13
generation is removed. The GCC13 version choice retains the historical
FORTIFY-sensitive source profile; earlier execution receipts do not qualify
the changed compiler/libc inputs. Those rows retain public Attr propagation.
2.4.0 needs Attr headers to build but does not propagate Attr. Its installed
headers work independently; consumers defining the optional `error_context`
struct need explicit Attr headers. ELF, runpath and closure checks confirm
that the 2.4.0 output has no Attr runtime dependency.

The SONAME remains `libacl.so.1`. Historical library revisions are preserved,
including 2.3.0's `libacl.so.1.1.230` and 2.3.1's corrected revision 2301.
Existing consumers stay pinned to 2.3.2; `acl` and `acl_2` select 2.4.0.

## Tests and historical behavior

Original version/operation assertions remain in the shared suite. Added tests cover
exact library loading, public headers, pkg-config, ACL text/permissions,
named/default ACLs, copy/inheritance and restore behavior. Filesystem test
outputs retain a `status` file containing PASS or SKIP, plus the fixture log.
Unsupported filesystems skip explicitly; other errors fail. Sandbox filesystem
fixtures skipped, while separate temporary-file runs passed all four releases.

2.4.0 tests cover its four exported `_at` APIs, dirfd and empty-path access,
symlink handling, invalid flags and directory defaults. CLI fixtures cover
physical restore, malformed input and permission-preserving dry runs.
The 2.3.x controls retain three upstream defects fixed in 2.4.0: lost leading
whitespace in restore filenames, numeric UID/GID overflow truncating to zero,
and symlink traversal without the newer unsafe-restore warning.

Pinned Linux 6.9 headers select shipped xattrat ENOSYS stubs and compatibility
operations. Native openat2 physical restore passed; injecting ENOSYS made it
fail. Native xattrat, older kernels, long-path fallbacks and O_PATH workarounds
remain untested.

Unmodified upstream ordinary tests passed: nine per 2.3.x release and ten for
2.4.0, including its three conditional restore-warning cases. Four privileged
cases per release and the NFS directory case were not run. The local `nfsacl`
probe produced XFAIL/XPASS depending on timestamp formatting; neither establishes
NFS coverage. NFS/root-squash and SELinux policy variants remain untested.

## Upstream tracking

The Savannah tracker accepts complete numeric `acl-X.Y.Z[.src].tar.gz` and
`.tar.xz` filenames and deduplicates formats. Prefixes, signatures, README and
other suffixes are rejected. Its 14 archives represent 10 releases: four
packaged and six missing (2.2.48–2.2.53). Archive hashes and source versions
were checked; detached signatures were not authenticated.


## Authoring structure

The literal release table preserves exact library revisions, runtime Attr and
public propagation facts. All releases need Attr headers to build. Independent
U restores a compiled checkpoint and binds the existing Perl/shell harness and
filesystem-capability wrappers; `.test` versus `.run` is test-only policy.
Compilation does not depend on those policy files. One installed suite retains
all API, exact-library, tracker and filesystem assertions. Isolated-header
controls remain limited to the originally isolated 2.3.2/2.4.0 interface;
2.3.0/1 deliberately propagate Attr and are not falsely claimed isolated.

Construction callers instantiate the same family with explicit earlier inputs.
The old construction definition, duplicate builders and caller factory are removed.
Historical Tar remains explicitly constrained to `acl_2_3`. Current source cleanup
adds no runtime qualification; prior skips and limitations remain unwaived.


## Current authoring validation

The historical observations above retain their original scope. The current
family-authoring pass qualifies only the selected outputs recorded in
`lib/MIGRATION-LOG.md`; it does not replay every historical release or waive
filesystem/platform skips.
ACL 2.4.0 and the former GCC13 2.3.0 representative passed their recorded normal
batches. New source-GCC13 consumer execution remains pending; the old receipts
are not evidence for the replacement provider. The other two releases were
evaluation-only in the authoring pass.
