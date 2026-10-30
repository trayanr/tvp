# ACL releases

2.3.0 and 2.3.1 use the 2.3.2 build procedure and propagated Attr 2.5.2.
2.4.0 needs Attr headers to build but does not propagate Attr. Its installed
headers work independently; consumers defining the optional `error_context`
struct need explicit Attr headers. ELF, runpath and closure checks confirm
that the 2.4.0 output has no Attr runtime dependency.

The SONAME remains `libacl.so.1`. Historical library revisions are preserved,
including 2.3.0's `libacl.so.1.1.230` and 2.3.1's corrected revision 2301.
Existing consumers stay pinned to 2.3.2; `acl` and `acl_2` select 2.4.0.

## Tests and historical behavior

Original version/operation tests retain their identities. Added tests cover
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
