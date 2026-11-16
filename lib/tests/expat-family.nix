# Source/plan contracts; root evaluates these before the one selected build.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/libraries/expat { inherit pkgs tvp; };
  p = family.canonical.expat_2_9_0;
  prior = (import ../../bases/source-gnu { }).tools;
  marker = builtins.derivation {
    name = "expat-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-expat-tool";
  };
  baseEdit = role: p.edit (s: s // { base = s.base.override { standardTools.${role} = marker; }; });
  cmake = baseEdit "cmake";
  ninja = baseEdit "ninja";
  python = baseEdit "python";
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  unchecked = p.override { doCheck = false; };
  checkOnly = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = ": changed check";
      };
    }
  );
  prepOnly = p.edit (
    s:
    s
    // {
      upstreamPolicy = s.upstreamPolicy // {
        ctestFlags = [
          "--verbose"
          "--no-tests=error"
        ];
      };
    }
  );
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "/expat-runtime-probe" ]; });
  scalar = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values = {
          CFLAGS = "-O0 -DSELECTED=42";
          LDFLAGS = "-Wl,--as-needed";
        };
      };
    }
  );
  structured = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.flags = {
          NIX_CFLAGS_COMPILE = [
            "-O0"
            "-DSELECTED=42"
          ];
          NIX_LDFLAGS = [ "--as-needed" ];
        };
      };
    }
  );
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  historical = import ../../pkgs/libraries/expat/tests/construction-callers.nix { inherit pkgs tvp; };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  results = {
    wholeFamily = builtins.attrNames family.recipes.expat.versionTable == [ "2.9.0" ];
    oneProcedure =
      builtins.baseNameOf family.recipes.expat.versionTable."2.9.0".def.builder == "build.nix";
    implicitNoLibraryDependencies = family.recipes.expat.versionTable."2.9.0".def.deps == { };
    oneSplit = builtins.length (builtins.filter (s: (s.kind or "") == "split") p.buildSteps) == 1;
    productionHasNoTests =
      !(builtins.any (s: s.name == "expat.check" || s.name == "expat.build-upstream") p.buildSteps)
      && lib.hasInfix "-DEXPAT_BUILD_TESTS=OFF" (step "expat.configure" p).run
      && !(lib.hasInfix "-DEXPAT_BUILD_TESTS=ON" (step "expat.configure" p).run);
    savedConfiguredTree =
      builtins.any (s: s.name == "expat.save-build-tree") p.buildSteps
      && p.specification.sourceLayout.buildDirectory == ".tvp-build";
    upstreamConsumesArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    upstreamRestores =
      (builtins.head (p.specification.upstreamPlan p.artifact)).name == "expat.restore-build-tree";
    upstreamBuildsOnlyAfterRestore =
      map (s: s.name) (p.specification.upstreamPlan p.artifact) == [
        "expat.restore-build-tree"
        "expat.configure-upstream"
        "expat.build-upstream"
      ];
    oldFeatureDefaults =
      p.tvp.features.shared
      && !(p.tvp.features.static)
      && p.tvp.features.doCheck
      && !(p.specification.buildFeatures.docs)
      && p.specification.buildFeatures.tools
      && p.specification.buildFeatures.examples;
    oldCMakeProvider = p.specification.base.standardTools.cmake.drvPath == prior.cmake.drvPath;
    oldNinjaProvider = p.specification.base.standardTools.ninja.drvPath == prior.ninja.drvPath;
    oldPkgConfigTestProvider =
      p.specification.base.standardTools.pkg-config.drvPath == prior.pkgConfig.drvPath;
    cmakeRebinds =
      lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/cmake") (step "expat.configure" cmake)
      .run
      && cmake.tvp.deps.cmake.drvPath == marker.drvPath;
    ninjaRebinds =
      lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/ninja") (step "expat.configure" ninja)
      .run
      && ninja.tvp.deps.ninja.drvPath == marker.drvPath;
    pythonRebinds =
      lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/python3") (step "expat.save-build-tree" python)
      .run
      && python.tvp.deps.python.drvPath == marker.drvPath;
    testPolicyReusesProduction = same unchecked && !(unchecked.tests ? upstream);
    commandReusesProduction =
      same checkOnly && checkOnly.tests.upstream.drvPath != p.tests.upstream.drvPath;
    preparationReusesProduction =
      same prepOnly && prepOnly.tests.upstream.drvPath != p.tests.upstream.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    scalarFlagsSurvive =
      (step "expat.configure" scalar).env.CFLAGS == "-O0 -DSELECTED=42"
      && (step "expat.configure" scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlagsSurvive =
      lib.hasInfix "-DSELECTED=42" (step "expat.configure" structured).env.NIX_CFLAGS_COMPILE
      && lib.hasInfix "--as-needed" (step "expat.configure" structured).env.NIX_LDFLAGS;
    productionTestFlagIsRejected =
      rejects
        (p.override { cmakeFlags = [ "-DEXPAT_BUILD_TESTS=ON" ]; }).drvPath;
    customizationIsEvaluated =
      import ../../pkgs/libraries/expat/tests/customization.nix { package = p; } == "customization";
    constructionFactoryObservers = builtins.all (value: value) (
      builtins.attrValues historical.contracts
    );
    singleConstructionDefinition =
      !(family.recipes.expat ? constructionRecipe)
      && family.instantiate { version = "2.9.0"; } ? artifact;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Expat family contracts: ${lib.concatStringsSep ", " failed}";
results
