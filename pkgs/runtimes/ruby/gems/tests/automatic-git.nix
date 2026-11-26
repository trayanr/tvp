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
  gemfileText = ''
    source 'https://invalid.example'
    gem 'tvp-pure', '= 1.0.0', :git => '${url}', :ref => '${rev}'
    gem 'tvp-test', '= 1.0.0', :git => '${url}', :ref => '${rev}'
  '';
  lockfileText = bundlerVersion: ''
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
       ${bundlerVersion}
  '';
  bundle = tvp.lib.ruby.bundlerEnv {
    inherit tvp ruby bundler;
    name = "synthetic-automatic-git";
    gemset = entries;
    gemfile = builtins.toFile "Gemfile-automatic-git" gemfileText;
    lockfile = builtins.toFile "Gemfile-automatic-git.lock" (lockfileText bundler.version);
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
  configured = bundle.override {
    gemset = builtins.mapAttrs (_: entry: entry // { source.type = "git"; }) entries;
    gemConfig = {
      tvp-pure.src = ./fixtures/git;
      tvp-test.src = ./fixtures/git;
    };
  };
  assemblyScript = candidate: label: ''
    cat > ${label}.sh <<'TVP_GIT_BUNDLE_ASSEMBLY'
    ${(builtins.head candidate.specification.plan).run}
    TVP_GIT_BUNDLE_ASSEMBLY
  '';
  sourceChecks =
    label: ruby: bundler:
    let
      matching = bundle.override {
        inherit ruby bundler;
        lockfile = builtins.toFile "Gemfile-${label}.lock" (lockfileText bundler.version);
      };
      replaceSource =
        before: after:
        matching.override {
          gemfile = builtins.toFile "Git-source-Gemfile" (
            builtins.replaceStrings [ before ] [ after ] gemfileText
          );
          lockfile = builtins.toFile "Git-source-Gemfile.lock" (
            builtins.replaceStrings [ before ] [ after ] (lockfileText bundler.version)
          );
        };
      changedRevision = replaceSource rev "1111111111111111111111111111111111111111";
      changedUrl = replaceSource url "https://invalid.example/another-repository.git";
      changedType = matching.override {
        lockfile = builtins.toFile "Path-source-Gemfile.lock" (
          builtins.replaceStrings
            [ "GIT\n  remote: ${url}\n  revision: ${rev}\n  ref: ${rev}\n" ]
            [ "PATH\n  remote: vendor/shared\n" ]
            (lockfileText bundler.version)
        );
      };
    in
    ''
      ${assemblyScript matching "${label}-matching"}
      ${assemblyScript changedRevision "${label}-revision"}
      ${assemblyScript changedUrl "${label}-url"}
      ${assemblyScript changedType "${label}-type"}
      assemble_into "$PWD/${label}-matching.sh" ${label}-matching >&2
      reject_assembly "$PWD/${label}-revision.sh" ${label}-revision 'Git revision differs from lockfile for tvp-pure'
      reject_assembly "$PWD/${label}-url.sh" ${label}-url 'Git URL differs from lockfile for tvp-pure'
      reject_assembly "$PWD/${label}-type.sh" ${label}-type 'source type differs from lockfile for tvp-pure'
    '';
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
  tools = [
    ruby.specification.base.tools.diffutils
    ruby.specification.base.tools.grep
  ];
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
    '
    ${configured}/bin/bundle check >&2
    ${configured}/bin/bundle exec ruby -rtvp_pure -rtvp_test -e '
      abort "Per-gem source overrides did not take precedence" unless TvpPure::ANSWER == 42 && TvpTest::ANSWER == 43
    '

    assemble_into() (
      assembly_script="$1"
      directory="$2"
      mkdir -p "$directory"
      cd "$directory"
      env out="$PWD/output" TVP_SOURCE_ROOT="$PWD" \
        ${ruby.specification.base.shell}/bin/bash -e "$assembly_script"
    )
    reject_assembly() {
      if assemble_into "$1" "$2" > "$2.log" 2>&1; then
        echo "Mismatched Git source was accepted: $2" >&2
        exit 1
      fi
      grep -F "$3" "$2.log" >&2
    }
    ${sourceChecks "legacy" ruby bundler}
    ${sourceChecks "modern" tvp.canonical.ruby_3_3_12 tvp.canonical.bundler_2_5_20}
    cmp ${bundle.specification.gemfile} ${bundle}/project/Gemfile
    cmp ${bundle.specification.lockfile} ${bundle}/project/Gemfile.lock
    printf automatic-git-ok
  '';
  expected = "automatic-git-ok";
}
