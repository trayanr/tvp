{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  api = tvp.lib.packages;
  steps = tvp.builder.steps;
  family = (import ../../pkgs/libraries/mpfr { inherit pkgs tvp; }).recipes.mpfr;
  p = tvp.canonical.mpfr_4_2_2;
  gmp = tvp.packages.gmp_6_2;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  insert = steps.insertAfter "mpfr.build" [
    {
      name = "fixture.log";
      run = ":";
    }
  ];
  changed = ((p.override { inherit gmp; }).editSteps insert).override (args: {
    gmp = args.gmp;
    doCheck = false;
  });
  runtime = p.editRuntime (_: {
    libraries = [ gmp ];
  });
  dlopenDirectory = "/tvp-runtime-directory-fixture";
  runtimeDirectories = p.editRuntime (r: r // { dlopenDirectories = [ dlopenDirectory ]; });
  referenceRebound = p.override { base = p.specification.base.override { }; };
  reboundRegistry = tvp.lib.provenance.registry {
    canonical.fixture = referenceRebound;
    variants = { };
    bases = { };
  };
  variants = api.mkVariants (
    family
    // {
      inherit pkgs;
      profiles.fixture = {
        base = tvp.bases.default;
        versions."4.2.2".deps = {
          inherit gmp;
        };
      };
    }
  );
  fixtureArgs = {
    pname = "fixture";
    infra = { };
    source = _: p.src;
    versionTable."1" = {
      sha256 = "fixture";
      status = {
        level = "degraded";
        reason = "Intentional test exclusion fixture.";
        needs = "Fixture control.";
        knownTestFailures = [ "excluded" ];
      };
      def = {
        name = "1";
        constructor = tvp.builder;
        builder = ./owned-catalogue-recipe.nix;
        base = tvp.bases.default;
        deps = {
          inherit (tvp.packages) bash coreutils;
          dependency = gmp;
        };
        patches = [
          {
            file = ./owned-catalogue-recipe.nix;
            reason = "Fixture patch declaration.";
          }
        ];
        opts.enabled = false;
      };
    };
    extraArgs.mkTests = package: {
      excluded = throw "excluded test was forced";
      kept = package.outPath;
    };
  };
  fixture = (api.mkVersions fixtureArgs).fixture_1;
  tagged =
    selector: package:
    let
      constrained = api.withConstraint { reason = "Catalogue constraint fixture."; } package;
      edits = [
        (q: q.override { doCheck = false; })
        (
          q:
          q.edit (
            s:
            s
            // {
              meta = s.meta // {
                description = "fixture";
              };
            }
          )
        )
        (q: q.editSteps insert)
        (q: q.editRuntime (r: r))
      ];
    in
    lib.all (
      edit:
      let
        q = edit constrained;
      in
      lib.all
        (
          v:
          v.__tvpSelection.selector == selector
          && v.__tvpSelection.namespace == constrained.__tvpSelection.namespace
          && v.__tvpSelection.canonical == "mpfr_4_2_2"
          && v.__tvpSelection.version == "4.2.2"
          && v.__tvpSelection.kind == "override"
          && v.__tvpSelection.reason == "Catalogue constraint fixture."
          && !(v ? overrideAttrs)
        )
        (
          [
            q
            q.out
          ]
          ++ q.all
        )
      && (edit constrained.out).__tvpSelection.selector == selector
      && (edit (builtins.head constrained.all)).__tvpSelection.reason == "Catalogue constraint fixture."
    ) edits;
  candidate = import ../../bases/source-gnu { };
  sentinel = (import ../../bases/source-gnu/tests/probes.nix { }).sentinel;
  contextChanged =
    (p.override {
      bash = tvp.packages.bash;
      coreutils = tvp.bases.default.components.floor.coreutils;
    }).edit
      (spec: spec // { base = candidate.base.override { compiler = sentinel; }; });
  contextBatch = contextChanged.testContext.mkBatch {
    name = "context-rebound";
    suite = contextChanged.tests;
  };
  splitTest = p.tests.arithmetic.editSteps (
    plan:
    plan
    ++ [
      (steps.split "fixture.inventory")
      {
        name = "fixture.second";
        tools = [ candidate.tools.pkgConfig ];
        run = ":";
      }
    ]
  );
  splitInventory = import ../dependencies.nix {
    inherit pkgs;
    canonical.fixture = p // {
      tests.arithmetic = splitTest;
    };
    variants = { };
    construction.variants = { };
  };
  foundation = map (name: tvp.canonical.${name}) [
    "bzip2_1_0_8"
    "zlib_1_3_2"
    "xz_5_8_4"
    "attr_2_6_0"
    "acl_2_4_0"
    "libxcrypt_4_5_2"
  ];
  contracts = {
    foundationCurrentContext = lib.all (
      q:
      let
        edited = q.edit (spec: spec // { bash = tvp.packages.bash; });
      in
      edited.tests.version.package.drvPath == edited.drvPath
    ) (lib.take 5 foundation);
    foundationNoPublicBuildLibraries = lib.all (q: q.development.libraries == [ ]) foundation;
    foundationRuntimeDirectories = lib.all (
      q:
      let
        edited = q.editRuntime (
          r:
          r
          // {
            libraries = [ ];
            dlopenDirectories = [ "/foundation-runtime-probe" ];
          }
        );
      in
      edited.drvPath != q.drvPath
      &&
        lib.hasInfix "/foundation-runtime-probe"
          (lib.findFirst (step: step.name == "output.rpaths") null edited.buildSteps).run
    ) foundation;
    foundationRejectUnknown = lib.all (
      q: rejects (q.override { undeclaredExecutable = p; }).drvPath
    ) foundation;

    referenceRebinding =
      referenceRebound.drvPath == p.drvPath
      && referenceRebound.specification.base.referencePackages == p.specification.base.referencePackages
      &&
        contextChanged.tests.arithmetic.specification.base.referencePackages
        == p.specification.base.referencePackages
      &&
        map (row: row.path) (lib.filter (row: row.kind == "definition-reference") reboundRegistry)
        == map (
          package: builtins.unsafeDiscardStringContext (toString package)
        ) p.specification.base.referencePackages;
    sourceReferenceRegistration =
      lib.all
        (
          target:
          lib.any (
            row: row.kind == "definition-reference" && row.path == toString target
          ) tvp.dependencyRoots.outputRegistrations
        )
        [
          candidate.toolchain.compiler
          candidate.toolchain.libc
        ];
    splitTestInventory = lib.any (
      row:
      row.dependencyScope or "" == "test-support"
      && row.resolved.drv == candidate.tools.pkgConfig.drvPath
      && lib.elem "step-tool" row.roles
    ) splitInventory.support;
    currentContext =
      contextChanged.tests.arithmetic.specification.base.compiler.drvPath == sentinel.drvPath
      && contextChanged.tests.arithmetic.specification.bash.drvPath == tvp.packages.bash.drvPath
      &&
        contextChanged.tests.arithmetic.specification.coreutils.drvPath
        == tvp.bases.default.components.floor.coreutils.drvPath
      && contextChanged.tests.arithmetic.package.drvPath == contextChanged.drvPath
      && contextChanged.tests.arithmetic.tvp.cc.drvPath == sentinel.drvPath
      && contextBatch.specification.base.compiler.drvPath == sentinel.drvPath
      && contextBatch.testSuite.arithmetic.drvPath == contextChanged.tests.arithmetic.drvPath
      && !(p.tvp ? testContext)
      && !(p.tests ? testContext);
    variantContext = variants.fixture.mpfr_4_2_2.tests.arithmetic.tvp.base == tvp.bases.default.name;

    canonicalOwned = p.tvp.builder == "build-4.2.2.nix" && !(p ? overrideAttrs);
    canonicalSelection = p.__tvpSelection.kind == "exact";
    distinctPilot =
      p.drvPath != tvp.variants.build-steps.mpfr_4_2_2.drvPath
      && p.tvp.base == "source-gnu-candidate"
      && tvp.variants.build-steps.mpfr_4_2_2.tvp.base == tvp.bases.default.name;
    distinctArtifact = p.artifact.drvPath != tvp.variants.build-steps.mpfr_4_2_2.artifact.drvPath;
    archiveHash =
      p.src.outputHash == (api.mkVersions family.constructionRecipe).mpfr_4_2_2.src.outputHash;
    distinctSourceProducer =
      p.src.drvPath != (api.mkVersions family.constructionRecipe).mpfr_4_2_2.src.drvPath;
    legacyPreserved = !(tvp.canonical.mpfr_4_2_1 ? edit) && tvp.canonical.mpfr_4_2_1 ? overrideAttrs;
    exactEdits = tagged "mpfr_4_2_2" p;
    publicExactEdits = tagged "mpfr_4_2_2" tvp.packages.mpfr_4_2_2;
    majorEdits = tagged "mpfr_4" tvp.packages.mpfr_4;
    minorEdits = tagged "mpfr_4_2" tvp.packages.mpfr_4_2;
    floatingIntent =
      tvp.packages.mpfr_4.__tvpSelection.kind == "major"
      && tvp.packages.mpfr_4_2.__tvpSelection.kind == "minor";
    functionCurrentArgs = changed.tvp.deps.gmp.drvPath == gmp.drvPath;
    replay =
      changed.drvPath == ((p.editSteps insert).override {
        inherit gmp;
        doCheck = false;
      }).drvPath;
    editOrder =
      changed.tvp.customization.edits == 1
      && lib.count (s: s.name == "fixture.log") changed.buildSteps == 1;
    testsRebound =
      changed.tests.version.drvPath != p.tests.version.drvPath
      && changed.tests.version.package.outPath == changed.outPath
      && changed.tests.version.compiler.drvPath == changed.compiler.drvPath;
    passthru =
      changed.tests.version.drvPath == changed.passthru.tests.version.drvPath
      && changed.tvp.deps.gmp.drvPath == changed.passthru.tvp.deps.gmp.drvPath;
    testFactory =
      p ? mkTests
      && p.mkTests ? override
      && p.passthru ? mkTests
      && p.out ? mkTests
      && p.out.passthru ? mkTests
      && (builtins.head p.all) ? mkTests;
    testFactoryReplay =
      (changed.mkTests changed).version.drvPath == changed.tests.version.drvPath
      && (changed.out.mkTests changed.out).version.drvPath == changed.tests.version.drvPath
      && (changed.passthru.mkTests changed).version.drvPath == changed.tests.version.drvPath
      &&
        ((changed.mkTests.override { inherit pkgs; }) changed).version.drvPath
        == changed.tests.version.drvPath;
    projections =
      changed.out.tvp.customization == changed.tvp.customization
      && (builtins.head changed.all).tests.version.drvPath == changed.tests.version.drvPath;
    runtimeArtifact = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    runtimeDirectories =
      runtimeDirectories.artifact.drvPath == p.artifact.drvPath
      && runtimeDirectories.drvPath != p.drvPath
      &&
        lib.hasInfix dlopenDirectory
          (lib.findFirst (step: step.name == "output.rpaths") null runtimeDirectories.buildSteps).run
      && runtimeDirectories.drvPath == (p.override { dlopenDirectories = [ dlopenDirectory ]; }).drvPath;
    metadataOnly = (p.edit (s: s // { meta.description = "fixture"; })).drvPath == p.drvPath;
    unknownArgument = rejects (p.override { unknownArgument = true; }).drvPath;
    noOp = (p.override { }).drvPath == p.drvPath;
    publicRequirements = map toString p.development.libraries == [ (toString tvp.packages.gmp_6) ];
    disabledRequirements =
      (p.editSteps (
        steps.replace "output.development" (
          s:
          s
          // {
            enabled = false;
            libraries = throw "disabled export";
          }
        )
      )).development.libraries == [ ];
    variantOwned =
      !(variants.fixture.mpfr_4_2_2 ? overrideAttrs)
      && variants.fixture.mpfr_4_2_2.tvp.variant == "fixture"
      && variants.fixture.mpfr_4_2_2.tvp.canonical == false;
    variantArguments = variants.fixture.mpfr_4_2_2.tvp.deps.gmp.drvPath == gmp.drvPath;
    variantReplay = (variants.fixture.mpfr_4_2_2.editRuntime (r: r)).tvp.variant == "fixture";
    checkedStatus =
      fixture.tvp.status.level == "degraded" && fixture.tests == { kept = fixture.outPath; };
    checkedPatch =
      fixture.tvp.patches == [
        {
          file = "owned-catalogue-recipe.nix";
          reason = "Fixture patch declaration.";
        }
      ];
    excludedAfterEdit = (fixture.edit (s: s)).tests == { kept = fixture.outPath; };
    lazyDisabled = builtins.isString (
      (fixture.override { dependency = throw "disabled dependency"; }).drvPath
    );
    invalidStatus =
      rejects
        (api.mkVersions (
          fixtureArgs
          // {
            versionTable."1" = fixtureArgs.versionTable."1" // {
              status.level = "invalid";
            };
          }
        )).fixture_1.tvp.status;
    missingSource = rejects (api.mkVersions (removeAttrs fixtureArgs [ "source" ])).fixture_1.src;
    actualDependencies =
      lib.attrNames p.tvp.declaredDependencies == [
        "bash"
        "binutils"
        "coreutils"
        "diffutils"
        "findutils"
        "gawk"
        "gmp"
        "gnumake"
        "gnutar"
        "grep"
        "patchelf"
        "python"
        "sed"
        "xz"
      ];
    helperNotDependency = !(p.tvp.declaredDependencies ? tvp) && !(p.tvp.declaredInfrastructure ? tvp);
  };
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned catalogue contracts: ${lib.concatStringsSep ", " failed}";
pkgs.writeText "tvp-owned-catalogue-contracts.json" (builtins.toJSON contracts)
