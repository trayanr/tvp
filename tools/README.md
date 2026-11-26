# Repository tools

All six apps are copied by `tools/lib/owned-cli.nix`, a direct derivation run by
TVP Bash with TVP coreutils. It installs explicit Bash shebangs and checks each
script with `bash -n` and TVP's package of the official static ShellCheck
release. That validator has an explicit binary origin. The helper uses no stdenv
setup, wrapper hooks or compiler. Text manifests use `builtins.toFile`.

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

## Downstream TVP selections

Run the `tvp` app from the consumer flake directory after it has a `flake.lock`.
It defaults to `devShells.x86_64-linux.default` and the top-level `tvp` input.
Use `--attr` to select another shell or package output and `--input` if the
input has a different name.

```sh
nix run github:trayanr/tvp#tvp -- used
nix run github:trayanr/tvp#tvp -- diff /tmp/before.lock /tmp/after.lock
nix run github:trayanr/tvp#tvp -- update --preview
```

`diff` evaluates the same project output with both existing lockfiles. Its second
argument defaults to the project's current `flake.lock`. `update --preview` asks
Nix to update only the chosen input into a temporary lockfile, then uses the same
comparison. Use `nix flake update tvp` to apply an update. Use `--json` for CI
reports. These commands evaluate derivations without building package outputs.

Add `--impure` when the selected output reads environment variables or local
paths outside its flake source, for example a development shell that reads a
separate application checkout. Set the required environment variables before
running the command. The flag applies to both sides of a diff or update preview;
evaluation remains pure unless it is explicitly supplied.

## Inventory contract

Reports cover TVP-managed selections exposed by a selected package or the direct
inputs of a selected shell. TVP's environment helpers publish the same inventory
contract for every supported language; consumers do not need to define reporting
metadata. A helper exposes actual resolved package references through its
derivation's passthru:

```nix
tvpInventory = {
  schema = 1;
  packages = {
    runtime = ruby;
    manager = bundler;
    native = { pg = [ postgresql ]; };
  };
};
```

`packages` is an attribute set whose values are package references, nested
attribute sets or lists. Its names describe usage; they have no language-specific
meaning to the reader. TVP helpers derive these references from the final resolved
arguments, including overrides and edits, rather than copying package versions.
Only referenced packages carrying TVP selection metadata are reported. A
referenced environment with its own contract contributes its declared packages.
The contract defines the complete reporting scope for that environment: its own
container and undeclared build inputs are omitted. Older pinned helpers remain
supported through the Ruby and PHP shape readers.

For a Ruby bundle or application, the reported selections are its Ruby, bound
Bundler and TVP native-library providers. Gems remain
independent build units, but their versions belong to Gemfile.lock and gemset.nix;
their versions and rebuilds are not listed as TVP package updates. The consumer's
bundle and application derivations are also omitted. A directly selected gem
exposes its TVP Ruby and native providers, not a gem row. Native providers without
TVP selection metadata, such as explicitly chosen Nixpkgs libraries, are excluded.

Repeated references to the same package selection are collapsed. Distinct
selectors and build variants remain separate, even when selectors resolve to the
same derivation. JSON package rows retain `usedBy` references with their generic
metadata locations. Legacy Ruby rows can also include `gemName`/`providerName`.
The text report shows package selectors and versions. Changes to consumer
references alone, including migration to the common contract, are not package
updates.

PHP reports retain the managed engine and extensions of a directly selected TVP
PHP composition, and omit the composition itself. Its engine row describes the
resolved engine and may show a
canonical engine even when the project chose a moving PHP alias. Version changes
and same-version derivation changes are reported separately. General derivation-
graph traversal and attribution among multiple TVP inputs remain outside this
inspection scope.

The offline integration check runs with `python3 -B tools/consumer/test_consumer.py`.

## Experimental security audit

`tvp audit` reads the same resolved TVP selections as `tvp used`. Choose a
candidate backend explicitly while Grype and OSV are being evaluated:

```sh
nix run .#tvp -- audit --backend osv
nix run .#tvp -- audit --backend grype --attr packages.x86_64-linux.example --json
nix run .#tvp -- audit --backend osv --offline --require-coverage
```

Grype currently needs to be on the caller's PATH. OSV uses its HTTPS API and
caches exact query responses for 24 hours; `--offline` requires cached responses
for mapped components and labels their age. Neither backend uploads application
source. No packages are built to read the inventory. An initial set of TVP-owned
identity profiles covers Bundler, Curl, Ruby, OpenSSL and PostgreSQL; support
differs by backend, and missing profiles remain explicitly unscanned.

Reports include the TVP pin, output, scanner/data evidence, coverage and advisory
matches with applicability unassessed. The scope excludes undeclared transitive
dependencies, language lockfiles, non-TVP packages and application reachability.
No matches among scanned components does not establish whole-environment safety.
The default is report-only; `--fail-on high` exits 2 for matching advisories at
that severity or above, and `--require-coverage` exits 3 for incomplete declared
inventory coverage. Errors exit 1. Unknown severity remains visible.
Provider-supplied fix versions are advisory fix points; branch compatibility is
not established by the audit.

The [security roadmap](consumer/SECURITY-ROADMAP.md) records candidate evaluation,
daily CI on pinned environments, build assessments and later dependency scopes.
Run the offline core/provider check with
`nix build --no-link .#checks.x86_64-linux.consumer-audit`.

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

Use `--root packages.coreutils_9_5` for a specific package, or `--root @tools`,
`--root @checks` or `--root @smoke` for CLI tools, repository checks or standard
CI suites. Use `--declared` for
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

Use `nix run .#upstream -- --json --flake REF FAMILY` for a machine-readable
report. The command reads the catalogue and release rules from one frozen
`REF`. The version 1 report includes `schemaVersion`, the clean Git
`revision` (or null for a dirty or unversioned source), and `families`.
Each family records its discovery status, source, releases or commit
identities, and any declared PHP coverage. A failed lookup returns a
nonzero exit and a partial report. Treat that report as diagnostic data.
`--list --json` reads declarations without querying the upstream feeds.

For numbered releases, `candidate` means that a stable numeric
`MAJOR.MINOR.PATCH` advances an already packaged major/minor series. Older
missing releases are `historical-gap`. A fresh series or version scheme
needs its own update policy. Prereleases and source-declared unavailable
releases are reported separately, as is unknown PHP compatibility. An
unpackaged Git branch head is identified by its full commit and has a
separate `kind`. Automation should apply its own family and series policy
before acting on candidates.

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

All catalogue families declare discovery. Android SDK feeds and Go's documented
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
