`tvp.builder` constructs opt-in native recipes. `tvp.builder.steps` supplies
ordered-plan editors and source helpers; `tvp.builder.outputs` supplies explicit
installed-output operations. MPFR 4.2.2 and Fontconfig 2.18.3 use the owned constructor. The other
build-step variants retain their existing adapter.

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
directories; }` provider. Contributions are scalar `values`, separator/entries
`paths`, and ordered `flags`. Compose base first, then tools; exact path dedup
keeps first position, flags retain repeats, and conflicts identify origins.
Executable lookup puts explicitly selected tools before base fallback tools;
provider contribution order remains base then tools. Path entries must be
nonempty and must not contain their separator.
Recipe `overrides` replace variables before conflict validation. Runner variables
are protected. Providers never recursively activate other tools or execute hooks.
Pkg-config supplies an explicit provider for selected public library interfaces.
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
