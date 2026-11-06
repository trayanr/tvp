{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-full-gcc-prerequisites.nix { inherit bootstrap; };
  inherit (f.composition)
    base
    bash
    coreutils
    builder
    ;
  recipe =
    {
      compilerBase ? base,
    }:
    final: {
      pname = "source-full-gcc-prerequisite-consumers";
      version = "1";
      src = null;
      base = compilerBase;
      inherit bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.tools.python
          f.tools.pkgConfig
        ];
        libraries = [
          f.isl
          f.libxcrypt
          f.ncurses
        ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "prerequisites.consumers";
            run = ''
              mkdir -p "$out/bin" "$evidence"
              export PREREQUISITES=${
                f.composition.lib.escapeShellArg (
                  builtins.toJSON (
                    builtins.mapAttrs (_: toString) {
                      inherit (f)
                        isl
                        libxcrypt
                        which
                        ncurses
                        texinfo
                        ;
                    }
                  )
                )
              }
              export FIXTURES=${
                f.composition.lib.escapeShellArg (
                  builtins.toJSON {
                    islC = ../pkgs/libraries/isl/tests/fixtures/semantics.c;
                    islCxx = ../pkgs/libraries/isl/tests/fixtures/consumer.cc;
                    crypt = ../pkgs/libraries/libxcrypt/tests/fixtures/api.c;
                    vectors = ../pkgs/libraries/libxcrypt/tests/fixtures/vectors.h;
                    terminfo = ../pkgs/libraries/ncurses/tests/fixtures/terminfo.c;
                    panel = ../pkgs/libraries/ncurses/tests/fixtures/panel.c;
                    manual = ../pkgs/build-tools/texinfo/tests/fixtures/manual.texi;
                  }
                )
              }
                          export SOURCE_PERL=${f.perl}
              export LOCALE_TOOL=${f.tools.localeTools}/bin/locale
              export READELF=${f.tools.binutils}/bin/readelf
              ${f.python}/bin/python3 -B ${./source-full-gcc-prerequisite-checks.py} "$out" "$evidence"
            '';
          }
        )
      ];
    };
  make =
    args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-full-gcc-prerequisite-tests";
      mkTests = _: { };
    };
  consumer = make { };
  ccOf = p: (builtins.head p.buildSteps).env.CC;
  poisoned =
    (import ./source-base.nix {
      inherit bootstrap;
      compiler = f.native.driver // {
        outPath = "/missing-native-compiler";
      };
    }).base;
in
{
  inherit f consumer;
  upstream = builder {
    recipe =
      { }:
      {
        pname = "source-full-gcc-prerequisite-upstream";
        version = "1";
        src = null;
        inherit base bash coreutils;
        plan = [
          {
            name = "upstream.classify";
            tools = [ f.python ];
            run = ''${f.python}/bin/python3 -B ${./source-full-gcc-prerequisite-upstream.py} "$out" ${
              f.composition.lib.escapeShellArg (
                builtins.toJSON (
                  builtins.mapAttrs (_: p: toString p.evidence) {
                    inherit (f)
                      isl
                      libxcrypt
                      which
                      texinfo
                      ;
                  }
                )
              )
            } ${f.native.driver}/bin/cc'';
          }
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "source-full-gcc-prerequisite-tests";
    mkTests = _: { };
  };
  contracts = {
    packageEnvironmentReplacement =
      builtins.all
        (
          p:
          let
            edited = p.edit (
              s:
              s
              // {
                environment = s.environment // {
                  overrides.values.CC = "/explicit-package-compiler";
                };
              }
            );
          in
          builtins.length (
            builtins.filter (step: builtins.match ".*\\.configure" step.name != null) edited.buildSteps
          ) == 1
          && builtins.all (step: step.env.CC == "/explicit-package-compiler") (
            builtins.filter (step: builtins.match ".*\\.configure" step.name != null) edited.buildSteps
          )
        )
        [
          f.isl
          f.libxcrypt
          f.which
          f.ncurses
          f.texinfo
        ];
    nativeCompiler = ccOf consumer == "${f.native.driver}/bin/cc";
    constructorBase =
      ccOf (make {
        compilerBase = poisoned;
      }) == "/missing-native-compiler/bin/cc";
    editedBase =
      ccOf (consumer.edit (s: s // { base = poisoned; })) == "/missing-native-compiler/bin/cc";
    environmentReplacement =
      ccOf (
        consumer.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.CC = "/explicit-environment-compiler";
            };
          }
        )
      ) == "/explicit-environment-compiler";
    sourceReplacement = (f.which.override { src = f.sources.isl; }).drvPath != f.which.drvPath;
    stepEdit =
      (consumer.editSteps (
        builder.steps.replace "prerequisites.consumers" (s: s // { run = s.run + "\ntrue"; })
      )).drvPath != consumer.drvPath;
    publicGmp = builtins.elem f.gmp f.isl.development.libraries;
    reusedGmp = f.gmp.drvPath == f.native.gmp.drvPath;
  };
}
