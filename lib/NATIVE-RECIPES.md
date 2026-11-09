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
a different output of the same derivation. The test runner explicitly realizes
multioutput jobs and tests alongside the aggregate: substituting a cached
aggregate alone may leave unreferenced sibling outputs absent. Split plans currently support only
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

Bzip2 1.0.8, zlib 1.3.2, XZ 5.8.4, Attr 2.6.0, ACL 2.4.0 and
libxcrypt 4.5.2 have selected owned recipes with explicit source, check,
installation and finalization steps. They retain one configured output prefix;
no compilation reuse across runtime edits is claimed. Historical construction
recipes and their test factories remain separately selectable. XZ, Attr, ACL and
libxcrypt explicitly add static archives to their prior shared-library layout.
ACL 2.4 uses Attr's error-context headers during compilation, without linking
libattr or publishing it as a public requirement; older ACL recipes retain
their original propagation.

Attr and ACL run upstream checks through independent libc capability probes.
Nix's syscall filter blocks xattr/ACL writes and set-ID modes. Only cases
requiring an unavailable operation exit 77; all other cases use the original
upstream runner. Unexpected probe errors and upstream failures still fail.
Skipped filesystem cases need separate non-root host validation; a successful
package build does not establish that coverage. Privileged and NFS cases keep
their upstream limitations.

An output-dependent development interface may be a pure function of the raw
package output (`development = output: { aclocalDirectories =
[ "${output}/share/aclocal" ]; };`). The owned constructor resolves it after
construction; it does not affect procedure inputs or execute hooks. Libtool
uses this for the actual installed macro directory, including customized outputs.

Git 2.56.0, GN 20260707 and the Gradle 9.3.1 distribution wrapper use the
source-GNU base for ordinary construction and regular tests. Their complete
legacy recipes remain independent. Git compiles source with the declared binary
Rust/Cargo tools and offline vendored dependencies. GN's build-only Python is
selected from the retained source-owned construction tools. Its local fixed-output
procedure preserves the flat Gitiles tree hash and rejects archive links/special
entries; reuse of the same cached output does not certify a fresh download.
Gradle retains upstream binary bytecode/native payloads and all.zip unchanged;
its explicit environment provider supplies GRADLE_HOME without running hooks.
For an output-relative public interface such as distributionArchive, `passthru`
may be a pure function of the raw output, like `development`. This does not add
commands or dependencies to existing specifications.

LibYAML 0.2.5, Ruby 3.4.10 and Bundler 2.5.20 also select the source-GNU
base and owned regular test contexts. Their independent native procedures leave
historical release procedures complete. LibYAML preserves shared/static archives,
headers and pkg-config metadata and runs upstream checks. Ruby 3 retains a single
stage, shared libruby, UTF-8 gem installation and default YJIT, using the declared
binary Rust compiler only at build time. Turning YJIT off does not demand Rust;
this port does not introduce a source Rust bootstrap or Ruby 4's ZJIT interface.
Ruby's extension ELF scopes use its measured 3.4 layout and named runtime providers.
Bundler installs the pinned source gem locally with Ruby 3 and activates its exact
version, independently of Ruby's default Bundler. Its explicit environment provider
publishes GEM_PATH and RUBYLIB without executing installed setup hooks. Focused
controls cover offline install/lock/check/exec, an alternative interpreter wrapper,
Ruby native-gem compilation with the source compiler, and the retained independent
GCC 13 extension control. Other Ruby and Bundler reverse builds require separate
qualification.
