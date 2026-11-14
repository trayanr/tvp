# Bounded customization controls: no second Ruby compilation.
{
  pkgs,
  tvp,
  package,
}:
let
  inherit (pkgs) lib;
  contains = needle: haystack: lib.hasInfix (builtins.unsafeDiscardStringContext needle) haystack;
  candidate = import ../../../../bases/source-gnu { };
  inherit (candidate) base;
  inherit (candidate.tools) bash coreutils;
  p = tvp.packages;
  yaml = p.libyaml;
  ruby = p.ruby_3;
  bundler = package;
  make =
    name: plan: passthru:
    tvp.builder {
      recipe =
        {
          base,
          bash,
          coreutils,
        }:
        {
          pname = name;
          version = "1";
          src = null;
          inherit
            base
            bash
            coreutils
            plan
            passthru
            ;
        };
      args = {
        inherit base bash coreutils;
      };
      dependencyNames = [ ];
      metadata = { };
      selection.kind = "fixture";
      mkTests = _: { };
    };
  tinySource = make "ruby-bundler-source-control" [
    {
      name = "fixture.archive";
      tools = [
        candidate.tools.tar
        candidate.tools.gzip
      ];
      run = ''
        mkdir source
        printf '#!/bin/sh\nprintf prepared\\n\n' > source/configure
        printf source-edited > source/marker
        mkdir "$out"
        tar -czf "$out/source.tar.gz" source
      '';
    }
  ] { };
  cheap =
    family: original:
    (original.edit (
      s:
      (builtins.removeAttrs s [ "artifactName" ])
      // {
        src = "${tinySource}/source.tar.gz";
        environment = s.environment // {
          overrides = {
            values = (s.environment.overrides.values or { }) // {
              RUBY_CONTROL = "edited";
            };
          };
        };
      }
    )).editSteps
      (
        plan:
        [ (builtins.head plan) ]
        ++ [
          (
            (builtins.head (builtins.filter (s: s.name == "${family}.configure") plan))
            // {
              cwd = ".";
              name = "${family}.control";
              run = ''
                test "$(cat source/marker)" = source-edited
                test "$RUBY_CONTROL" = edited
                mkdir "$out"
                printf controlled > "$out/marker"
              '';
            }
          )
        ]
      );
  cheapYaml = cheap "libyaml" yaml;
  cheapRuby = cheap "ruby" ruby;
  shim = make "ruby3-interpreter-control" [
    {
      name = "fixture.interpreter";
      run = ''
        mkdir -p "$out/bin"
        cat > "$out/bin/ruby" <<'SH'
        #!${bash}/bin/bash
        exec ${ruby}/bin/ruby "$@"
        SH
        chmod +x "$out/bin/ruby"
        ln -s ${ruby}/bin/gem "$out/bin/gem"
      '';
    }
  ] { inherit (ruby) gemPath; };
  replaced = bundler.editRuntime (r: r // { ruby = shim; });
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  unknownRejected = q: !(builtins.tryEval ((q.override { nonsense = true; }).drvPath)).success;
  identities = q: {
    noOp =
      (q.override { }).drvPath == q.drvPath
      && (q.edit (s: s)).drvPath == q.drvPath
      && (q.editRuntime (r: r)).drvPath == q.drvPath
      && (q.editSteps (s: s)).drvPath == q.drvPath;
    unknown = unknownRejected q;
    baseRebound =
      let
        edited = q.edit (s: s // { base = s.base.override { name = "control-base"; }; });
      in
      (edited.testContext.mkTest {
        package = edited;
        name = "base-probe";
        script = "printf okay";
        expected = "okay";
      }).tvp.base == "control-base";
    equivalent =
      (q.override { src = "${tinySource}/source.tar.gz"; }).drvPath
      == (q.edit (s: s // { src = "${tinySource}/source.tar.gz"; })).drvPath;
    sourceRebound =
      contains "${tinySource}/source.tar.gz"
        (builtins.head (q.edit (s: s // { src = "${tinySource}/source.tar.gz"; })).buildSteps).run;
  };
  off = ruby.override {
    yjit = false;
    rustc = throw "disabled YJIT forced binary Rust";
  };
  checkFeature =
    enabled: q:
    q.edit (
      s:
      s
      // {
        tvp = s.tvp // {
          features = s.tvp.features // {
            doCheck = enabled;
          };
        };
      }
    );
  yamlChecksDisabled = checkFeature false yaml;
  yamlChecksReenabled = checkFeature true (yaml.override { doCheck = false; });
  runtime = ruby.editRuntime (r: r // { libyaml = p.libyaml_0_2_4; });
  legacyFactory =
    directory: family: attr:
    let
      factory = (import directory { inherit pkgs tvp; }).recipes.${family};
      old = (tvp.lib.packages.mkVersions factory.constructionRecipe).${attr};
      chosen = pkgs // {
        runCommand = name: args: script: { selectedPkgs = true; };
      };
      public = (factory.extraArgs.mkTests.override { pkgs = chosen; }) old;
      retained = (factory.constructionRecipe.extraArgs.mkTests.override { pkgs = chosen; }) old;
    in
    public.version.selectedPkgs && retained.version.selectedPkgs;
  contracts = {
    libyaml = identities yaml;
    libyamlBoundary = {
      defaultCheckEnabled = yaml.specification.upstreamCheck.enabled && yaml.tests ? upstream;
      editedCheckDisabled =
        !yamlChecksDisabled.specification.tvp.features.doCheck
        && !yamlChecksDisabled.specification.upstreamCheck.enabled
        && !(yamlChecksDisabled.tests ? upstream);
      editedCheckReenabled =
        yamlChecksReenabled.specification.tvp.features.doCheck
        && yamlChecksReenabled.specification.upstreamCheck.enabled
        && yamlChecksReenabled.tests ? upstream;
      overrideEditEquivalent = yamlChecksDisabled.drvPath == (yaml.override { doCheck = false; }).drvPath;
      disabledCheckReusesProducer =
        yamlChecksDisabled.artifact.drvPath == yaml.artifact.drvPath
        && yamlChecksDisabled.drvPath == yaml.drvPath;
      reenabledCheckRestoresProducer = yamlChecksReenabled.drvPath == yaml.drvPath;
    };
    ruby = identities ruby;
    bundler = (identities bundler) // {
      selectedInterpreter = contains "${shim}/bin/ruby" (step "bundler.wrappers" replaced).run;
      provider =
        let
          env = base.environment { tools = [ replaced ]; };
        in
        contains "bundler-2.5.20/lib" env.env.RUBYLIB;
    };
    legacyCallers = {
      libyaml = legacyFactory ../../../libraries/libyaml "libyaml" "libyaml_0_2_4";
      ruby = legacyFactory ../../../runtimes/ruby "ruby" "ruby_3_3_12";
      bundler = legacyFactory ../. "bundler" "bundler_2_5_11";
    };
    rubyBoundary = {
      disabledRustLazy = off.drvPath != ruby.drvPath && !(off.tvp.deps ? rustc);
      noZjit = !(ruby.tvp.jit ? zjit);
      sourceCompiler = ruby.tvp.cc.outPath == candidate.toolchain.driver.outPath;
      sourcePrepare = contains "${tinySource}/source.tar.gz" (step "source.unpack" cheapRuby).run;
      runtimeLookup = contains "${p.libyaml_0_2_4}/lib" (step "ruby.lookup.yaml" runtime).run;
      compileProviderPreserved =
        runtime.specification.libraries.libyaml.drvPath == ruby.specification.libraries.libyaml.drvPath;
      runtimeSummary =
        map toString runtime.runtime.libraries == map toString [
          runtime.runtime.openssl
          runtime.runtime.zlib
          runtime.runtime.libyaml
          runtime.runtime.libffi
        ];
      bashRebound =
        let
          q = ruby.edit (s: s // { bash = candidate.tools.bash; });
        in
        contains "${q.specification.bash}/bin/bash" (step "ruby.prepare" q).run;
      makeRebound =
        let
          q = ruby.edit (
            s:
            s
            // {
              tools = s.tools // {
                gnumake = shim;
              };
            }
          );
        in
        contains "${shim}/bin/make" (step "ruby.build" q).run;
    };
  };
  flat = lib.concatMap builtins.attrValues (builtins.attrValues contracts);
in
assert
  builtins.all (x: x) flat
  || throw "Ruby/Bundler customization contract failure: ${builtins.toJSON contracts}";
package.testContext.mkTest {
  inherit package;
  name = "owned-customization";
  tools = [
    candidate.tools.grep
    shim
  ];
  script = ''
    test "$(cat ${cheapYaml}/marker)" = controlled
    test "$(cat ${cheapRuby}/marker)" = controlled
    head -1 ${replaced}/bin/bundle > interpreter
    grep -Fx '#!${shim}/bin/ruby' interpreter >&2
    env -i HOME="$TMPDIR" ${replaced}/bin/bundle --version > version
    grep -Fx 'Bundler version ${bundler.version}' version >&2
    # Explicit provider activation contributes Bundler's source library directory.
    env -i HOME="$TMPDIR" RUBYLIB=${
      lib.escapeShellArg (base.environment { tools = [ replaced ]; }).env.RUBYLIB
    } ${ruby}/bin/ruby -rbundler -e 'abort unless Bundler::VERSION == "2.5.20"'
    printf customization-ok
  '';
  expected = "customization-ok";
}
// {
  inherit contracts;
}
