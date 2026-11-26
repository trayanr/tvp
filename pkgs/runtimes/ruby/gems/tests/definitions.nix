# Public installed behavior for automatic gem definitions and named providers.
{
  tvp,
  ruby,
  bundler,
  name,
}:
let
  base = ruby.specification.base;
  postgresql = tvp.packages.postgresql_16;
  provider =
    marker:
    (tvp.builder {
      recipe =
        { postgresql, marker }:
        {
          pname = "synthetic-pg-provider-${toString marker}";
          inherit (postgresql) version;
          src = null;
          inherit base;
          bash = base.shell;
          coreutils = base.coreutils;
          plan = [
            {
              name = "fixture.pg-config";
              tools = [ postgresql ];
              run = ''
                mkdir -p "$out/bin"
                ln -s ${postgresql}/lib "$out/lib"
                ln -s ${postgresql}/include "$out/include"
                cat > "$out/bin/pg_config" <<'SCRIPT'
                #!${base.shell}/bin/bash
                if test "$1" = --tvp-fixture-marker; then
                  printf '%s\n' ${toString marker}
                else
                  exec ${postgresql}/bin/pg_config "$@"
                fi
                SCRIPT
                chmod +x "$out/bin/pg_config"
              '';
            }
          ];
        };
      args = { inherit postgresql marker; };
      dependencyNames = [ "postgresql" ];
      metadata.kind = "fixture";
      selection.kind = "fixture";
      mkTests = _: { };
    })
    // {
      inherit (postgresql) development;
    };
  firstProvider = provider 101;
  secondProvider = provider 202;
  arguments = {
    inherit tvp ruby;
    name = "pg";
    version = "1.0.0";
    src = ./fixtures/definitions/pg;
    sourceType = "source";
  };
  automatic = tvp.lib.ruby.buildGem arguments;
  first = automatic.override { postgresql = firstProvider; };
  overridden = first.override { postgresql = secondProvider; };
  edited = first.edit (spec: spec // { postgresql = secondProvider; });
  explicit = tvp.lib.ruby.buildGem (arguments // { postgresql = secondProvider; });
  archive = tvp.builder {
    recipe =
      { ruby, source }:
      {
        pname = "synthetic-pg-archive-${name}";
        version = "1.0.0";
        src = null;
        inherit base;
        bash = base.shell;
        coreutils = base.coreutils;
        plan = [
          {
            name = "fixture.gem-archive";
            tools = [ ruby ];
            run = ''
              export HOME="$TMPDIR/home"
              mkdir -p "$HOME" "$out" source
              cp -R ${source}/. source/
              chmod -R u+w source
              cd source
              ${ruby}/bin/gem build pg.gemspec >&2
              cp pg-1.0.0.gem "$out/"
            '';
          }
        ];
      };
    args = {
      inherit ruby;
      source = ./fixtures/definitions/pg;
    };
    dependencyNames = [ "ruby" ];
    metadata.kind = "fixture";
    selection.kind = "fixture";
    mkTests = _: { };
  };
  sourcePatch = builtins.toFile "synthetic-pg-source-marker.patch" ''
    --- a/lib/pg.rb
    +++ b/lib/pg.rb
    @@ -3 +3 @@
    -PgFixture::SOURCE_MARKER = 'original-source'
    +PgFixture::SOURCE_MARKER = 'patched-source'
  '';
  patchedArchive = tvp.lib.ruby.buildGem (
    arguments
    // {
      postgresql = secondProvider;
      src = "${archive}/pg-1.0.0.gem";
      sourceType = "gem";
      patches = [ sourcePatch ];
    }
  );
  unknown = first.override { unknownNativeProvider = secondProvider; };
  hasProvider = value: values: builtins.any (package: package.drvPath == value.drvPath) values;
  bundle = tvp.lib.ruby.bundlerEnv {
    inherit tvp ruby bundler;
    name = "synthetic-gem-definitions-${name}";
    gemfile = builtins.toFile "Gemfile-definitions-${name}" ''
      source 'https://invalid.example'
      gem 'pg', '= 1.0.0', :path => 'vendor/pg'
      gem 'tvp-pg-client', '= 1.0.0', :path => 'vendor/client'
    '';
    lockfile = builtins.toFile "Gemfile-definitions-${name}.lock" ''
      PATH
        remote: vendor/pg
        specs:
          pg (1.0.0)

      PATH
        remote: vendor/client
        specs:
          tvp-pg-client (1.0.0)
            pg (= 1.0.0)

      GEM
        remote: https://invalid.example/
        specs:

      PLATFORMS
        ruby

      DEPENDENCIES
        pg (= 1.0.0)!
        tvp-pg-client (= 1.0.0)!

      BUNDLED WITH
         ${bundler.version}
    '';
    gemset = {
      pg = {
        version = "1.0.0";
        groups = [ "default" ];
        source.type = "path";
      };
      tvp-pg-client = {
        version = "1.0.0";
        groups = [ "default" ];
        dependencies = [ "pg" ];
        source.type = "path";
      };
    };
    sourceOverrides = {
      pg = ./fixtures/definitions/pg;
      tvp-pg-client = ./fixtures/definitions/client;
    };
    gemConfig.pg.postgresql = firstProvider;
  };
  changedBundle = bundle.override {
    gemConfig.pg.postgresql = secondProvider;
  };
in
assert automatic.specification.postgresql.drvPath == postgresql.drvPath;
assert overridden.drvPath == edited.drvPath && overridden.drvPath == explicit.drvPath;
assert overridden.artifact.drvPath != first.artifact.drvPath;
assert hasProvider secondProvider edited.specification.libraries;
assert hasProvider secondProvider edited.specification.tools;
assert hasProvider secondProvider edited.specification.runtime.libraries;
assert edited.tvp.declaredDependencies.postgresql.drvPath == secondProvider.drvPath;
assert edited.tvpInventory.schema == 1;
assert edited.tvpInventory.packages.runtime.drvPath == ruby.drvPath;
assert hasProvider firstProvider first.tvpInventory.packages.native;
assert hasProvider secondProvider edited.tvpInventory.packages.native;
assert !(builtins.tryEval unknown.drvPath).success;
assert changedBundle.gems.pg.drvPath == explicit.drvPath;
assert changedBundle.tvpInventory.schema == 1;
assert changedBundle.tvpInventory.packages.runtime.drvPath == ruby.drvPath;
assert changedBundle.tvpInventory.packages.manager.drvPath == changedBundle.bundler.drvPath;
assert hasProvider firstProvider bundle.tvpInventory.packages.native.pg;
assert hasProvider secondProvider changedBundle.tvpInventory.packages.native.pg;
assert
  (builtins.head changedBundle.gems.tvp-pg-client.specification.dependencies).drvPath
  == changedBundle.gems.pg.drvPath;
ruby.testContext.mkTest {
  package = changedBundle;
  name = "named-providers";
  script = ''
    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    export GEM_HOME=${first}/${ruby.gemPath}
    export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
    ${ruby}/bin/ruby -rpg -e '
      abort "Original provider was not used" unless PgFixture.marker == 101
      abort "The native extension did not call libpq" unless PgFixture.client_version >= 160000
    '
    export GEM_HOME=${edited}/${ruby.gemPath}
    export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
    ${ruby}/bin/ruby -rpg -e '
      abort "The edited provider was not used" unless PgFixture.marker == 202
      abort "The edited native extension did not call libpq" unless PgFixture.client_version >= 160000
    '
    export GEM_HOME=${patchedArchive}/${ruby.gemPath}
    export GEM_PATH="$GEM_HOME:${ruby}/${ruby.gemPath}"
    ${ruby}/bin/ruby -rpg -e '
      abort "The source patch was not applied to the gem archive" unless PgFixture::SOURCE_MARKER == "patched-source"
      abort "Rebuilt archive lost the named provider" unless PgFixture.marker == 202
      abort "Rebuilt archive lost native libpq linkage" unless PgFixture.client_version >= 160000
    '
    ${ruby}/bin/ruby -rfileutils -rrubygems/package -e '
      Gem::Package.new(ARGV[0]).extract_files("original-archive")
      ["original-archive/lib/pg.rb", ARGV[1]].each do |path|
        source = File.read(path)
        abort "Patching changed an original input source" unless source.include?("SOURCE_MARKER = \u0027original-source\u0027")
        abort "Patching leaked into an original input source" if source.include?("SOURCE_MARKER = \u0027patched-source\u0027")
      end
    ' ${archive}/pg-1.0.0.gem ${./fixtures/definitions/pg/lib/pg.rb}
    ${changedBundle}/bin/bundle exec ruby -rtvp_pg_client -e '
      marker, version = TvpPgClient.answer
      abort "Bundle did not use its customized gem definition" unless marker == 202 && version >= 160000
      print "gem-definitions-ok"
    '
  '';
  expected = "gem-definitions-ok";
}
