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
  defs = api.mkDefs {
    "1" = {
      builder = ./fixtures/family-recipe.nix;
      deps.dependency = package "dependency";
    };
  };
  args = {
    pname = "family-model";
    versionTable = api.mkTable [
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
  canonical = api.mkVersions family;
  aliases = api.mkAliases {
    inherit (family) pname versionTable;
    inherit canonical;
  };
  p = canonical.family-model_1;
  build = args: (api.mkVersions (api.mkFamily args)).family-model_1;
  descriptor = (import ../sources { inherit lib; }).archive {
    url = version: "https://example.invalid/family-${version}.tar.xz";
    fetch = args.source;
    discovery = {
      type = "git-tags";
      url = "https://git.example.invalid/family.git";
      prefix = "v";
    };
  };
  described = build (args // { source = descriptor; });
  overriddenSource = build (
    (withDefinition (
      defs."1"
      // {
        source = (import ../sources { inherit lib; }).archive {
          url = "https://mirror.example.invalid/source.tar.xz";
          fetch = args.source;
        };
      }
    ))
    // {
      source = descriptor;
    }
  );
  withDefinition =
    def:
    args
    // {
      versionTable."1" = args.versionTable."1" // {
        inherit def;
      };
    };
  withoutTests = build (args // { tests = _: { }; });
  replacement = base.override {
    compiler = compiler "second-compiler";
    shell = package "second-shell";
    coreutils = package "second-coreutils";
    tools = [ (package "second-coreutils") ];
    standardTools.gnumake = package "second-make";
  };
  definitionBaseFamily = api.mkFamily (withDefinition (defs."1" // { base = replacement; }));
  definitionBaseCanonical = (api.mkVersions definitionBaseFamily).family-model_1;
  definitionBaseDefault = definitionBaseFamily.instantiate { version = "1"; };
  explicitCallerBase = definitionBaseFamily.instantiate {
    version = "1";
    inherit base;
  };
  rebound = p.override { base = replacement; };
  explicit = (p.override { bash = package "explicit-shell"; }).override { base = replacement; };
  runtime = p.editRuntime (_: {
    message = "second";
  });
  retested = p.mkTests.override { tests = _: { }; };
  probeTestConfiguration =
    (p.mkTests.override {
      tests =
        { package, ... }:
        {
          inherit (package) drvPath;
          options = package.testConfiguration;
        };
      helpers = "caller-helpers";
    })
      p;
  dependencyFamily = api.mkFamily (args // { testDeps.tool = package "default-test-tool"; });
  dependencyPackage = (api.mkVersions dependencyFamily).family-model_1;
  probeTestDependency =
    (dependencyPackage.mkTests.override {
      tests = { package, ... }: package.tvp.declaredTestDependencies.tool;
      tool = package "selected-test-tool";
    })
      dependencyPackage;
  customDependencies =
    dependencyNames: build (withDefinition (defs."1" // { inherit dependencyNames; }));
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
    (withDefinition (
      defs."1"
      // {
        deps.dependency = throw "public dependency was forced";
      }
    ))
    // {
      context = context // {
        base = throw "final base was forced during construction";
      };
    }
  );
  constructed = independent.instantiate {
    version = "1";
    inherit base;
    deps.dependency = package "dependency";
  };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  inlineTable = api.mkTable [
    {
      def = builtins.removeAttrs defs."1" [ "name" ];
      releases."1" = "model";
    }
  ];
  inline = build (args // { versionTable = inlineTable; });
  numericTable = api.mkTable [
    {
      def.builder = ./fixtures/family-recipe.nix;
      releases = {
        "1.10" = "ten";
        "1.9" = "nine";
      };
    }
  ];
  withoutOrigin = api.mkVersions (
    (builtins.removeAttrs family [ "authoring" ])
    // {
      versionTable = lib.mapAttrs (
        _: entry:
        entry
        // {
          def = builtins.removeAttrs entry.def [ "authoring" ];
        }
      ) family.versionTable;
    }
  );
  registration = api.mergeNamespaces {
    libraries = api.mergeNamespaces {
      family-model = {
        recipes.family-model = family;
        inherit canonical aliases;
      };
    };
  };
  lazyRegistration = api.mergeNamespaces {
    family-model = {
      recipes.family-model = family;
      canonical = throw "origin inventory forced production";
      aliases = throw "origin inventory forced aliases";
    };
  };
  results = {
    sourceDescriptorPreservesProduction =
      described.drvPath == p.drvPath && described.artifact.drvPath == p.artifact.drvPath;
    sourceDescriptorMetadata =
      described.tvp.source.url == "https://example.invalid/family-1.tar.xz"
      && described.tvp.upstream.normalise "v1" == "1";
    effectiveDefinitionSource =
      overriddenSource.tvp.source.url == "https://mirror.example.invalid/source.tar.xz"
      && !(overriddenSource.tvp ? upstream)
      && overriddenSource.drvPath == p.drvPath;
    duplicateDiscoveryRejected = rejects (
      (build (
        args
        // {
          source = descriptor;
          packageMeta.upstream = descriptor.discovery;
        }
      )).tvp.source
    );
    sourceDescriptorConflictsRejected =
      rejects
        (build (
          args
          // {
            source = descriptor;
            packageMeta.upstream = {
              type = "git-tags";
              url = "https://other.invalid/family.git";
            };
          }
        )).tvp.upstream;
    evaluatedOrigin =
      family.authoring == {
        origin = "tvp.lib.packages.mkFamily";
        model = "ordinary-family/v1";
      };
    definitionOrigin = family.versionTable."1".def.authoring == family.authoring;
    originIsNotProductionInput =
      p.drvPath == withoutOrigin.family-model_1.drvPath
      && p.artifact.drvPath == withoutOrigin.family-model_1.artifact.drvPath
      && p.tests.message.drvPath == withoutOrigin.family-model_1.tests.message.drvPath;
    registeredEntrypointOrigin =
      registration.familyEntrypoints == [
        {
          namespaces = [
            "libraries"
            "family-model"
          ];
          recipes.family-model = {
            origin = family.authoring;
            versionOrigins."1" = family.authoring;
            retainedConstructionRecipe = false;
          };
        }
      ];
    inventoryDoesNotForceProduction =
      builtins.length (
        builtins.deepSeq lazyRegistration.familyEntrypoints lazyRegistration.familyEntrypoints
      ) == 1;
    inlineDefinition = inlineTable."1".def == defs."1";
    inlinePreservesProduction =
      inline.artifact.drvPath == p.artifact.drvPath && inline.drvPath == p.drvPath;
    inlinePreservesTests = inline.tests.message.drvPath == p.tests.message.drvPath;
    inferredNumericLabel =
      numericTable."1.10".def.name == "1.9" && numericTable."1.9".def.name == "1.9";
    emptyDependencies = numericTable."1.9".def.deps == { };
    explicitLabelsPreserved =
      (api.mkTable [
        {
          def = defs."1";
          releases."2" = "second";
        }
      ])."2".def.name == "1";
    duplicateInlineReleasesRejected = rejects (
      api.mkTable [
        {
          def = { };
          releases."1" = "first";
        }
        {
          def = { };
          releases."1" = "second";
        }
      ]
    );
    testConfigurationOverride = probeTestConfiguration.options.helpers == "caller-helpers";
    testConfigurationPreservesProduction = probeTestConfiguration.drvPath == p.drvPath;
    testDependencyOverride = probeTestDependency.drvPath == (package "selected-test-tool").drvPath;
    testDependencyPreservesProduction = dependencyPackage.drvPath == p.drvPath;
    explicitComposition = family ? versionTable && !(family ? canonical) && !(family ? aliases);
    generatedAliases = aliases.family-model.drvPath == p.drvPath;
    stageLocalInstantiation = constructed.drvPath == p.drvPath;
    omittedBaseHonorsDefinition =
      definitionBaseDefault.specification.base.compiler.drvPath == replacement.compiler.drvPath
      && definitionBaseDefault.drvPath == definitionBaseCanonical.drvPath
      && definitionBaseDefault.artifact.drvPath == definitionBaseCanonical.artifact.drvPath;
    explicitCallerBaseStillAuthoritative =
      explicitCallerBase.specification.base.compiler.drvPath == base.compiler.drvPath
      && explicitCallerBase.drvPath == p.drvPath
      && explicitCallerBase.artifact.drvPath == p.artifact.drvPath;
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
      map (p: p.drvPath) coreutilsOnly.baselineTools == [ coreutilsOnly.coreutils.drvPath ];
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
        (build (withDefinition (defs."1" // { deps.dependency = "not a package"; }))).drvPath;
    missingContext = rejects ((build (args // { context = null; })).drvPath);
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Family contracts: ${lib.concatStringsSep ", " failed}";
results
