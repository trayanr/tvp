# Redis core

The initial package provides Redis 8.10.3's core server, CLI, benchmark and
inspection/sentinel commands. It builds the upstream source-shipped static
dependencies with the selected TVP base. The profile uses libc allocation and
does not include TLS, systemd, replication compression or the separately built
Redis Search/JSON modules. These are explicit future profiles rather than
undeclared downloads during a package build.

Compilation/installation and final runtime repair are split into independently
cached producers. The package does not start a host service or install a
configuration with unbuilt module paths. Applications supply configuration or
explicit server arguments. Two installed checks cover the server/CLI versions
and a short Unix-socket PING/SET/GET exchange, without the upstream suite.

Upstream Redis 8's `LICENSE.txt` offers RSALv2, SSPLv1 and AGPLv3 alternatives.
This package selects AGPLv3 and installs the complete upstream license text.
