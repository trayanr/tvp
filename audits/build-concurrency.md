# Build concurrency screening

The 2026-11-17 screening covers package recipes, shared build helpers, bases,
bootstrap recipes and CI/test tooling. Build concurrency comes from
`NIX_BUILD_CORES`; simultaneous derivations remain controlled by Nix's
`max-jobs`. There is no repository-wide numeric jobs or cores override.

## Corrections

| Area | Finding and correction |
| --- | --- |
| PHP | Six builders defaulted to serial execution. They now default to Nix's core budget; redundant per-release enables were removed. Explicit caller opt-outs remain supported. |
| PHP installation | PHP 5.4 serialized installation to hide a directory-creation race. The install now uses the selected Coreutils `mkdir -p` through `mkinstalldirs`. |
| OpenSSL | Production, installation and upstream helpers forced one job. They now use Nix's budget, including Perl harness workers. Legacy shared cleanup/link/alias stages are ordered, and OpenSSL 0.9.8 receives explicit archive/shared-library/engine prerequisite edges. |
| SQLite | Modern upstream runners fixed the worker count at eight. They now read `NIX_BUILD_CORES`. |
| Zlib | Test variants sharing `foo.gz` need prerequisite ordering. That dependency is expressed with a scoped `.NOTPARALLEL: test`; independent compilation retains Nix's budget. |
| Build frontends | Autoconf, Gettext and pkg-config fixed one job in selected phases. Those phases now use Nix's budget. Ninja's bootstrap self-rebuild also receives the budget instead of detecting host CPUs independently. |
| Install and consumer helpers | CMake, pkg-config, Patchelf, File and Less install commands, Meson test workers, and base/tool consumer builds now forward Nix's budget. Fixed four-job consumer builds were removed. |

The `build-concurrency` check evaluates build/install commands across every PHP
release and every buildable OpenSSL release. PHP contracts also cover inherited
defaults, explicit caller overrides and concurrent install directory creation.
The existing build-step runner tests cover forwarding explicit core values and
the missing-variable fallback.

## Intentional controls and remaining constraints

Fixed one/two-worker values remain in fixtures that test GNU Make/Ninja
jobservers, JDK `JOBS` validation and explicit caller overrides. Recorded fake
command lines, parser fixtures and source hashes are not execution budgets.
The fallback to one core when `NIX_BUILD_CORES` is absent is for standalone
helper invocation; it does not replace a supplied Nix budget.

Early bootstrap stages with documented parallel-build failures retain their
existing ordering constraints. These are explicit upstream/build-tool issues,
not evidence that every early bootstrap stage is parallel-safe:

| Recipe | Existing constraint |
| --- | --- |
| `bootstrap/recipes/gawk/mes.nix` | Autoconf-generated Makefile race under tcc-mes. |
| `bootstrap/recipes/gnugrep/default.nix` | Custom Makefile parallel race. |
| `bootstrap/recipes/gnused/default.nix` | Documented tcc-musl instability. |
| `bootstrap/recipes/gnumake/musl.nix` | Documented tcc-musl instability. |
| `bootstrap/recipes/gnutar/mes.nix` | Documented tcc-mes race. |
| `bootstrap/recipes/gnutar/musl.nix` | Documented tcc-musl instability. |
| `bootstrap/recipes/gzip/default.nix` | Documented early TinyCC instability. |
| `bootstrap/recipes/musl/tcc.nix` | Previously observed parallel failure. |
| `bootstrap/recipes/bash/2.nix` | Earliest shell lacks `nproc`; its missing/zero-core fallback remains explicit. |

Each remaining early-stage constraint needs its own dependency/compiler repair
and bounded bootstrap validation before its ordering can change. It must not be
copied into ordinary package defaults.
