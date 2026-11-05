# Opt-in GNU libc capabilities

`nix build --file bootstrap/gnu-libc-profile.nix libc` selects a separate glibc
2.39 output. The reduced `gnu-libc`, existing compiler/wrappers, environment,
catalogue selectors and frozen construction are unchanged. There is no new
compiler generation, public base, default switch, or `mkDerivation` interface.
Sources reuse the pinned glibc archive and GCC16 fnmatch diagnostic patch.
Construction uses the existing source-owned bootstrap tools; host Nix and the
Linux kernel remain explicit external assumptions.

The profile installs only C.UTF-8, using its matching new localedef. It retains
locale, localedef, iconv and iconvconfig, with the complete installed gconv module
and metadata set. No minimal converter-set claim is made. Tests measure
UTF-8 ↔ ISO-8859-1 and UTF-8 ↔ UTF-16LE, including invalid, incomplete and
output-buffer exhaustion cases. They identify loaded converter modules and libc
by their actual paths. Empty environments exercise compiled locale/converter
defaults without LOCPATH or GCONV_PATH.
The probe rejects supplied lookup variables as test preconditions; this does
not claim that libc forbids those variables.

Libc's system.c SHELL_PATH and generic/Linux paths.h _PATH_BSHELL point to the
**previous source-built GNU Bash** bin/sh. The dependency is deliberately:
new libc → prior GNU Bash → reduced GNU libc. These are two GNU libc generations
in an acyclic stage graph. Bash is not rebuilt recursively; this is not a final
self-hosted runtime or a fixed-point result. The source inventory records all
shell uses; oldiopopen's literal belongs to GLIBC_2.0–2.1 compatibility code,
excluded by the x86_64 GLIBC_2.2.5 baseline. The same paths.h binding also covers
execvpe's shell fallback. Other host/service defaults are not broadly rewritten.

`nix-build bootstrap/gnu-libc-profile-tests.nix` builds dynamic and static C
consumers with explicit new sysroot/startup-object selection. Link traces,
PT_INTERP/NEEDED/search inspection, direct new-loader invocation and installed
tool inspection establish new libc selection. Shell contracts check availability,
exact exit status, popen/pclose and wordexp command substitution, with a Bash path
guard that a host shell cannot satisfy. The previous compiler's defaults stay
unchanged. Static PIE remains unsupported; no fix for its retained raw startup
crash, C++ equivalence, or GNU generation comparison is claimed.

`gnu-libc-origin-audit.py` extends the source ledger while preserving the prior
owned runner profiles. `gnu-libc-runtime-audit.py` consumes a separate exact
profile assigning every executable output to one GNU generation and its loader
and library search roots. It checks actual loader resolution against selected
dependencies; it does not permit either loader globally. Source data never grants
executable permission. Source-built musl construction helpers are distinct from
the selected GNU runtime closure. Run its rejection suite with
`python -m unittest discover -s bootstrap -p test_gnu_libc_runtime_audit.py`.

This is focused capability coverage, not full glibc conformance. nscd, timezone
tools, profiling, mathvec and an all-locales installation are omitted. No NSS,
resolver, network service, timezone database, arbitrary-shell security,
reproducibility, or production readiness coverage follows. Retained converter
modules beyond the measured conversions are available but unqualified. Parent
review, scoped publication, CI authorization, merge and master reconciliation
remain separate steps.
