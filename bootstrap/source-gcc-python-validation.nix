{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-gcc-python-tests.nix { inherit bootstrap; };
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  make =
    recipe: args:
    builder {
      inherit recipe args;
      dependencyNames = builtins.attrNames args;
      metadata = { };
      selection.kind = "source-gcc-python-validation";
      mkTests = _: { };
    };
  py = f.packages.pytest;
  packages = builtins.attrValues f.packages;
in
{
  inherit f;
  consumer = make (
    { }:
    final: {
      pname = "source-gcc-python-validation";
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
          f.tools.tar
          f.tools.gzip
          f.tools.findutils
        ];
        libraries = [ ];
      };
      plan = [
        (
          (final.base.environment final.environment)
          // {
            name = "python.validation";
            run = ''
              ${f.tools.python}/bin/python3 -B ${./source-gcc-python-checks.py} "$out" "$evidence" ${
                lib.escapeShellArg (
                  builtins.toJSON {
                    profile = toString f.profile;
                    python = toString f.tools.python;
                    packages = builtins.mapAttrs (_: p: toString p) f.packages;
                    sources = builtins.mapAttrs (_: p: toString p) f.sources;
                    shell = toString bash;
                    coreutils = toString coreutils;
                    compiler = toString f.harness.native.driver;
                    gccSource = toString f.harness.native.source;
                    expect = toString f.harness.expect;
                  }
                )
              } ${./source-gcc-python-results.py}
            '';
          }
        )
      ];
    }
  ) { };
  contracts =
    let
      step = p: builtins.head (builtins.filter (s: s.name == "python.build") p.buildSteps);
      rebound =
        (import ./source-base.nix {
          inherit bootstrap;
          compiler = f.harness.native.driver // {
            outPath = "/missing-compiler";
          };
        }).base;
    in
    {
      sourceEdit = builtins.all (
        p:
        lib.hasInfix "/replacement/archive"
          (builtins.head (p.edit (s: s // { src = "/replacement/archive"; })).buildSteps).run
      ) packages;
      sourceOverride = (py.override { src = f.sources.click; }).drvPath != py.drvPath;
      inputOverride = (py.override { python = f.harness.prerequisites.perl; }).drvPath != py.drvPath;
      baseOverride = (step (py.override { base = rebound; })).env.CC == "/missing-compiler/bin/cc";
      baseEdit = (step (py.edit (s: s // { base = rebound; }))).env.CC == "/missing-compiler/bin/cc";
      environmentReplacement =
        (step (
          py.edit (
            s:
            s
            // {
              environment = s.environment // {
                overrides.values.PYRSISTENT_SKIP_EXTENSION = "replacement";
              };
            }
          )
        )).env.PYRSISTENT_SKIP_EXTENSION == "replacement";
      stepEdit =
        (py.editSteps (builder.steps.replace "python.build" (s: s // { run = s.run + "\ntrue"; }))).drvPath
        != py.drvPath;
      reusedPython = f.tools.python.drvPath == f.harness.tools.python.drvPath;
      reusedCompiler = f.harness.native.driver.drvPath == f.harness.prerequisites.native.driver.drvPath;
    };
}
