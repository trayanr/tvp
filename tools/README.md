# Repository tools

All six apps are copied by `tools/lib/owned-cli.nix`, a direct derivation run by
TVP Bash with TVP coreutils. It installs explicit Bash shebangs and checks each
script with `bash -n` and ShellCheck (a borrowed build-time validator). It uses
no stdenv setup, wrapper hooks or compiler. Text manifests use `builtins.toFile`.

The four shell commands retain `errexit`, `nounset` and `pipefail`, and prepend
their declared tools in order to the caller's PATH. The Python entrypoints exec
TVP Python, forward every argument, and set `TVP_DEPENDENCIES_SYSTEM` or
`TVP_TEST_SYSTEM` from the selected native platform. They leave PATH alone.
The helper supports these scripts only; it is not a general packaging API.

Explicit runtime utilities and interpreters are TVP packages except jq, which
has no TVP recipe. Commands that query Nix use the caller's host Nix API.
Inherited bootstrap closures and the test runner's external strace boundary
remain separate from this packaging change. Ruby's extension tests retain an
owned GCC 13 consumer compiler as a control against GCC 16-built Ruby.

`tvp-test verify --run /absolute/frozen/run --output report.json` reads one
terminal full attempt without running status, evaluating source, building or
writing run caches. It checks reporting, derivation outputs and the current
aggregate/suite/test links, including validity of secondary outputs. Reports use
`tvp.validation-report/v1`; input hashes reference large inventories. Output files
are immutable: a conflicting report or an input alias is refused.

For exported evidence use `--plan plan.json --state status.json --adapter ci-status`
(the raw adapter is the default). Exported status may have an observation time
after completion and must include source, exclusions,
run and suite counts; local worker evidence is explicitly unavailable. Store links
are always observed on the executing host, never inferred from exported link rows.
Use `--expect-revision`, `--expect-source` and `--expect-system` for external
bindings. `--reference-plan` compares the entire reviewed plan; `--revision-only`
permits only its revision field to differ for squash replay.

`--graph-before` and `--graph-after` use the existing graph comparison semantics
and are informational. Optional `--invariants` JSON has schema `1` and exact
`graphEntries`, `planJobs`, `skipped` and/or `graphDelta` expectations. It supplies
policy data without changing CI policy. `--log` and `--prepare-log` attach execution
observations; missing logs mean unknown. Cached outputs and a successful report
establish neither fresh execution, source approval nor ABI compatibility.

## Package reports

`nix run .#status` reports declared package status, gaps and the locally measured
build surface. `--json` includes every canonical version; the text report expands
non-OK versions. Migration-specific status has been removed.

`nix run .#upstream -- --list` lists every family, its packaged-version count and
release-discovery configuration. The installed command makes no network requests
in this mode. Running `nix run` can first realize the CLI and its runtime tools.

`nix run .#upstream -- curl` compares discovered releases with the exact versions
in the catalogue. Without family arguments it reports every family. A family with
no discovery configuration remains visible with its packaged versions, download
URL and `missing versions: unknown`. Failed remote listings remain errors rather
than being presented as an empty release list or nothing missing.

Download and discovery metadata belong together in the family source definition:

```nix
source = tvp.lib.sources.directory {
  url = "https://curl.se/download/";
  archive = "curl-{version}.tar.gz";
};
```

The directory URL serves both archive downloads and release enumeration. The
archive template supplies the filename and version extraction; only complete
matching archive names count as releases. Hashes stay in the version table.

Sources with independent download and listing locations are explicit:

```nix
source = tvp.lib.sources.archive {
  url = version: "https://downloads.example.org/project-${version}.tar.xz";
  discovery = {
    type = "git-tags";
    url = "https://git.example.org/project.git";
    prefix = "v";
  };
};
```

Discovery supports directory indexes, Git tags, JSON indexes, Android SDK XML,
RubyGems version indexes and explicit Git branch heads. Source-specific normalization, exclusions and unavailable
release explanations stay with that source. Missing discovery is represented by
`null`; an arbitrary download URL function is never guessed into a listing rule.
Exceptional fetchers can supply an explicit `fetch` factory while keeping their
available URL and discovery description in the same source record. These
reporting fields do not become compilation inputs.

All 110 current families declare discovery. Android SDK feeds and Go's documented
C-bootstrap archive have explicitly limited history; the report prints those
scopes. GN compares an exact pinned commit with its upstream branch head. For
release feeds, the packaged count is the intersection with the queried feed;
older packaged versions absent from it are shown separately.
