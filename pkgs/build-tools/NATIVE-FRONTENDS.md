# Ordinary native build frontends

The selected pkg-config 0.29.2, Ninja 1.13.2, CMake 4.4.5 and Meson 1.12.1
use complete independent era procedures on source-owned compiler bases. Release
tables, package metadata and test dependencies are declared in each current index.
Earlier construction callers use the same family’s `instantiate` function with
explicit earlier bases and dependencies. A second retained recipe graph is not
exported by the ordinary families. Native x86_64 GNU/Linux is the supported mode.

Construction helpers select retained source-GNU host generations explicitly.
In particular pkg-config cannot use ordinary Python: ordinary Python discovers
its libraries with public pkg-config. CMake also uses the independent helper
interpreter. Ninja browse and Meson instead require the full public Python
runtime. Python's frontend test tools are declared test dependencies, outside
its production recipe arguments. This distinction prevents strict dependency
validation from forcing the Python/Ninja/Meson test cycle during construction.

All four procedures have artifact/final splits. Production source and compile
choices determine A; runtime/output repairs determine F. Runtime and test-only
edits reuse A when its actual inputs remain unchanged. Ninja's
compiled shell/Python and Meson's launcher/zipapp use the final runtime fields.
CMake's generated shell bindings use its final runtime shell. ELF finalization
uses the selected base and final runtime libraries. Tool overrides use the
existing public names, including `pkg-config`.

pkg-config exports explicit discovery providers on every owned projection.
Meson composes its selected pkg-config and CMake providers. A caller selecting
a different discovery tool alongside Meson must rebind Meson with `.override`;
conflicting providers remain errors. Explicit environment values retain their
usual precedence. CMake environment prefix lists use colons; cache lists use
semicolons. Legacy setup hooks remain installed for existing stdenv consumers;
native procedures and suites use explicit environments instead.

The normal suites preserve their original named behaviors with owned contexts.
Constructor probes exercise alternate source, compiler/base replacement, C/C++
execution, explicit environment edits, projections, test rebinding and ordered
edits. Installed profile probes retain raw logs as separate evidence outputs.
CMake uses its baseline `BUILD_TESTING=OFF` profile; selected RunCMake scripts
and real CTest consumers are bounded coverage. Ninja runs upstream syntax tests
and an installed browse service; its archive has no GoogleTest C++ harness, and
PTY tests are outside this profile. pkg-config runs its discovery suite and
vendored charset-object controls, not all bundled GLib tests. Meson runs eight
selected internal unit tests from both source and installed zipapp, alongside
native consumers; this is not its entire upstream suite.

Provider-origin, output ownership and runtime qualification are separate checks.
Family authoring or an available cached output alone does not establish a fully
qualified transitive runtime closure.
