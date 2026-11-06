# Source GCC Python test tools

`import ./source-gcc-python-tests.nix { }` provides `profile`, `packages`,
`sources`, and the previously selected `harness`. Put `${profile}/bin` on PATH
for `python3 -m pytest`, `pytest`, and the genuine `check-jsonschema` command.
This opt-in composition reuses Python 3.12.5, the native compiler, and the
capability libc. Ordinary package definitions and compiler selections are unchanged.

The compatibility selection uses pytest 8.3.2, check-jsonschema 0.23.3, and
jsonschema 4.17.3. The CLI's own source metadata permits jsonschema >=4.5.1,<5,
requests <3, click >=8,<9, and requires ruamel.yaml 0.17.32. The engine uses attrs
and pyrsistent rather than rpds/Rust. A narrow source patch initializes the CLI resolver with the engine’s dialect-specific
`ID_OF` function: Draft04 uses `id`, while newer drafts use `$id`. Unpatched
0.23.3 tries to fetch the absolute SARIF identifier for local internal references.
The patch preserves the CLI, its validation engine and all GCC schema files.
Exact upstream sdists and hashes are in
`source-gcc-python-sources.json`; evaluation never contacts upstream.

All runtime modules and packaging backends have explicit source inputs. The
common PEP 517 recipe invokes the upstream backend and installs the wheel just
built locally, including distribution metadata, resources, and genuine entrypoint
functions. It performs no dependency resolution or downloads. Setuptools,
Flit Core, Hatchling, Hatch VCS, the README metadata plugin, setuptools-scm,
Wheel, and their dependencies are built from source too. Their in-archive
vendored Python sources retain that archive's provenance. Windows binary
launchers are omitted; Linux scripts use the selected source interpreter.

Pyrsistent's upstream `PYRSISTENT_SKIP_EXTENSION` selection, charset-normalizer's
non-mypyc mode, ruamel.yaml's Python 3.12 pure implementation, and PyYAML's
`PYYAML_FORCE_LIBYAML=0` test dependency avoid optional accelerator extensions.
Cython is installed from its Python sources in upstream uncompiled mode solely
to satisfy PyYAML’s declared test-build backend requirement; no native compiler
or interpreter is rebuilt. These modes retain the real parsers and persistent data structures. The selected
format providers cover URI references, date-time and the other standard
jsonschema format checks, including rfc3987. JSON5 is also installed for the
CLI’s optional input format. No schema validation or GCC test is replaced.

The profile and installed script launchers set declared module paths and disable
user site-packages. An explicitly supplied PYTHONPATH is appended, allowing GCC
to expose its own `sarif` helper. Clean-environment checks require no such rescue.
Normal recipe input overrides, specification edits, environment replacements and
step edits remain available. Shared code implements the single generic PEP 517
procedure; no versioned recipe imports or overrides another versioned recipe.

`source-gcc-python-validation.nix` exposes the optional `consumer` and pure
customization `contracts`. Production outputs do not depend on test evidence.
Installed tests validate both actual GCC SARIF schemas (Draft04 and Draft2020-12),
valid and invalid documents, newer draft semantics, malformed schemas, format
errors, missing tools/modules, and real compiler-generated SARIF. They run the
actual GCC Python test and unmodified `run-sarif-pytest` Expect parser.
The source snapshot has no separate `lib/pytest.exp`; the procedure is in
`lib/scansarif.exp` (HTML has its own corresponding procedure).

Bounded upstream pytest, jsonschema and CLI suites produce raw logs and JUnit
records whose outcomes must agree with completion summaries. This is a test-tool
qualification, not full GCC conformance. Full compiler execution and Graphviz
rendering remain separate. The construction observer requires the prior core
observer and compares overlapping nodes before union. The runtime observer
requires the prior runtime proof, scans the reused Python ELF modules, checks
actual process mappings and loaders, and gives pure Python sources no new native
execution permissions.
