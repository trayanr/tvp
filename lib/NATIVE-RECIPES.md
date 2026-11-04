`tvp.builder` constructs canonical and opt-in native recipes. Its `steps`
namespace supplies ordered-plan editors and source helpers; `outputs` supplies
explicit installed-output operations. MPFR 4.2.2, Fontconfig 2.18.3, Zstd 1.5.7,
Ruby 4.0.6 and JSON-C 0.19 use the owned constructor for both canonical and
build-step selectors. MPC 1.4.1 also uses the owned constructor; older MPC
releases retain their legacy recipes. Historical construction controls retain
their explicitly selected recipes.

A recipe accepts ordinary dependency arguments and returns specification data,
or `final: { ... }`. `final` is the edited specification. Put editable
`environment`, named `environments`, `runtime` and `plan` data beside each other;
derive command fields through `final.base.environment final.environment`.

`.override` accepts argument replacements or a function of current arguments.
`.edit` transforms the specification. `.editSteps` and `.editRuntime` transform
its plan and runtime fields. Edits accumulate in order and replay after argument
overrides. Unknown arguments, missing edit targets and duplicate names fail.
Tests, provenance and output projections follow the customized package.
`overrideAttrs` is not part of the owned API.

Plans contain named executable records and optionally one `steps.split` marker.
The marker accepts only `kind` and `name`. After editing, the constructor
partitions the plan, requires enabled commands in each partition, then selects
active inputs independently. Disabled command payloads remain lazy. The owned
path lowers directly to Nix derivations without inherited setup hooks. Each
command receives a fresh shell and temporary directory; the runner preserves
logging, failure and cancellation behavior.

Specifications may declare `outputs = [ "out" "validation" ];` or
`outputs = [ "out" "bin" ];`. The default is `[ "out" ]`; `out` must be first.
Names are unique, context-free lowercase shell identifiers (`[a-z][a-z0-9_]*`);
constructor, primitive and projected metadata names are reserved. Every fresh
command receives the declared build paths. In multioutput plans these variables
are read-only and cannot be supplied through step `env`. Output paths are build
locations, separate from package environment contributions.

Named projections (`package.validation`, `package.bin`), `all`, tests, provenance
and customization retain the selected output. `lib.getBin` and `lib.getOutput`
select the corresponding path. Tests continue to describe the customized whole
package. Test plans retain the selected output as each occurrence's link target,
and verify the complete declared output set even when another occurrence selects
a different output of the same derivation. Split plans currently support only
`[ "out" ]`; combining a split with multiple outputs fails at evaluation. Use an
unsplit plan when installing to multiple compiled prefixes.

With a split, compilation installs a stable artifact. Finalization receives
read-only `TVP_ARTIFACT_ROOT` and a fresh workspace/output. `copyArtifacts`
copies independently; `relocateText` rewrites only declared text files. Export
necessary handoff data explicitly. Nix rejects final references to the internal
artifact output. Relocation of other formats requires an explicit operation.

`outputs.rpaths { base = final.base; libraries = final.runtime.libraries; ...; }`
selects authoritative non-base ELF lookup paths, retains required base/self
paths and declared dlopen directories, and removes superseded paths. It rebases
artifact self RPATHs onto the copied output before shrinking. Library
directory exceptions use the selected provider's `development.libraryDirectories`.
`elfKinds = [ "runtime" ]` validates and skips relocatable objects in mixed trees.
It does not relink or establish ABI compatibility. No global `LD_LIBRARY_PATH` is used.
`outputs.development { libraries = [ dependency ]; ...; }` publishes the same
selected public requirements as evaluation and installed propagation metadata.
Consumers follow these requirements, without inheriting the producer's build
tools. Standard include/lib/pkg-config directories can be overridden through
the specification's `development` interface.

Explicit tools may export a pure `buildEnvironment { tool; libraries;
directories; base; ... }` provider. The base is explicit selected data.
Contributions are scalar `values`, separator/entries `paths`, and ordered `flags`. Compose base first, then tools; exact path dedup
keeps first position, flags retain repeats, and conflicts identify origins.
Executable lookup puts explicitly selected tools before base fallback tools;
provider contribution order remains base then tools. Path entries must be
nonempty and must not contain their separator.
Recipe `overrides` replace variables before conflict validation. Runner variables
are protected. Providers never recursively activate other tools or execute hooks.
Pkg-config supplies an explicit provider for selected public library interfaces.
CMake adds development prefixes and the selected base libc without compiler
probes or hooks. Its native `CMAKE_PREFIX_PATH` uses colons; cache-list arguments
use semicolons. `steps.cmake` prepares explicit selected CMake/CTest/Make calls,
Unix Makefiles, Release, libdir=lib, disabled registries and the generator install
target. Editable flags and source/build directories stay ordinary helper inputs.
The current owned flag encoders support the three frozen `NIX_*FLAGS` protocols:
nonempty whitespace-free arguments only, with commas also rejected in
`NIX_LDFLAGS`. Other flag protocols require their own encoder. Unsupported
encodings fail explicitly; direct compiler argv remains available.

Fontconfig uses a single stage (zero `steps.split` markers). Upstream Linux
embeds its configuration, template and cache paths in the library. Runtime
edits therefore rebuild this recipe; no compilation reuse or binary relocation
is claimed. Its explicit source shebang operations cover the enabled Python
generators and installation scripts. The fifteen enabled native Meson tests
run unless `doCheck = false`; this flag skips execution without disabling their
build-time generation. Optional pytest, external fonts, bwrap, docs, locales,
Fontations and installed static libraries are outside this recipe's coverage.
The public development interface exposes FreeType headers and the selected
private pkg-config requirements; runtime providers remain separately editable.

Zstd and JSON-C split compilation from finalization, as MPFR does. Fontconfig
and Ruby keep one stage because compiled data embeds configuration/load paths.
Runtime fields are recipe data consumed by explicit output operations. Ruby's
named providers derive its library summary; conflicting summary edits fail.
JSON-C needs no external runtime providers by default. Edits to
`runtime.libraries` or `runtime.dlopenDirectories` configure additional lookup
paths. Custom runtime fields can also supply user-inserted steps.
An ELF lookup edit does not establish linkage or ABI compatibility.

MPC 1.4.1 splits shared-only compilation from runtime finalization. Its public
interface exports the selected GMP and MPFR headers and pkg-config requirements.
Runtime provider edits preserve compilation inputs and configure MPC's own ELF
lookup. A consumer that links MPFR directly may select that same-SONAME provider
first; the MPC-only numeric probe verifies producer lookup separately. The tested
MPFR 4.2.1 substitution is a concrete compatibility check, not a general ABI promise.
