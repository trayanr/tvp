# Opt-in native BUILD Python and Meson

`source-python-meson.nix` adds CPython 3.12.5's existing BUILD-tool profile and
Meson 1.12.1 over the owned GNU base. Import it explicitly; no catalogue producer,
default, alias or earlier bootstrap Python changes.

Python retains TLS, hashlib, zlib, Bzip2, LZMA, static libpython embedding,
headers and truthful compiler/sysconfig metadata. The same eleven optional
modules as the existing profile remain disabled. Installation is single-stage
because prefixes, bytecode and development scripts refer to the final output.
Read-only installed extension modes are restored after ELF finalization.
`subprocess(shell=True)` selects owned Bash; libc's `os.system` contract is
unchanged.

Python alone selects the existing OpenSSL 3.0.21 catalogue source pin through
owned OpenSSL steps. Source OpenSSL 4.0.1 and its previous consumers stay exact.
The OpenSSL 4 experiment first failed on opaque ASN.1 fields, then removed
version-method symbols. A bounded adaptation built and passed local trusted,
untrusted and hostname TLS checks, but repeated upstream TLS connections still
failed after peer closure (`[SYS] unknown error`). The experiment and attempted
patch are retained in implementation evidence; no OpenSSL 4 compatibility claim
is made for CPython 3.12.5. The same peer-closure failures reproduced with
OpenSSL 3.6.3, including outside the sandbox. The existing stable-line 3.0.21
source pin passes all six targeted repeated-connection cases; neither rejected
provider is admitted to Python's native runtime permissions.

Meson installs a genuinely compressed zipapp, launcher and manual, without a
setup hook. Its `buildEnvironment` delegates pkg-config discovery to the selected
pkg-config tool and CMake discovery to the selected CMake. For example:

```nix
(base.environment {
  tools = [ f.meson ];
  libraries = [ f.prerequisites.zlib ];
}).env
```

This contributes both declared discovery interfaces. Consumers also declare any
build programs they execute (for example Ninja for CMake probes). Launchers
preserve explicit `NINJA`, `CMAKE`, `PKG_CONFIG` and `SHELL`. When declaring another
pkg-config provider alongside Meson, use `meson.override { pkgConfig = selected;
}` so its contribution and default agree; conflicting scalars remain errors.
Normal Python overrides rebind both the launcher and zipapp interpreter.

`source-python-meson-tests.nix` exposes focused consumers, constructor contracts,
source override probes and selected-provider TLS checks. The C/C++ fixture uses
both zlib discovery methods, shared/static libraries, an installed executable,
rebuild/no-op/reconfigure/failure checks, traced tool overrides and an offline
cached `.tar.xz` wrap. It reserves the installation prefix in the build RPATH,
allowing the existing store-preservation patch to retain immutable dependencies.
The eight pinned upstream Meson unit methods run separately against source and
installed zipapp modules. Python's pinned source test harness supplies regression
data while the tested standard library remains installed.

The separate origin/runtime observers independently require the previous audits,
then classify new source and native endpoints. Compiler/development references
remain visible in the full reference closure and grant no native runtime
permission. Raw upstream failures, skips and environment limits remain evidence;
these bounded checks do not establish full CPython/Meson conformance or promote
a default. Publication, parent review, CI and merge remain separate work.
