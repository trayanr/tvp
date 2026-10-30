# GNU tar

1.32–1.34 use the unchanged 1.35 recipe with ACL 2.3.2 and Attr 2.5.2.
Latest remains 1.35; existing consumers keep their pins.

Two historical behaviors are retained and tested against newer controls:

- 1.33 creates directory members during `--extract --to-stdout`.
- 1.32 changes empty-directory modes despite `--no-overwrite-dir`.

Shared tests cover GNU/ustar/PAX archives, links, long/quoted names, bounded
sparse files, directory modes and owned gzip/bzip2/xz/zstd helper execution.
ACL and user-xattr roundtrips passed natively. Unsupported sandbox probes retain
explicit SKIP results and errno logs; other probe errors fail.

Unmodified upstream check and installed-package installcheck passed for all
four releases. Optional lzip/lzop, privileged ownership, SELinux/capabilities,
large-file and external STAR-corpus cases retain their prerequisite skips.
Bounded sparse fixtures cover 8 MiB logical files. Passing ordinary checks
does not establish those omitted capabilities.

The GNU tracker accepts complete numeric `tar-VERSION.tar` filenames, including
optional gz/bz2/xz/lz compression, and rejects surrounding junk and signatures.
It finds 67 archive variants / 28 releases, including uncompressed 1.13:
four packaged, 24 missing. Archive hashes and source versions were checked;
detached signatures were not authenticated.
