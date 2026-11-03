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
  contracts = {
    canonicalOwned = p.tvp.builder == "build-4.2.2.nix" && !(p ? overrideAttrs);
    canonicalSelection = p.__tvpSelection.kind == "exact";
    samePilot = p.drvPath == tvp.variants.build-steps.mpfr_4_2_2.drvPath;
    sameArtifact = p.artifact.drvPath == tvp.variants.build-steps.mpfr_4_2_2.artifact.drvPath;
    sameSource = p.src.drvPath == (api.mkVersions family.constructionRecipe).mpfr_4_2_2.src.drvPath;
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
      && lib.any (v: v.outPath == changed.outPath) changed.tests.version.nativeBuildInputs;
    passthru =
      changed.tests.version.drvPath == changed.passthru.tests.version.drvPath
      && changed.tvp.deps.gmp.drvPath == changed.passthru.tvp.deps.gmp.drvPath;
    testFactory = p.passthru ? mkTests && p.out.passthru ? mkTests;
    projections =
      changed.out.tvp.customization == changed.tvp.customization
      && (builtins.head changed.all).tests.version.drvPath == changed.tests.version.drvPath;
    runtimeArtifact = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
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
        "gmp"
        "gnumake"
        "gnutar"
        "patchelf"
        "python"
        "xz"
      ];
    helperNotDependency = !(p.tvp.declaredDependencies ? tvp) && !(p.tvp.declaredInfrastructure ? tvp);
  };
  failed = lib.filter (n: !contracts.${n}) (lib.attrNames contracts);
in
assert failed == [ ] || throw "Owned catalogue contracts: ${lib.concatStringsSep ", " failed}";
pkgs.writeText "tvp-owned-catalogue-contracts.json" (builtins.toJSON contracts)
