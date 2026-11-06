{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-full-gcc.nix { inherit bootstrap; };
  previous = import ./source-gcc-graphviz-validation.nix { inherit bootstrap; };
  inherit (f.composition)
    lib
    base
    bash
    coreutils
    builder
    ;
  consumer = builder {
    recipe =
      { }:
      final: {
        pname = "source-full-gcc-validation";
        version = "1";
        src = null;
        inherit base bash coreutils;
        outputs = [
          "out"
          "evidence"
        ];
        environment.tools = [
          f.prerequisites.tools.python
          f.native.binutils
        ];
        plan = [
          (
            (final.base.environment final.environment)
            // {
              name = "gcc.validation";
              run = ''
                ${f.prerequisites.tools.python}/bin/python3 -B ${./source-full-gcc-checks.py} "$out" "$evidence" ${
                  lib.escapeShellArg (
                    builtins.toJSON {
                      compiler = toString f.compiler;
                      zlib = toString f.prerequisites.zlib;
                      zstd = toString f.prerequisites.zstd;
                      gmp = toString f.prerequisites.gmp;
                      driver = toString f.driver;
                      libc = toString f.native.profile.libc;
                      binutils = toString f.native.binutils;
                      evidence = toString f.compiler.evidence;
                      previousEvidence = toString previous.consumer.evidence;
                      shell = toString bash;
                      coreutils = toString coreutils;
                    }
                  )
                }
              '';
            }
          )
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "source-full-gcc-validation";
    mkTests = _: { };
  };
  libbacktraceChecks = builder {
    recipe = import ../pkgs/compilers/gcc/owned/check-libbacktrace.nix;
    args = {
      inherit
        lib
        base
        bash
        coreutils
        ;
      source = f.source;
      version = f.compiler.version;
      gnumake = f.prerequisites.tools.make;
      inherit (f.prerequisites) zlib zstd;
      tools =
        [
          f.file
        ]
        ++ map (n: f.prerequisites.tools.${n}) [
          "sed"
          "grep"
          "findutils"
          "diffutils"
          "gawk"
          "gzip"
          "xz"
        ];
    };
    dependencyNames = [
      "source"
      "gnumake"
      "zlib"
      "zstd"
    ];
    metadata = { };
    selection.kind = "source-full-gcc-support-check";
    mkTests = _: { };
  };
  step = p: builtins.head (builtins.filter (s: s.name == "gcc.configure") p.buildSteps);
  rebound =
    (import ./source-base.nix {
      inherit bootstrap;
      compiler = f.native.driver // {
        outPath = "/replacement/compiler";
      };
    }).base;
in
{
  inherit f consumer libbacktraceChecks;
  contracts = {
    driverCustomizationMaintainsInterface =
      (f.driver.editSteps (plan: plan)).bintools.drvPath == f.native.binutils.drvPath;
    sourceEdit =
      lib.hasInfix "/replacement/source"
        (builtins.head ((f.compiler.edit (s: s // { src = "/replacement/source"; })).buildSteps)).run;
    sourceOverride = (f.compiler.override { source = f.native.source; }).drvPath != f.compiler.drvPath;
    dependencyOverride =
      (f.compiler.override { zlib = f.prerequisites.zstd; }).drvPath != f.compiler.drvPath;
    baseEdit =
      (step (f.compiler.edit (s: s // { base = rebound; }))).env.CC == "/replacement/compiler/bin/cc";
    baseOverride =
      (step (f.compiler.override { base = rebound; })).env.CC == "/replacement/compiler/bin/cc";
    environmentCC =
      (step (
        f.compiler.edit (
          s:
          s
          // {
            environment = s.environment // {
              overrides.values.CC = "/replacement/cc";
            };
          }
        )
      )).env.CC == "/replacement/cc";
    stepEdit =
      (f.compiler.editSteps (builder.steps.replace "gcc.install" (s: s // { run = s.run + "\ntrue"; })))
      .drvPath != f.compiler.drvPath;
    reconstructedBase = (consumer.specification.base.environment { }).env.CC == "${f.driver}/bin/cc";
  };
}
