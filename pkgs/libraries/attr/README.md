# Attr

Packaged releases: 2.5.0, 2.5.1, 2.5.2 and 2.6.0. The older pair forwards
to the unchanged 2.5.2 recipe; no source patches or dependency changes are
needed. Existing consumers remain pinned to 2.5.2. `attr` and `attr_2` select
2.6.0; `attr_2_5` selects 2.5.2.

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
