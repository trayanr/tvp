# Ruby project helpers

`tvp.lib.ruby` builds individual gems, locked dependency environments and
application packages with a selected TVP Ruby and Bundler. Gems build separately,
so application changes reuse their dependency outputs.

## Locked environments

Construct the full TVP context from the flake input and pass it to the helper.
The package-only flake outputs do not expose the required builder.

```nix
let
  system = "x86_64-linux";
  pkgs = import nixpkgs { inherit system; };
  tvp = import tvpInput.outPath { inherit pkgs system; };
in
  tvp.lib.ruby.bundlerEnv {
    inherit tvp;
    ruby = tvp.canonical.ruby_2_7_0;
    bundler = tvp.canonical.bundler_1_17_3;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./nix/gemset.nix;
    groups = [ "default" "test" ];
  }
```

`gemset` accepts a Bundix attrset or a path to one. Registry entries use
`source.sha256` and their first declared remote. Git entries use `source.url`,
a full commit hash in `source.rev` and the recursive checkout hash in
`source.sha256`; `source.fetchSubmodules` defaults to false. TVP uses the package
context's fixed-output Git fetcher and its normal repository access settings.

The helper preserves the supplied lockfile and checks gem versions, Git source
identities and `BUNDLED WITH`. Automatically fetched Git URLs and revisions must
match `Gemfile.lock`, even when the gem version is unchanged. Ruby and Bundler
updates remain explicit consumer choices under TVP's rolling release model.

`sourceOverrides.<gem>` or `gemConfig.<gem>.src` deliberately replace a source
and bypass the automatic Git identity comparison. Sources may be directories or
archives containing one top-level directory. Git checkouts support multiple gems
using Bundler's default gemspec glob. Gemfile path dependencies must resolve inside
the project.
Set `src` when the Gemfile needs additional project files. Installed local-gem
files overlay that source while preserving other files and the supplied manifests.

The output provides `bin/ruby`, exact-version `bin/bundle`, selected gem
executables and `ruby`, rebound `bundler`, `gems`, `groups`, `gemfile` and
`lockfile` attributes. Add it to a development shell to share the locked environment
with package and CI commands.

## Individual gems

```nix
tvp.lib.ruby.buildGem {
  inherit tvp;
  ruby = tvp.canonical.ruby_2_7_0;
  name = "example";
  version = "1.0.0";
  src = ./example-1.0.0.gem;
  dependencies = [ ];
}
```

`sourceType = "gem"` installs an archive. Use `"source"` for a gemspec in a
directory or source archive, or `"git"` for an exported checkout. Git packaging
includes the exported snapshot and prepares a temporary index when necessary.
`sourceSubdir` selects a directory inside that source tree. Inputs remain untouched.

Build options include `libraries`, `tools`, `buildFlags`, `patches` and `platform`.
Patched gem archives are verified, extracted and rebuilt automatically. Platform
gems require an explicit compatible platform, such as `"x86_64-linux"`.
Ruby/RubyGems version requirements are checked before installation, and gem
dependencies must use the selected Ruby. Native cleanup preserves foreign binary
payloads. Source packaging preserves historical RubyGems source-symlink semantics.

## Native providers and overrides

Direct and bundled gems share definitions under `definitions/<name>/`. TVP owns
the provider defaults, build flags and compatibility patches for `pg`, `ffi`,
`ethon`, `rbtrace`, `activerecord`, `rmagick` and `nokogiri`. Native-library
definitions also expose installed probes through `gem.tests.load`. Ordinary gems
use the generic recipe without a TVP catalogue entry.

```nix
customBundle = bundle.override {
  gemConfig = {
    pg.postgresql = chosenPostgresql;
    rmagick.imagemagick = chosenImageMagick;
  };
};
customPg = bundle.gems.pg.override { postgresql = chosenPostgresql; };
editedPg = bundle.gems.pg.edit (spec: spec // { postgresql = chosenPostgresql; });
```

Named providers recompute libraries, tools, flags and runtime references. Bundle
changes also rewire dependent gems; an individual gem override returns a separate
package. `gemConfig` extends TVP's definition defaults. Replacing that map replaces
previous consumer choices; use a function override to merge them. Low-level lists
such as `libraries` or `patches` replace defaults; a function override or `.edit`
can append instead. Native providers are exposed through `gem.nativeProviders`.

RMagick follows the selected ImageMagick package's image formats and HDRI features.
Nokogiri's libxml2 follows its selected libxslt unless overridden. Nokogiri 1.15.7
uses libxslt 1.1.43 and its matching libxml2 2.12.10 for API compatibility.

## Application packages

```nix
tvp.lib.ruby.application {
  inherit tvp bundle;
  name = "example-app";
  version = "dev";
  src = ./application-source;
  buildScript = ''
    bundle exec rake assets:precompile
  '';
  commands.server = [ "bundle" "exec" "rackup" ];
  environment.RACK_ENV = "production";
}
```

The helper builds a writable source copy and installs the prepared tree under
`$out/share/<name>`. It validates Gemfile and lockfile against the bundle before
and after the build, supplying exact bundle manifests when the source omits them.
Select source explicitly: the output includes everything left by `buildScript`.

Each command is an argv list starting with an executable from the bundle's `bin/`.
Wrappers enter the immutable application directory, forward arguments and preserve
exit status. Environment values are caller-overridable defaults, including empty
values. Optional `tools` are build inputs. Writable runtime state, configuration
and services remain application concerns. The output exposes
`applicationDirectory`, `bundle`, `ruby`, `bundler`, `gems` and `groups`.

## Inventory and checks

Helpers publish `tvpInventory` automatically from resolved package references,
including overrides, edits and group selection. `tvp used`, `tvp diff` and update
previews report the TVP-managed Ruby, Bundler and native providers. Gems remain
owned by the application lockfile; bundle and application containers are omitted.
Consumers need no reporting declarations. See the shared
[inventory contract](../../../../tools/README.md#inventory-contract).

Follow [TESTING.md](../../../../TESTING.md) and reuse valid outputs. Public
[helper checks](tests/) cover synthetic projects and representative registry gems
on Ruby 2.7/Bundler 1.17 and Ruby 3.3/Bundler 2.5. Run a focused named check:

```sh
nix build --no-link .#checks.x86_64-linux.ruby-projects.testSuite.ruby-bundle-git
```
