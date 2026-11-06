{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-gcc-graphviz-tests.nix { inherit bootstrap; };
  priorValidation = import ./source-gcc-python-validation.nix { inherit bootstrap; };
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  packages = builtins.attrValues f.packages ++ [ f.fonts ];
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-graphviz-validation";
      mkTests = _: { };
    };
in
{
  inherit f;
  consumer = make (
    { }:
    final: {
      pname = "source-gcc-graphviz-validation";
      version = "1";
      src = null;
      inherit base bash coreutils;
      outputs = [
        "out"
        "evidence"
      ];
      environment = {
        tools = [
          f.tools.python
          f.tools.pkgConfig
          f.tools.findutils
        ];
        libraries = builtins.attrValues f.packages;
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "graphviz.validation";
            run = ''
              ${f.tools.python}/bin/python3 -B ${./source-gcc-graphviz-checks.py} "$out" "$evidence" ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    packages = builtins.mapAttrs (_: p: toString p) f.packages;
                    upstream = builtins.mapAttrs (_: p: toString (p.evidence or p)) f.packages;
                    sources = builtins.mapAttrs (_: p: toString p) f.sources;
                    zlib = toString f.previous.harness.prerequisites.zlib;
                    bzip2 = toString (import ./source-python-meson.nix { inherit bootstrap; }).prerequisites.bzip2;
                    m4 = toString f.tools.m4;
                    fonts = toString f.fonts;
                    python = toString f.tools.python;
                    compiler = toString f.previous.harness.native.driver;
                    gccSource = toString f.previous.harness.native.source;
                    expect = toString f.previous.harness.expect;
                    shell = toString bash;
                    pkgConfig = toString f.tools.pkgConfig;
                    previousEvidence = toString priorValidation.consumer.evidence;
                  }
                )
              } ${./source-gcc-graphviz-upstream.py}
            '';
          }
        )
      ];
    }
  ) { };
  contracts =
    let
      p = f.packages.gd;
      step = x: builtins.head (builtins.filter (s: s.name == "gd.build") x.buildSteps);
      rebound =
        (import ./source-base.nix {
          inherit bootstrap;
          compiler = f.previous.harness.native.driver // {
            outPath = "/missing-compiler";
          };
        }).base;
    in
    {
      sourceEdit = builtins.all (
        x:
        lib.hasInfix "/replacement/archive"
          (builtins.head (x.edit (s: s // { src = "/replacement/archive"; })).buildSteps).run
      ) packages;
      sourceOverride = (p.override { src = f.sources.expat; }).drvPath != p.drvPath;
      inputOverride = (p.override { png = f.packages.expat; }).drvPath != p.drvPath;
      baseOverride = (step (p.override { base = rebound; })).env.CC == "/missing-compiler/bin/cc";
      baseEdit = (step (p.edit (s: s // { base = rebound; }))).env.CC == "/missing-compiler/bin/cc";
      environmentReplacement =
        (step (
          p.edit (
            s:
            s
            // {
              environment = s.environment // {
                overrides.values.PROBE = "replacement";
              };
            }
          )
        )).env.PROBE == "replacement";
      stepEdit =
        (p.editSteps (builder.steps.replace "gd.build" (s: s // { run = s.run + "\ntrue"; }))).drvPath
        != p.drvPath;
      reusedCompiler =
        f.previous.harness.native.driver.drvPath == f.previous.harness.prerequisites.native.driver.drvPath;
      reusedBison = f.tools.bison.drvPath == bootstrap.build-bison.drvPath;
      reusedPython = f.tools.python.drvPath == f.previous.tools.python.drvPath;
    };
}
