# Selected GCC test harness

`import ./source-gcc-test-harness.nix { }` exposes `tcl` (8.6.18),
`expect` (5.45.4), `dejagnu` (1.6.3), and `flock` (GCC 16.2's Perl fallback).
The composition reuses the source-native compiler and full-compiler prerequisite
endpoints. It does not change ordinary package selections or build a full GCC.

Tcl provides threaded shared Tcl, its script library and timezone data, `tclsh`
and `tclsh8.6`, headers, `tclConfig.sh`, pkg-config metadata and the upstream stub
archive. It links the selected external zlib and retains the matching unwinder
for pthread exit/cancellation. Expect provides the executable, shared extension,
headers and scripts. Its public development dependency is the selected Tcl.
For loading Expect from a separate Tcl process, set `TCLLIBPATH` to
`${expect}/lib/expect5.45.4`; the Expect executable resolves its libraries directly.
DejaGNU installs the real runner and support files, with a sibling `expect`
symlink preserving upstream discovery through `argv[0]`. Runner execution needs
the declared shell utilities on PATH; no legacy setup hook is required.

Expect's original configure probes require a scoped GNU89 C setting with modern
GCC. Explicit environment replacements remain supported. Tcl's optional bundled
Thread/TDBC/Itcl extension builds are outside this core selection; Tcl itself is
threaded, and its native thread creation/join/exit API is tested.

The `flock` command implements **only** `--exclusive 1`, exactly as upstream.
It locks stdout's inherited open-file description. The caller opens the lock
file for writing and retains that descriptor until execution finishes. Installing
it as `flock` makes libgomp's normal program lookup select it; the upstream
configure Perl fallback is also retained in the compiler source. It is not a
general util-linux replacement.

Each interpreter recipe has separate `out` and `evidence` outputs. Raw upstream
statuses and logs remain visible, including limitations of the build sandbox.
A zero exit alone never establishes upstream test success. The installed checks
exercise Tcl evaluation/regexp/zlib and embedding/stubs, extension loading,
process mappings, real Expect PTY interactions, native DejaGNU C/C++ compilation,
result rejection controls, and the actual libgomp lock wrapper with concurrent
Tcl parents. PTY availability is measured explicitly; a host control, when needed,
has a distinct scope from sandbox testing.

`source-gcc-test-harness-tests.nix` exposes `consumer` and pure customization
`contracts`. The origin observer requires the existing prerequisite observer and
compares overlaps before union. The runtime observer independently inspects ELF
loaders, dependencies, RPATHs, scripts and loaded extension mappings. Construction
and development references do not grant execution permission to a new ELF.

This batch covers the harness core only. Python pytest/schema validation,
Graphviz PNG/SVG and fonts, and full GCC test-suite execution remain separate work.
