Latest native Autoconf 2.73 and Automake 1.19 use the source GNU base and owned
builder. Their complete former factories remain in `legacy.nix`; bootstrap
construction and historical test contexts select these factories explicitly.
Historical releases and other platforms keep the compatibility recipes.

Both procedures use shipped configure scripts and Makefiles. Source preparation
preserves timestamps, so production never needs the pair to regenerate itself.
Perl programs embed their installed prefix and data paths; each package therefore
uses one stage. The seven Autoconf commands retain direct selected Perl shebangs,
embedded M4 defaults, sibling paths and upstream environment overrides. Explicit
owned tool directories supply the shell-string utilities used by Perl. The caller's
PATH remains available for peer commands such as Automake and libtoolize.

Automake exports a pure `buildEnvironment` provider. Select it in an owned
consumer's `environment.tools`, with macro packages in `environment.libraries`.
Each package can publish `development.aclocalDirectories`; the default is its
`share/aclocal`. The base composes these into ACLOCAL_PATH. Explicit environment
overrides replace the composed value. No installed setup hook executes in the
owned builder. Automake still installs its legacy hook for compatibility consumers.
Upstream ACLOCAL_PATH, ACLOCAL_AUTOMAKE_DIR, AUTOMAKE_LIBDIR and `-I` behavior
remains available when invoking the installed programs directly.

Own suites run configure/header generation, out-of-tree C builds and installs,
substitution, forced autoreconf, tracing/cache/scan/update, versioned aliases,
tool/data overrides, independent macro providers and source/base/interpreter edits.
Check-only package edits run upstream suites after both installed tools exist;
upstream failures propagate and are never turned into a successful qualification.
