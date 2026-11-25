# Redis core

The package provides the core server, CLI, benchmark, inspection and Sentinel
commands. Both Redis 8.10.3 and 8.12.0 build TLS with TVP OpenSSL and replication
compression with TVP Zstandard. Applications can enable a TLS listener and
configure `repl-compression` with more than one I/O thread. The build uses libc
allocation. Jemalloc, systemd, and the separately built Redis modules are
outstanding package features.

Compilation/installation and final runtime repair are split into independently
cached producers. The package does not start a host service or install a
configuration with unbuilt module paths. Applications supply configuration or
explicit server arguments. Installed checks cover the server and CLI versions,
a Unix-socket PING/SET/GET exchange, and a mutually authenticated TLS exchange.
The TLS check also verifies that Redis accepts the replication compression level
at startup and retains it when queried over TLS.

Upstream Redis 8's `LICENSE.txt` offers RSALv2, SSPLv1 and AGPLv3 alternatives.
This package selects AGPLv3 and installs the complete upstream license text.
