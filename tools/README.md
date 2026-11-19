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

Explicit runtime utilities and interpreters, including jq, are TVP packages.
Commands that query Nix use the caller's host Nix API.
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

`nix run .#provenance` counts confirmed external package derivations in the
evaluated build graph of canonical packages, public variants and compositions.
It follows actual Nix inputs through build steps and compilation artifacts, so
an input selected through builder options is visible even if omitted from
`deps`. The graph query reads derivation metadata offline and realizes no
package outputs. A provider is confirmed by exact derivation identity against
the evaluated external provider records. Unmatched inputs, including generated
build steps and fetchers, are listed separately in `--json`, with one route
back toward a consumer. JSON also includes the consumers and a dependency
chain for each confirmed provider.

Use `--root packages.coreutils_9_5` for a specific package, or `--root @tools`
or `--root @checks` to inspect those graphs separately. Use `--declared` for
source origins, recipes, bases, binary boundaries, and registered outputs.
`--realized` separately checks locally available runtime closures for
unregistered store paths. JSON also lists unavailable packages and exact
registered binary or mixed outputs in each closure.

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

PHP extension families also show coverage for each registered extension release.
The report distinguishes declared packages, packaging gaps, and hard compatibility
limits. Use a PHP series or exact version to narrow the view:

```sh
nix run .#upstream -- --php 8.2 php-mysqli php-redis
# Read the declared coverage without contacting upstream:
nix run .#upstream -- --list --php 8.2 php-mysqli php-redis
```

Release definitions record their TVP support span in `opts.phpCompatibility`.
Source-backed restrictions belong in `phpRequirements`, with a reason and an
upstream URL. A PHP version outside the declared span remains a packaging gap
unless an explicit hard restriction excludes it. A declared package outside a
hard restriction fails coverage evaluation. Missing upstream requirements remain
unknown for releases that have no registered definition.

```nix
phpRequirements = {
  min = "8.1.0";
  max = "8.99.99";
  reason = "MongoDB 1.21.13 declares PHP 8.1 through 8.x in package.xml.";
  source = "https://pecl.php.net/get/mongodb-1.21.13.tgz";
};
```

Bundled modules declare `phpPolicy.kind = "bundled"`. Coverage then checks for
the module from each PHP release's own source and SDK. An absent PHP 8.2 module
is a packaging gap even when the registered PHP 8.5 module requires an exact
8.5 SDK. Historical source-availability limits carry the same reason and URL
requirements as independent extensions.

Mixed-source families declare `phpPolicy.kind = "mixed"` and a source-backed
`phpPolicy.bundled` range. Coverage tracks matching PHP source inside that
range and standalone releases outside it. Upstream release discovery follows
the standalone project.

When the engine includes a bundled module, `phpPolicy.builtIn` records the
applicable PHP versions with a reason and upstream URL. Coverage displays
these versions as built into PHP.

The machine-readable report is available under
`php.metadata.families.<extension>.coverage`. Each row names the PHP version,
extension release, and `packaged`, `gap`, `incompatible`, or `builtin` state.
Mixed-source rows also record `kind`. Coverage describes declarations.
Test execution remains recorded by the test runner.
