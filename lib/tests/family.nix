# Pure API contracts. The model derivations are deliberately not buildable.
{ lib }:
let
  builder = import ../builder.nix { inherit lib; };
  package =
    name:
    builtins.derivation {
      inherit name;
      system = "x86_64-linux";
      builder = "/never-build-this-model";
    };
  compiler =
    name:
    (package name)
    // {
      bintools = package "${name}-binutils";
      libc = package "${name}-libc";
      runtimeDirectories = [ "${package name}/lib" ];
      defaultHardeningFlags = [ ];
    };
  base = builder.base {
    name = "family-model";
    platform = {
      system = "x86_64-linux";
      config = "x86_64-unknown-linux-gnu";
      isMusl = false;
    };
    compiler = compiler "first-compiler";
    shell = package "first-shell";
    coreutils = package "first-coreutils";
    tools = [ (package "first-coreutils") ];
    standardTools = {
      gnumake = package "first-make";
      gnutar = package "first-tar";
      unused = throw "unused standard tool forced";
    };
  };
  context = {
    inherit builder base;
    helpers = {
      inherit lib;
      tvp = {
        inherit builder;
      };
      unused = throw "unused helper forced";
    };
  };
  api =
    (import ../default.nix {
      inherit lib;
      familyContext = context;
    }).packages;
  args = {
    pname = "family-model";
    defs."1" = {
      builder = ./fixtures/family-recipe.nix;
      deps.dependency = package "dependency";
    };
    releases =
      { defs }:
      [
        {
          def = defs."1";
          releases."1" = "model";
        }
      ];
    source = _: builtins.toFile "family-source" "source";
    tests =
      { package, context, ... }:
      context.mkSuite {
        inherit package;
        tests.message = {
          script = "printf value";
          expected = "value";
        };
      };
  };
  family = api.mkFamily args;
  p = family.canonical.family-model_1;
  withoutTests = (api.mkFamily (args // { tests = _: { }; })).canonical.family-model_1;
  replacement = base.override {
    compiler = compiler "second-compiler";
    shell = package "second-shell";
    coreutils = package "second-coreutils";
    tools = [ (package "second-coreutils") ];
    standardTools.gnumake = package "second-make";
  };
  rebound = p.override { base = replacement; };
  explicit = (p.override { bash = package "explicit-shell"; }).override { base = replacement; };
  runtime = p.editRuntime (_: {
    message = "second";
  });
  retested = p.mkTests.override { tests = _: { }; };
  customDependencies =
    dependencyNames:
    (api.mkFamily (
      args
      // {
        defs."1" = args.defs."1" // {
          inherit dependencyNames;
        };
      }
    )).canonical.family-model_1;
  floorVisible =
    package: builtins.all (name: package.tvp.declaredDependencies ? ${name}) standardNames;
  standardNames = [
    "bash"
    "coreutils"
    "binutils"
    "gnumake"
  ];
  coreutilsOnly = base.override { coreutils = package "replacement-coreutils"; };
  edited = p.edit (s: s // { base = replacement; });
  independent = api.mkFamily (
    args
    // {
      context = context // {
        base = throw "final base was forced during construction";
      };
      defs."1" = args.defs."1" // {
        deps.dependency = throw "public dependency was forced";
      };
    }
  );
  constructed = independent.instantiate {
    version = "1";
    inherit base;
    deps.dependency = package "dependency";
  };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    stageLocalInstantiation = constructed.drvPath == p.drvPath;
    baseEditRebindsMake =
      edited.specification.gnumake.drvPath == replacement.standardTools.gnumake.drvPath;
    baseEditRebindsShell = edited.specification.bash.drvPath == replacement.shell.drvPath;
    baseEditRebindsMetadata =
      edited.tvp.declaredDependencies.gnumake.drvPath == replacement.standardTools.gnumake.drvPath;
    baseEditRebindsTests =
      edited.tests.message.specification.base.compiler.drvPath == replacement.compiler.drvPath;
    implicitConstructor = p ? artifact && !(p ? overrideAttrs);
    implicitHelpers = builtins.isString p.drvPath;
    standardShell = p.specification.bash.drvPath == base.shell.drvPath;
    standardCoreutils = p.specification.coreutils.drvPath == base.coreutils.drvPath;
    standardBinutils = p.specification.binutils.drvPath == base.compiler.bintools.drvPath;
    standardMake = p.specification.gnumake.drvPath == base.standardTools.gnumake.drvPath;
    makeOverrideRebinds =
      rebound.specification.gnumake.drvPath == replacement.standardTools.gnumake.drvPath;
    partialToolOverride = replacement.standardTools.gnutar.drvPath == base.standardTools.gnutar.drvPath;
    explicitToolWins =
      ((p.override { gnumake = package "explicit-make"; }).override { base = replacement; })
      .specification.gnumake.drvPath == (package "explicit-make").drvPath;
    toolMetadataRebound =
      rebound.tvp.declaredDependencies.gnumake.drvPath == replacement.standardTools.gnumake.drvPath;
    onlyConsumedStandards =
      !(p.tvp.declaredDependencies ? gnutar) && !(p.tvp.declaredDependencies ? unused);
    declaredFloor = builtins.all (n: p.tvp.declaredDependencies ? ${n}) [
      "bash"
      "coreutils"
      "binutils"
    ];
    customListPreservesFloor = floorVisible (customDependencies [ "dependency" ]);
    customFunctionPreservesFloor = floorVisible (customDependencies (_: [ "dependency" ]));
    coreutilsOverrideRebindsFloor =
      map (p: p.drvPath) coreutilsOnly.tools == [ coreutilsOnly.coreutils.drvPath ];
    baseOverride =
      rebound.specification.bash.drvPath == replacement.shell.drvPath
      && rebound.specification.coreutils.drvPath == replacement.coreutils.drvPath
      && rebound.specification.binutils.drvPath == replacement.compiler.bintools.drvPath;
    metadataRebound = rebound.tvp.deps.coreutils.drvPath == replacement.coreutils.drvPath;
    explicitWins = explicit.specification.bash.drvPath == (package "explicit-shell").drvPath;
    functionOverrideSeesDefaults =
      (p.override (args: {
        bash = args.bash;
      })).drvPath == p.drvPath;
    noop = (p.override { }).drvPath == p.drvPath && (p.edit (s: s)).drvPath == p.drvPath;
    testsFollowBase =
      rebound.tests.message.specification.base.compiler.drvPath == replacement.compiler.drvPath;
    testsFollowShell =
      explicit.tests.message.specification.bash.drvPath == explicit.specification.bash.drvPath;
    runtimeIsolation = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    testFactoryOverride = retested p == { };
    sharedTests = builtins.attrNames p.tests == [ "message" ];
    testChangesReuseProduction =
      withoutTests.tests == { }
      && withoutTests.artifact.drvPath == p.artifact.drvPath
      && withoutTests.drvPath == p.drvPath;
    unknownArgument = rejects (p.override { typo = true; }).drvPath;
    invalidStandardTool =
      rejects
        (p.override { base = base.override { standardTools.gnumake = "not a package"; }; }).drvPath;
    wrongStandardPlatform =
      rejects
        (p.override {
          base = base.override {
            standardTools.gnumake = (package "foreign-make") // {
              system = "aarch64-linux";
            };
          };
        }).drvPath;
    reservedStandardTool = rejects (
      base.override { standardTools.coreutils = package "shadow-coreutils"; }
    );
    invalidDependency =
      rejects
        (api.mkFamily (
          args
          // {
            defs."1" = args.defs."1" // {
              deps.dependency = "not a package";
            };
          }
        )).canonical.family-model_1.drvPath;
    missingContext = rejects (
      (api.mkFamily (args // { context = null; })).canonical.family-model_1.drvPath
    );
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Family contracts: ${lib.concatStringsSep ", " failed}";
results
