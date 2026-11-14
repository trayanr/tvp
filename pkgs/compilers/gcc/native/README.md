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

`out` holds the public raw compiler, plugin headers, LTO tools and matching
runtimes. Production now has exactly `[ "out" ]`; `^validation` is intentionally
no longer a sibling output. `package.validation` is the independent raw R producer.
The registered `upstream-audit` test consumes R without gating A or F. Existing
consumers of the attribute retain the same raw file names and classifier rules.
The private pinned compiler and its evidence output remain unchanged.

A retains mandatory real bootstrap/comparison, configure/install logs, stage flags,
stage_final, stage2 object hashes, builtin specs and installed ELF inventory under
nix-support/production. A's nix-support/upstream-build-tree retains patched source,
active stage3 compiler/target libraries and generated build prerequisites with
modes, hardlinks and timestamps; obsolete stage1/2 object trees and installation
staging are excluded. Checkpoint size and actual check-target sufficiency are
UNKNOWN until later qualification. No external filesystem or NAS retention is used.
R restores a private copy, rebases only generated text roots if necessary, and
runs the same seven DejaGNU targets without invoking bootstrap/production all.
Summaries/logs and make status remain raw. U keeps the current strict requirement
on make status and six completed summaries, with the unchanged known raw
19 FAIL / 2 XPASS rules. No compatibility observation becomes strict acceptance.

GCC configures with stable `/tvp/gcc` plus DESTDIR staging. F whitelists installed
bin/include/lib/lib64/libexec/share only, transports supported text metadata and
exclusive dynamic RPATHs (including A/lib), and repairs ELF interpreters. It never
copies checkpoint or provenance. Native executable-relative GCC search remains
responsible for self discovery; no consumer wrapper or stage-evidence protocol
is introduced. The ordinary raw -B/static-PIE/libc-construction API remains intact.

Field classification:

* A: src/version/layoutPatch/patches, tuple/configurePrefix/configureFlags,
  libcFlags/linkFlags, glibc/binutils and target libraries, base/compiler and
  bootstrap flags, checkpointScript and normal configure/bootstrap/install tools.
  These are genuine compile inputs; no runtime alias promises their independence.
* F: finalizerScript, patchelf and final copy/interpreter/check steps. Final step
  edits reuse A; direct shared tools still retain their A effects where used.
* R: dejagnu/expect/flock/graphviz/fonts/pythonConfig and upstreamCapture/
  upstreamSummarizer/upstreamRestore; edits reuse both A and F.
* U: upstreamClassifier and unchanged known-result data; classifier edits reuse R
  as well as A/F. The existing independent test factory registers U.

One later bounded latest bootstrap must measure and test checkpoint restoration
without production rebuilding, compare full raw summary multisets/statuses with
the retained baseline, and exercise raw C/C++/LTO/plugin/fixincludes/static-PIE/
libc construction and native runtime/self paths. Emitted layout and final A
exclusion remain later proof requirements, never waived by source contracts.

Source staging is not compilation or qualification. Canonical GCC is UNBUILT,
installed tests are NOT_RUN and the hardening gate is OPEN_UNWAIVED. A parent
source review must authorize the sequential full bootstrap separately. Default,
older, application and admission gates remain open.
