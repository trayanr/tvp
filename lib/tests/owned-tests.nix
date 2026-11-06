# Pure interface contracts. Model paths are never built.
{ lib, builder }:
let
  tests = import ../tests.nix { inherit lib; };
  data = builtins.toFile "owned-test-model" "data";
  pkg = name: {
    inherit name;
    outPath = "${data}/${name}";
  };
  compiler =
    name:
    (pkg name)
    // {
      bintools = pkg "binutils";
      libc = pkg "libc";
      runtimeDirectories = [ "${data}/${name}/lib" ];
      defaultHardeningFlags = [ ];
    };
  base = builder.base {
    name = "test-model";
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    compiler = compiler "cc";
    shell = pkg "shell";
    tools = [ ];
  };
  coreutils = pkg "coreutils";
  package = (pkg "package") // {
    pname = "package";
    version = "1";
  };
  context = tests.forBase { inherit builder base coreutils; };
  spec = {
    inherit package;
    name = "value";
    script = "printf value";
    expected = "value";
  };
  p = context.mkTest spec;
  changedBase = base.override {
    compiler = compiler "changed";
    shell = pkg "other-shell";
  };
  changed =
    (tests.forBase {
      inherit builder coreutils;
      base = changedBase;
    }).mkTest
      spec;
  tool = (pkg "tool") // {
    buildEnvironment = _: { values.PROBE = "tool"; };
  };
  library = (pkg "library") // {
    development.libraries = [ (pkg "public") ];
  };
  withInputs = context.mkTest (
    spec
    // {
      tools = [ tool ];
      libraries = [ library ];
      environment.values.PROBE = "override";
    }
  );
  step = builtins.head withInputs.buildSteps;
  suite = context.mkSuite {
    inherit package;
    tests.value = builtins.removeAttrs spec [
      "name"
      "package"
    ];
    tests.empty = {
      script = ":";
      expected = "";
    };
  };
  batch = context.mkBatch {
    name = "model";
    inherit suite;
  };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    direct = !(p ? stdenv) && !(p ? mkDerivation) && !(p ? runCommand);
    interface =
      builtins.attrNames context == [
        "mkBatch"
        "mkSuite"
        "mkTest"
      ];
    selectedCompiler =
      p.compiler == base.compiler
      && p.tvp.cc == base.compiler
      && changed.compiler == changedBase.compiler
      && changed.drvPath != p.drvPath;
    selectedRuntime =
      changed.specification.base.runtimeDirectories == changedBase.compiler.runtimeDirectories;
    selectedShell = changed.specification.bash == changedBase.shell;
    selectedTools =
      builtins.elem tool step.tools
      && builtins.elem package step.tools
      && builtins.elem coreutils step.tools
      && withInputs.drvPath != p.drvPath;
    publicLibraries =
      map toString step.libraries == map toString [
        library
        (pkg "public")
      ];
    override = step.env.PROBE == "override";
    ccOverride =
      (builtins.head
        (context.mkTest (spec // { environment.values.CC = "/explicit/compiler"; })).buildSteps
      ).env.CC == "/explicit/compiler";
    noop =
      (p.override { }).drvPath == p.drvPath
      && (p.edit (s: s)).drvPath == p.drvPath
      && (p.editSteps (s: s)).drvPath == p.drvPath
      &&
        (
          (tests.forBase {
            inherit builder coreutils;
            base = base.override { };
          }).mkTest
          spec
        ).drvPath == p.drvPath;
    expectedRequired = (builtins.functionArgs context.mkTest).expected == false;
    expectedType = rejects (context.mkTest (spec // { expected = 42; }));
    scriptType = rejects (context.mkTest (spec // { script = [ ]; }));
    unsafeName = rejects (
      context.mkBatch {
        name = "unsafe";
        suite."../escape" = p;
      }
    );
    suiteLeaves =
      builtins.attrNames suite == [
        "empty"
        "value"
      ]
      && suite.value.drvPath == p.drvPath;
    batchLinks =
      batch.testSuite.value.drvPath == suite.value.drvPath
      && batch.passthru.testSuite.empty.drvPath == suite.empty.drvPath;
    provenance =
      p.package == package
      && p.testName == "value"
      && p.passthru.package == package
      && withInputs.tvp.declaredDependencies.tools == [ tool ]
      && withInputs.tvp.declaredDependencies.libraries == [ library ]
      && p.tvp.declaredInfrastructure.shell == base.shell;
    contexts =
      builtins.hasContext (builtins.head batch.buildSteps).run
      && builtins.hasContext step.env.NIX_LDFLAGS;
  };
  failed = builtins.filter (n: !results.${n}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Owned test contracts: ${lib.concatStringsSep ", " failed}";
results
