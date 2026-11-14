# Attr

All four public releases use the complete `build.nix` procedure and a literal
release table in `default.nix`. Library revisions stay explicit: 2.5.0's
historical 250 spelling is not replaced by 2501. The `.test` versus `.run`
harness choice belongs only to the independent upstream factory.

Compilation/configuration/installation form A. F copies A, drops the build
checkpoint and applies runtime/output repair. U restores the compiled source
checkpoint privately; test-driver/Perl policy and filesystem capability
wrappers are U inputs, so changing that policy does not invalidate A or F.
Installed assertions are shared by all four releases.

`retained.nix` preserves the historical construction recipe and its original
factory closure. Its stdenv builders, frozen fixtures and factory entry points
remain independent of the public ordinary route. Existing alias and release
metadata are unchanged; ordinary authoring does not certify runtime behavior.

The Savannah tracker accepts complete `attr-VERSION[.src].tar.gz` filenames.
Its nine releases include the five still unpackaged 2.4.44–2.4.48 releases.
Extraction and normalization fixtures reject other prefixes, signatures,
README suffixes, other suffix junk and prereleases.

The original version and policy tests are retained. Added tests check SONAME,
symlinks, the exact loaded library, C API file/fd operations and copy policy,
and text/binary restore roundtrips with symlink and no-dereference semantics.
2.6.0 additionally checks physical restore (`-P`) and unsafe-restore warnings.
All filesystem targets are temporary owned files. When the user-xattr
preflight returns `EOPNOTSUPP`, the `xattrs` output records `SKIP` explicitly;
this is not filesystem coverage. Other errors fail the test. Native runs of
the same fixtures passed for all four releases and the two 2.5.2 assemblies.

2.5.0 intentionally retains its upstream libtool revision bug:
`libattr.so.1.1.250`, compared with corrected 2.5.1's `libattr.so.1.1.2501`.
Both retain SONAME `libattr.so.1`; tests verify each exact library rather than
substituting a newer release.

Supplemental unmodified upstream `make check` runs with Perl supplied yielded
one pass and one root-only skip for each 2.5.x release. 2.6.0 yielded two
passes and one root-only skip, including its conditional `restore.run`;
2.5.x uses `.test` files. There were no failures, errors or expected failures.
Root-only trusted-xattr, filesystem-specific boundary, SELinux and other
platform coverage is not established.

With the pinned libc/headers, 2.6.0 configure detects no libc xattrat/openat2
functions, but enables the shipped openat2 syscall wrapper and warnings.
The headers omit xattrat syscall numbers: its shipped wrappers return
`ENOSYS` without issuing those syscalls, then the compatibility operations
succeed. Native openat2 directory lookup and symlink rejection were tested.
No injected fallback, native xattrat syscall, or older-kernel coverage is
claimed. No runtime or versioning fixes are backported.


## Current authoring validation

The historical observations above retain their original scope. The current
family-authoring pass qualifies only the selected outputs recorded in
`lib/MIGRATION-LOG.md`; it does not replay every historical release or waive
filesystem/platform skips.
Attr 2.6.0 and the historical 2.5.0 harness representative pass their normal
batches. The other two releases are evaluation-only in this authoring pass.
