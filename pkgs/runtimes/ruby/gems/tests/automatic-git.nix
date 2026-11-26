# A small committed local repository exercises hashed Git fetching offline.
{ tvp }:
let
  ruby = tvp.canonical.ruby_2_7_0;
  bundler = tvp.canonical.bundler_1_17_3;
  rev = "0b614855d880af9ac64dc0c5b27d38e326d3bd20";
  url = "file://${./fixtures/git-repository}";
  source = {
    type = "git";
    inherit url rev;
    sha256 = "sha256-ZMz4N90C7szyFKRjlz+hDe7Fdb4AqKs8PbrJKB5Zy84=";
    fetchSubmodules = false;
  };
  entries = builtins.listToAttrs (
    map
      (name: {
        inherit name;
        value = {
          version = "1.0.0";
          groups = [ "default" ];
          inherit source;
        };
      })
      [
        "tvp-pure"
        "tvp-test"
      ]
  );
  bundle = tvp.lib.ruby.bundlerEnv {
    inherit tvp ruby bundler;
    name = "synthetic-automatic-git";
    gemset = entries;
    gemfile = builtins.toFile "Gemfile-automatic-git" ''
      source 'https://invalid.example'
      gem 'tvp-pure', '= 1.0.0', :git => '${url}', :ref => '${rev}'
      gem 'tvp-test', '= 1.0.0', :git => '${url}', :ref => '${rev}'
    '';
    lockfile = builtins.toFile "Gemfile-automatic-git.lock" ''
      GIT
        remote: ${url}
        revision: ${rev}
        ref: ${rev}
        specs:
          tvp-pure (1.0.0)
          tvp-test (1.0.0)

      GEM
        remote: https://invalid.example/
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES
        tvp-pure (= 1.0.0)!
        tvp-test (= 1.0.0)!

      BUNDLED WITH
         ${bundler.version}
    '';
  };
  invalidSource =
    changed:
    bundle.override {
      gemset = entries // {
        tvp-pure = entries.tvp-pure // {
          source = changed;
        };
      };
    };
  missingRevision = invalidSource (builtins.removeAttrs source [ "rev" ]);
  missingHash = invalidSource (builtins.removeAttrs source [ "sha256" ]);
  mutableRevision = invalidSource (source // { rev = "master"; });
  overridden = bundle.override {
    gemset = builtins.mapAttrs (_: entry: entry // { source.type = "git"; }) entries;
    sourceOverrides = {
      tvp-pure = ./fixtures/git;
      tvp-test = ./fixtures/git;
    };
  };
in
assert !(builtins.tryEval missingRevision.drvPath).success;
assert !(builtins.tryEval missingHash.drvPath).success;
assert !(builtins.tryEval mutableRevision.drvPath).success;
assert overridden.gems.tvp-pure.specification.src == ./fixtures/git;
assert
  bundle.gems.tvp-pure.specification.src.drvPath == bundle.gems.tvp-test.specification.src.drvPath;
ruby.testContext.mkTest {
  package = bundle;
  name = "git-manifest";
  script = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    ${bundle}/bin/bundle check >&2
    ${bundle}/bin/bundle exec ruby -rtvp_pure -rtvp_test -e '
      abort "Git gem results differ" unless TvpPure::ANSWER == 42 && TvpTest::ANSWER == 43
      directory = Gem.loaded_specs.fetch("tvp-pure").full_gem_path
      asset = File.join(directory, "dist", "widget.js")
      abort "Tracked export-ignore asset was omitted" unless File.read(asset).include?("42")
      abort "Git metadata escaped into the gem" if File.exist?(File.join(directory, ".git"))
    '
    ${overridden}/bin/bundle check >&2
    ${overridden}/bin/bundle exec ruby -rtvp_pure -rtvp_test -e '
      abort "Explicit source overrides did not take precedence" unless TvpPure::ANSWER == 42 && TvpTest::ANSWER == 43
      print "automatic-git-ok"
    '
  '';
  expected = "automatic-git-ok";
}
