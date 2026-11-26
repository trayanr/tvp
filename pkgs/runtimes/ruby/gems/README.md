# Ruby project helper roadmap

Build locked Ruby dependency environments with a selected TVP Ruby and Bundler.
A private legacy Rails application provides acceptance coverage. Public checks
use independently written synthetic projects and public registry native gems.

## First milestone

- [x] Export `tvp.lib.ruby.buildGem` and `tvp.lib.ruby.bundlerEnv`.
- [x] Build each gem independently with the selected Ruby and its compiler base.
- [x] Accept gem archives and source directories or archives, with native library,
  tool, patch and build flag overrides.
- [x] Consume the existing Bundix `gemset.nix` format. Fetch registry archives and
  revision-pinned Git checkouts with declared hashes; retain explicit source
  overrides for local dependencies and custom fetching.
- [x] Bind Bundler to the selected Ruby and assemble a frozen environment with
  explicit dependency groups, engine, manager and gem metadata.
- [x] Keep gem compilation separate from environment assembly and application code.
- [x] Register focused public checks for a pure Ruby gem, a native extension, and
  locked environments on Ruby 2.7/Bundler 1.17 and a modern combination.
- [x] Exercise registry, Git and local dependency layouts with synthetic sources,
  missing dependencies, group exclusion, exact manager selection and lockfile
  preservation.
- [x] Own native dependencies, compatibility patches and installed checks in
  unified TVP gem definitions, shared by direct and bundled builds.
- [x] Expose named native inputs through normal `.override` and `.edit`, and
  report their selected versions alongside locked gems.

## Private acceptance

- [x] Generate a source manifest from the application's existing lockfile using
  Bundix, recording immutable hashes and private source mappings in the private
  integration repository.
- [x] Validate TVP-owned native defaults with only deliberate source/platform
  choices remaining in the private configuration.
- [x] Run `bundle check`, load selected native gems, boot the Rails framework and
  load the application definition with its locked Ruby and Bundler.
- [x] Record acceptance results in the private project and reconcile any generic
  compatibility fixes into TVP with synthetic public regression fixtures.

The locked dependency environment and focused loading checks pass in Nix's
network-disabled build sandbox. A separate runtime check loads the real schema
into disposable PostgreSQL, completes Rails initialization and eager loading,
checks Redis, and requests an application endpoint. Business workflows, workers
and production deployment remain outside this focused acceptance scope.

Application source remains in its existing private checkout. Nix configuration,
dependency source manifests and acceptance scripts belong to the private
integration repository; they read application source without writing to it.
Private source details and credentials stay outside public TVP fixtures.
Dependency fetches and package publication follow the integration project's
access and cache settings.

## Follow-up work

- [x] Extend `tvp used` and `tvp diff` to inspect Ruby environments and gem changes.
- [x] Confirm Bundix can generate the required source manifest without updating
  dependency versions. An additional TVP manifest command is unnecessary for the
  supported inputs.
- [x] Establish the runtime contract with disposable services and sanitized
  configuration in the private integration repository.
- [x] Compile and validate the actual asset pipeline using locked offline
  frontend dependencies and disposable services.
- [x] Add a reusable application wrapper and synthetic public checks for that
  contract. Keep application-specific launch and acceptance settings private.

Private acceptance also builds the actual frontend pipeline and validates its
bundles, manifests, compressed outputs and engine assets. The public application
checks exercise the reusable build and launch contract using synthetic sources.

These helpers follow TVP's rolling release model. Consumers pin the TVP flake
revision and their dependency manifest; updates are reviewed through `tvp diff`
or `tvp update --preview`. Gem, Ruby and Bundler versions change through explicit
consumer choices. Bundler must match the lockfile's `BUNDLED WITH` version;
updating TVP does not select a new compatible manager automatically. Helper
changes and their public smoke checks ship together on the normal project branch,
without a separate helper release sequence.

## Structure

`lib/ruby.nix` owns the public helper interface. Procedures and focused synthetic
checks live here under `pkgs/runtimes/ruby/gems/`. Ruby and Bundler release recipes
stay in their existing runtime and build-tool families. Environment construction
uses the existing TVP builder and the selected Ruby's base.

The environment accepts a Gemfile, Gemfile.lock, gemset, groups, and per-gem source
and build overrides. The helper installs the locked dependencies and validates the
result without changing the input lockfile. Runtime and dependency updates remain
explicit downstream actions.

## Unified gem definitions

Each supported native gem owns a definition under `definitions/<name>/`: named
provider defaults, build flags, version-dependent patches and installed checks.
`buildGem` and `bundlerEnv` instantiate the same definition through the shared
builder. Ordinary gems use the generic recipe without requiring a TVP catalogue
entry. The lockfile and source manifest continue to supply exact versions, source
hashes and resolved gem dependencies.

Current definitions cover `pg`, `ffi`, `ethon`, `rbtrace`, `activerecord`,
`rmagick` and `nokogiri`. Their native defaults use TVP packages, including
PostgreSQL, libffi, Curl, ImageMagick, libxml2, libxslt and zlib. Native library
paths and dependencies come from those packages' declared development interfaces;
gem definitions do not import Nixpkgs native libraries.

RMagick defaults to TVP's ImageMagick 7 family. Its image formats and HDRI support
follow the selected ImageMagick package's `buildFeatures`. Nokogiri 1.15.7 uses
libxslt 1.1.43 and its matching libxml2 2.12.10 to retain the XML API that this gem
supports. Other Nokogiri versions default to the current TVP libxslt family.
Unless explicitly overridden, Nokogiri's libxml2 follows the chosen libxslt
provider, so overriding libxslt also selects its declared XML dependency.

For example, given the desired provider packages:

```nix
custom = bundle.override {
  gemConfig = {
    pg.postgresql = chosenPostgresql;
    rmagick.imagemagick = chosenImageMagick;
  };
};

customPg = bundle.gems.pg.override { postgresql = chosenPostgresql; };
editedPg = bundle.gems.pg.edit (spec: spec // { postgresql = chosenPostgresql; });
```

Named inputs recompute libraries, tools, flags and runtime references from the
effective specification. A bundle override also wires dependent gems to its
customized gem. An individual gem override returns a separate package.
`gemConfig` is optional and extends TVP's definition defaults. As with ordinary
TVP argument overrides, supplying a new `gemConfig` replaces the previous
consumer map; the function form of `.override` can merge prior local choices.
Explicit low-level lists such as `libraries` or `patches` replace their defaults;
`.edit` or a function override can append instead.

The five native-library definitions expose a small installed probe through
`gem.tests.load`. Native providers also appear in `gem.nativeProviders` and
TVP dependency provenance. Inventory and diffs identify their gem owner, provider
name, version and derivation.

## Validation policy

Follow the repository's [testing policy](../../../../TESTING.md). Build the named
helper smoke checks and reuse existing outputs. Upstream regression suites remain
available for explicit requests. Private application acceptance runs separately
from public TVP checks.

## Using the helpers

The first implementation exports both helpers from `tvp.lib.ruby`. Construct the
full TVP context from the downstream flake input (`tvpInput` below) and pass it
explicitly, as with the PHP custom extension interface. The flake's package-only
outputs do not expose the builder used by these helpers.

```nix
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  tvp = import tvpInput.outPath { inherit pkgs system; };
  ruby = tvp.canonical.ruby_2_7_0;
in
  tvp.lib.ruby.bundlerEnv {
    inherit tvp ruby;
    bundler = tvp.canonical.bundler_1_17_3;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./nix/gemset.nix;
    groups = [ "default" "test" ];
  }
```

`gemset` accepts a Bundix attrset or a path to one. Registry entries use their
`source.sha256` and first declared remote to fetch `.gem` files. Git entries are
fetched automatically from `source.url`, a full commit hash in `source.rev`, and
the recursive checkout hash in `source.sha256`; `source.fetchSubmodules` defaults
to false. No separate source-mapping file is needed. TVP uses the package
context's standard fixed-output Git fetcher, preserving existing checkout hashes,
cache paths and the normal private repository access configuration.

`sourceOverrides.<gem>` takes precedence over manifest fetching and can provide
custom Git sources or local dependencies. An override can be a directory or an
archive containing one top-level directory. Git checkouts use Bundler's normal
gemspec glob and support several gems from one repository.
Local paths must resolve inside the supplied project source. Set `src` to include
additional files which the Gemfile evaluates, such as a gemspec or `.ruby-version`.
When `src` contains a local gem, its installed files replace the matching source
files while preserving other project files and the supplied Gemfile and lockfile.

`gemConfig.<gem>` optionally supplies named inputs such as `postgresql` or
`imagemagick`, or generic `buildGem` arguments such as `libraries`, `tools`,
`buildFlags`, `patches`, `platform`, `sourceType` and `sourceSubdir`. Patches apply
to source directories and archives. A patched `.gem` archive is verified,
extracted and rebuilt automatically with the same identity; consumers do not
need a separate source-extraction recipe. Platform gems select an explicit `platform`,
such as `"x86_64-linux"`, with a hash-pinned archive source. The helper verifies
both the declared platform and its compatibility with the selected Ruby. Every
assembled gem must use the environment's Ruby. Gem requirements for Ruby and
RubyGems versions are checked before installation.

`buildGem` takes `tvp`, `ruby`, `name`, `version` and `src`, plus those build
options and an optional list of already built gem `dependencies`. Its default
`sourceType = "gem"` installs a `.gem` archive. Set `sourceType = "source"` to
build a gemspec from a directory or source archive. Git sources use
`sourceType = "git"`, preparing a temporary index for exported checkouts and
packaging the exported snapshot, including assets ignored by the release
gemspec. Gem dependencies expose their transitive build dependencies. Gems retain
their compiler and native library choices through their derivation inputs.
Native output cleanup selects host ELF files and preserves foreign binary payloads.
Source packaging normalizes bare relative symlink targets to preserve their
meaning through historical RubyGems packaging and extraction. The supplied
source remains untouched.

The bundle output exposes `bin/ruby`, exact-version `bin/bundle` and the selected
gems' executables. It validates the frozen lock, including `BUNDLED WITH`, and
exports `ruby`, rebound `bundler`, `gems`, `groups`, `gemfile` and `lockfile`
metadata. Add the output to a downstream development shell to use the same locked
dependency environment as package and CI commands.

## Packaging an application

`tvp.lib.ruby.application` packages source and generated assets over an existing
bundle. It copies the supplied source into a writable build directory, runs an
optional `buildScript`, and installs the prepared tree under
`$out/share/<name>`. Dependency gems remain separate derivations, so application
and asset changes reuse the locked bundle.

```nix
tvp.lib.ruby.application {
  inherit tvp bundle;
  name = "example-app";
  version = "dev";
  src = ./application-source;
  tools = [ ];
  buildScript = ''
    bundle exec rake assets:precompile
  '';
  commands = {
    server = [ "bundle" "exec" "rackup" ];
  };
  environment.RACK_ENV = "production";
}
```

Pass an explicitly selected source tree. The output contains that prepared tree,
including files left by the build script; exclude credentials and remove
build-only dependencies there if needed. The helper validates any supplied
Gemfile and lockfile against the bundle before and after the build, and adds the
exact bundle manifests when the source omits them.

Each `commands.<name>` is an argv list starting with an executable from the
selected bundle's `bin/`. The installed wrapper enters the immutable application
directory and preserves caller arguments and exit status. `environment` values
are defaults: callers can override them, including with an empty value. `tools`
are build inputs; runtime commands use the selected bundle. Writable runtime
state, external configuration and services remain explicit application concerns.

The output exposes `applicationDirectory`, `bundle`, `ruby`, `bundler`, `gems`
and `groups`. `tvp used`, `tvp diff` and update previews report the application
alongside its locked bundle and components.

## Focused public checks

```sh
nix build --no-link .#checks.x86_64-linux.ruby-projects
# One representative installed check
nix build --no-link .#checks.x86_64-linux.ruby-projects.testSuite.ruby-bundle-legacy
```

These named checks also run as the `ruby-projects` smoke subject. Ruby 2.7.0
with Bundler 1.17.3 and Ruby 3.3.12 with Bundler 2.5.20 cover gem archives,
source directories and tarballs, native loading, dependency groups, direct gem
executables, lockfile preservation, missing dependencies, Ruby ABI mismatches,
platform and version requirement verification, transitive build dependencies,
preservation of foreign binary payloads, local gem overlays in project sources,
and multiple gems sharing one exported Git source. These are installed-result
smoke checks. Public regressions cover generic fixes discovered during private
acceptance.

The automatic Git check fetches a small committed local repository without
network access or import-from-derivation. It verifies shared source fetching,
complete checkout contents including `export-ignore` files, immutable source
metadata and explicit source-override precedence.

The two application checks additionally build and read a transformed asset, run
from an unrelated directory with a hostile interpreter on PATH, preserve literal
arguments and environment values, honor runtime overrides, preserve exit status,
and verify the installed source and manifests.

The two definition checks compile a synthetic gem against real libpq and exercise
two selected `pg_config` providers. They cover direct/bundle consistency,
`.override`/`.edit`, transitive dependency wiring, provider provenance, unknown
input rejection and automatic patch rebuilding of a `.gem` archive.
