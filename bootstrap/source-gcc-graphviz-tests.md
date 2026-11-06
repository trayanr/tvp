# Source-owned GCC diagram test tools

`import ./source-gcc-graphviz-tests.nix {}` selects an opt-in rendering floor.
`packages.graphviz` supplies the real installed `dot`, core SVG renderer,
GD PNG renderer and native dot-layout plugins. libltdl loads installed plugins
from the immutable `lib/graphviz/config6` registry. It does not require a host
plugin directory or `LD_LIBRARY_PATH`.

The composition reuses the existing source native compiler, capability libc,
CMake, Ninja, Python, Meson, Bison 3.8.2, M4 and GNU construction tools. New
Flex, Gperf, Expat, FreeType, Fontconfig, libpng, libgd, libltdl and Graphviz
code builds with the capability toolchain. Reused construction programs retain
their earlier, separately measured runtime generations.

libgd enables PNG, FreeType, Fontconfig and its built-in GIF codec. JPEG, TIFF,
WebP, HEIF, AVIF, XPM, imagequant, RAQM, OpenMP and GUI acceleration are absent.
FreeType supports zlib and bzip2 compressed fonts; PNG, Brotli and HarfBuzz are
absent. Graphviz omits Pango/Cairo, X11 interfaces, language bindings and SFDP.
The narrow FindGD patch queries the actual native library rather than guessing
codec support from the presence of `gdlib.pc`.

`fonts` contains the upstream DejaVu 2.37 pre-generated Sans and Sans Mono TTF
**data artifacts**, their upstream license and an explicit Fontconfig file.
They are not executable seeds or fonts compiled from source. Select the profile
with `FONTCONFIG_FILE=${fonts}/etc/fonts/fonts.conf`; use a writable `HOME` and
`XDG_CACHE_HOME` for caches. The config names only those immutable font roots.

Development interfaces are explicit dependency metadata. FreeType exports
`include/freetype2`; pkg-config discovery uses the selected providers' `.pc`
directories. No setup hooks or hidden dependency resolution run. Recipes support
`override`, `edit`, and `editSteps`, including replacement sources and bases.
Fontconfig is selected directly through its authoritative owned procedure.

`source-gcc-graphviz-validation.nix` builds installed C/C++ consumers and checks
GCC's unchanged `dg-check-dot` procedure (`dot -O -Tpng FILE`), a compiler-produced
flow graph, and the HTML-table DOT expected by GCC's `graphviz.cc` selftest through
`dot -Tsvg`. It checks SVG labels, nodes and edges, decodes PNG pixels, distinguishes
real glyphs, validates selected font resolution, and rejects malformed input,
unknown formats, missing plugins and missing fonts. Native loader traces cover
registry-discovered plugins. Upstream test logs and statuses are separate evidence
outputs; installed probes do not imply complete upstream conformance. The reused
compiler has no analyzer, so its analyzer and full-compiler suites remain later work.

`source-gcc-graphviz-origin-audit.py` requires the prior Python/core construction
observers and independently compares their overlap. The runtime observer requires
the prior observers, rechecks prior ELF providers, and inspects new ELF loaders,
DT_NEEDED, RPATHs, installed interpreters and actual plugin loads. Font data grants
no executable permission. These opt-in files do not select catalogue/defaults.
