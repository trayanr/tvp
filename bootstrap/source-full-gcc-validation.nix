{
  bootstrap ? import ./. { },
}:
let
  f = import ./source-full-gcc.nix { inherit bootstrap; };
  previous = import ./source-gcc-graphviz-validation.nix { inherit bootstrap; };
  upstream = f.compiler.tests.upstream-audit;
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
                      productionEvidence = "${f.compiler.artifact}/nix-support/production";
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
  batch = f.compiler.testContext.mkBatch {
    name = "source-full-gcc";
    suite = {
      installed = consumer;
      inherit upstream;
      libbacktrace = libbacktraceChecks;
    };
  };
  testEdited = f.compiler.edit (s: s // { fonts = s.coreutils; });
  classifierEdited = f.compiler.edit (s: s // { upstreamClassifier = s.upstreamSummarizer; });
  testPythonEdited = f.compiler.override { testPython = f.prerequisites.python; };
  productionOnly = f.compiler.edit (
    s:
    s
    // {
      testPython = throw "test Python forced by production";
      pythonConfig = throw "test config forced by production";
      dejagnu = throw "DejaGNU forced by production";
      expect = throw "Expect forced by production";
      flock = throw "test flock forced by production";
      graphviz = throw "Graphviz forced by production";
      fonts = throw "fonts forced by production";
      upstreamCapture = throw "test capture forced by production";
      upstreamRestore = throw "test restoration forced by production";
      upstreamSummarizer = throw "test summary forced by production";
      upstreamClassifier = throw "test classification forced by production";
    }
  );
  sameProduction =
    p: p.drvPath == f.compiler.drvPath && p.artifact.drvPath == f.compiler.artifact.drvPath;
  productionContext =
    p:
    builtins.getContext (
      builtins.toJSON {
        inherit (p.buildStepRunner) inputs text childScripts;
      }
    );
  plain = builtins.unsafeDiscardStringContext;
in
{
  inherit
    f
    consumer
    libbacktraceChecks
    upstream
    batch
    ;
  contracts = {
    splitProduction =
      f.compiler.artifact.drvPath != f.compiler.drvPath
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") f.compiler.buildSteps) == 1;
    noInlineUpstream = !(builtins.any (s: s.name == "gcc.check") f.compiler.buildSteps);
    testInputsStayLazy = sameProduction productionOnly;
    testProviderEditsReuseProduction =
      sameProduction testEdited && testEdited.validation.drvPath != f.compiler.validation.drvPath;
    testPythonEditsReuseProduction =
      sameProduction testPythonEdited
      && testPythonEdited.validation.drvPath != f.compiler.validation.drvPath;
    classifierEditsReuseExecution =
      sameProduction classifierEdited
      && classifierEdited.validation.drvPath == f.compiler.validation.drvPath
      && classifierEdited.tests.upstream-audit.drvPath != upstream.drvPath;
    noTestProviderInputs =
      builtins.all
        (
          p:
          builtins.all (tool: !(builtins.hasAttr (plain tool.drvPath) (productionContext p))) [
            f.compiler.specification.testPython
            f.compiler.specification.dejagnu
            f.compiler.specification.expect
            f.compiler.specification.flock
            f.compiler.specification.graphviz
            f.compiler.specification.fonts
          ]
        )
        [
          f.compiler.artifact
          f.compiler
        ];
    factoryRegistration = upstream.package.drvPath == f.compiler.validation.drvPath;
    batchIncludesUpstream = batch.testSuite.upstream.drvPath == upstream.drvPath;
    driverUsesProductionEvidence = lib.hasInfix "${f.compiler.artifact}/nix-support/production/builtin.specs" (builtins.head f.driver.buildSteps)
    .run;
    driverCustomizationMaintainsInterface =
      (f.driver.editSteps (plan: plan)).bintools.drvPath == f.native.binutils.drvPath;
    driverCompilerOverride =
      lib.hasInfix "/replacement/raw-compiler/"
        (builtins.head (
          (f.driver.override {
            compiler = f.compiler // {
              outPath = "/replacement/raw-compiler";
              artifact = "/replacement/compiler-artifact";
            };
          }).buildSteps
        )).run;
    driverLibcOverride =
      builtins.head ((f.driver.override { libc = "/replacement/libc"; }).runtimeDirectories)
      == "/replacement/libc/lib";
    sourceEdit =
      lib.hasInfix "/replacement/source"
        (builtins.head ((f.compiler.edit (s: s // { src = "/replacement/source"; })).buildSteps)).run;
    sourceOverride = (f.compiler.override { src = f.native.source; }).drvPath != f.compiler.drvPath;
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
