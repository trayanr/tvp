Public GCC 16.2.0 exposes the complete upstream raw `gcc`, `g++`, `cpp`, `cc`
and `c++` programs. It uses the source-GNU candidate as its construction base,
not itself, and names the candidate's constrained target libc. Ordinary target
libraries follow their declared catalogue selectors. All construction and
upstream harness providers are explicit recipe arguments. The whole procedure
lives in `build-16.2.0.nix`; older procedures and the pinned private full compiler
remain independent.

The raw programs accept GCC's native operand/response-file semantics, `-B`,
`-nostdinc`, explicit include/link/startup flags, `-nostdlib` and `-static-pie`.
Public glibc 2.39 constructs its own headers, startup objects and libraries with
these interfaces, including stack protector, bind-now and static PIE. It still
reads `tvp.deps.glibc`, `platform` and the public raw paths. No selected consumer
wrapper is installed over these programs. Raw GCC does not interpret Nix wrapper
environment flags or imply a default hardening policy.
Raw-link tests explicitly supply `-rpath-link` for the selected compiler and
libc directories so the linker can resolve indirect ELF dependencies. These
link-time search paths are separate from the executable's runtime RPATH.

The existing candidate base separately selects the pinned private full consumer
driver, including its specs, aliases, runtime directories, operand/environment
flag handling and selected assembler/linker mechanism. Its rejection of static
PIE and non-native ABI modes belongs to that private consumer interface. The new
public compiler is not substituted into that driver or base. Raw `bintools`,
`libc`, `runtimeDirectories` and `rawCompiler` metadata describe the public
compiler; they do not declare it to implement the selected-driver protocol.

Customize raw target providers through `.override` arguments or `.edit`
specification fields such as `glibc` and `binutils`. This procedure has no
`runtime` schema for `.editRuntime`; adding arbitrary runtime data does not
change raw GCC's search paths.

`out` holds the raw compiler, plugin headers, LTO tools and matching target
runtimes. `validation` deliberately maps the reference `evidence` output to the
existing public API: `bootstrap-compare.log`, `stage_final`, `config.log`,
`stage2-objects.txt`, `stage2-objects.sha256`, `stage3-start.log`,
`test-environment.txt`, `invocation.txt`, `make-check.log`, `make-check.exit`,
all raw summaries/logs and `upstream.json`. Other command logs, stage flags,
installed ELF inventory and builtin specs are retained too. Both output siblings
come from the same derivation. Upstream checks include all seven make targets;
libquadmath/libsanitizer have compiler-integrated tests rather than standalone
summaries. The audit requires six completed summaries and retains known raw
19 FAIL / 2 XPASS outcomes. Later qualification must compare each full summary
multiset and make status with the historical control, not just these totals.

Source staging is not compilation or qualification. Canonical GCC is UNBUILT,
installed tests are NOT_RUN and the hardening gate is OPEN_UNWAIVED. A parent
source review must authorize the sequential full bootstrap separately. Default,
older, application and admission gates remain open.
