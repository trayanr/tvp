# Ordinary shared Perl 5.24.4–5.42.3

Three complete procedures cover the Errno header/GCC probe boundary, the later
preprocessor fallback, and the modern source/test-helper layout. The original
constructors, patch records and non-native definitions remain available through
`constructionRecipe`. Perl 5.44.0 keeps its independent unsplit procedure.

Each procedure installs an artifact before finalization and selects
`artifactName = "${final.pname}-${final.version}"`. Equal-width prefixes keep
compiled string lengths, positions, terminators and pooled suffix addresses
valid without changing upstream's shared-library or include-path code.

`prepare.py` validates the complete source namespace and every selected text,
frontend and exact patch context before writing. Its inputs include build-time
pwd and diff. `elf-finalize.py` is a separate final-only input. It validates the
whole installed namespace, UTF-8 metadata, contained links and hardlinks, ELF
inspection, allowed readonly library strings, and dynamic path ownership before
writing. It changes only equal-width compiled paths and uses Patchelf for RPATHs.
It deliberately preserves internal hardlinks and rejects external aliases.
Every hardlink alias contributes its metadata and runtime role. Dynamic-string
ownership includes loader tags, exported symbol names and version requirements;
sharing any RPATH bytes or using an unsupported consumer rejects the whole plan.

The finalizer rebinds old Cwd's build pwd to `runtime.pwd`. Final steps run bare
include/core/Config checks and an all-file artifact-reference audit. Installed
tests additionally compile fresh XS and a shared-libperl embedding executable.
Caller `outputChecks` are not used as a substitute for these checks. The generic
constructor still excludes artifact references independently.

The 5.24.4 and 5.28.3 definitions explicitly classify the shipped Time::Local
rolling-century defect. In 2026 its test passes two-digit year 70, the module
returns 2070 and two assertions expect 1970. The unmodified upstream harness runs
in full; raw FAIL, exit 2, SKIP and XPASS diagnostics remain in the build log.
`check.py` permits installation only for that exact sole summary (Local.t,
assertions 6 and 12, got 170 versus expected 70). Every other failure is fatal.
The complete summary and terminal Make status must match; a no-TAP crash,
extra record or parse error cannot disappear from classification.
This classification is an unwaived upstream nonpass, not an upstream PASS.

Pure effective-field controls live in `tests/ordinary-contracts.nix`; production
mutation guards in `tests/ordinary-guards.py`. The classifier and retained-artifact
dynamic-string regressions live in `tests/ordinary-check-guards.py` and
`tests/ordinary-dynamic-guards.py`. They need no Perl compilation. The older experiments
remain historical evidence and are not imported by these procedures.
