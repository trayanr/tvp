# ACL releases

2.3.0 and 2.3.1 forward to the unchanged 2.3.2 build procedure, retaining
propagated Attr 2.5.2. The existing 2.3.2 definition and recipe remain intact.
2.4.0 has a separate recipe: upstream removed libattr linkage, but configure
and `perm_copy_*` still require `attr/error_context.h`, so the same exact Attr
is a build input without propagation. Installed `sys/acl.h` and `acl/libacl.h`
do not include Attr; consumers defining the optional `struct error_context`
need an explicit Attr header dependency.

All four releases were built with the existing GCC 13.3.0, glibc 2.39 and
Linux 6.9 headers. Inspection of installed ELF dependencies and runpaths,
direct store references and the full output closure confirms that 2.4.0 has
no Attr runtime reference. Its closure consists of ACL, glibc and Linux
headers. Ordinary independent public-header and pkg-config consumers pass.
This is an observed output result, not an inference from removed linkage.

The SONAME is `libacl.so.1`. Both development and SONAME symlinks resolve to
`libacl.so.1.1.230` for 2.3.0, `libacl.so.1.1.2301` for 2.3.1,
`libacl.so.1.1.2302` for 2.3.2 and `libacl.so.1.2.2400` for 2.4.0. The original
2.3.0 revision is deliberately preserved. No upstream runtime fixes or
versioning corrections are backported.

## Validation

The original `version` and `operation` test leaves are unchanged, including
canonical and construction selections. Additional leaves cover exact-path
`dlopen`/symbol resolution, SONAME/symlinks, text/from-mode equivalence and
permissions, public headers, pkg-config, private-file named/default ACLs,
copy and inheritance, command-line restore, and strict upstream filenames.
Filesystem rejection (`ENOTSUP`/`EOPNOTSUPP`) is explicitly logged as SKIP;
other errors fail. The build sandbox native, `_at` and CLI fixtures skipped named ACLs. Separate
owned temporary-file runs passed the native C and CLI fixtures on all four
releases, rather than counting a sandbox skip as native success.

2.4.0 tests use the actual exported `acl_get_file_at`, `acl_set_file_at`,
`acl_delete_def_file_at` and `acl_extended_file_at` signatures. They cover
relative dirfd paths, empty-path descriptors, following/refusing symlinks,
invalid flags, and setting/deleting directory default ACLs. Native symlink
ACL operations returned `EOPNOTSUPP`; following the same link succeeded.
Physical restore refuses final and intermediate symlinks; nonphysical
restore emits the upstream warning. Malformed input, numeric overflow and
`--restore --test` permission preservation are also covered.

Historical controls retain 2.3.x behavior: leading-whitespace restore names
lose their whitespace, overflowing numeric UID/GID 4294967296 truncates to
zero, and restore follows symlinks without the 2.4.0 warning. Tests compare
these exact observations with the corrected 2.4.0 controls; they do not patch
old releases or classify the entire release as broken.

Configure selected the shipped openat2 wrapper and xattrat compatibility
objects, not libc implementations. Linux 6.9 headers lack the new xattrat
syscall numbers, so shipped wrappers return ENOSYS without issuing those
syscalls; native traces show `/proc/self/fd` paths and legacy xattr syscalls.
Physical restore's openat2 syscall succeeded natively. An explicitly injected
openat2 ENOSYS made physical restore fail with "Function not implemented".
That injected result is not old-kernel coverage. Native xattrat, long-path
fallbacks and newer-kernel O_PATH workarounds were not verified.

## Supplemental upstream harness

The upstream Perl harness, helper bodies and test files were kept unmodified
and their hashes rechecked. Explicit Perl invocation and an exported helper
function supply unavailable `/usr/bin/perl` shebangs; `testlookup` is preloaded
with upstream passwd/group fixtures. `getfattr` is from the exact owned Attr
2.5.2 input. Initial raw interpreter failures and subsequent results are both
retained in the external evidence.

All nine ordinary `.test` cases pass for each 2.3.x release. All ten ordinary
`.run` cases pass for 2.4.0: seven unconditional and the three
`UNSAFE_RESTORE_WARNINGS` cases (`restore`, `sbits-restore`, `utf8-filenames`).
Four root/user-switching cases per release were not executed. Both NFS cases
are declared XFAIL upstream. The bounded local `nfsacl` observation initially
XFAILed because of `ls` timestamp columns; with the expected long-ISO format
it XPASSed (and the unmodified harness correctly exited nonzero). This does
not verify NFS: the NFS prerequisite was absent. `nfs-dir` was not executed
because it requires root switching, a loopback NFS export, root-squash and
`EXPORT_PATH`. NFS protocol, root-squash, SELinux policy variants and other
filesystem limits remain unsupported coverage.

## Upstream tracking

The Savannah directory adapter extracts complete archive tokens, retaining
misleading prefixes and trailing junk/signatures for the strict normalizer
to reject. Only numeric `acl-X.Y.Z[.src].tar.gz`/`.tar.xz` names normalize;
compression variants deduplicate in the tracker. The verified index has 14
archives representing 10 releases. Four are packaged here; the six remaining
releases are 2.2.48 through 2.2.53. No unavailable declaration is inferred
from a failed fetch. Archive hashes and embedded versions were rechecked;
detached signatures were not authenticated.
