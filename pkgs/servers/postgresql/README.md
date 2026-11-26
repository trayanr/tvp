# PostgreSQL build features

TVP installs the server, client commands, libpq, PGXS, and bundled contrib
modules. The build enables TLS, GSSAPI, ICU, LDAP, PAM, XML and XSLT, translated
messages, PL/Perl, PL/Python 3, PL/Tcl, and the `uuid-ossp` extension with
util-linux's libuuid provider. The installed integration check loads all three
procedural languages and the `xml2` and `uuid-ossp` extensions into a temporary
server and exercises their behavior.

| Feature | Release coverage |
| --- | --- |
| LZ4 compression | PostgreSQL 14 and later expose `--with-lz4`. |
| Zstandard compression | PostgreSQL 15 and later expose `--with-zstd`. |
| NUMA | PostgreSQL 18 and later expose `--with-libnuma`. |
| LLVM JIT | 14.23, 15.18, 16.14, 17.10, 18.4, and 19.0 onward in their respective series. Those releases support the ORC allocation API used by TVP's LLVM 23. PostgreSQL 10 has no JIT. PostgreSQL 11–13 and earlier minors of newer series require a compatible older LLVM or an upstream compatibility backport. |

The following integrations need additional source-owned TVP providers:

| Feature | Prerequisite |
| --- | --- |
| SELinux (`--with-selinux`) | libselinux headers and library for the bundled `sepgsql` extension. |
| systemd notifications (`--with-systemd`) | The libsystemd daemon development interface. |
| Asynchronous I/O through io_uring (`--with-liburing`, PostgreSQL 18 and later) | liburing headers and library. |
| Bonjour service discovery (`--with-bonjour`) | A source-owned DNS-SD implementation that supplies the `dns_sd.h` API and library on Linux. |
| HTML and manual-page generation | DocBook stylesheets, the DocBook XML DTD and an XSLT command configured to resolve them locally. |

Upstream describes the available configure options in the
[PostgreSQL 10 build guide](https://www.postgresql.org/docs/10/install-procedure.html)
and the [PostgreSQL 19 build guide](https://www.postgresql.org/docs/19/install-make.html).
