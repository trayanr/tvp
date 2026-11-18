# Evaluation only: use real alias generation with unbuildable model releases.
{ lib }:
let
  api = import ../default.nix { inherit lib; };
  tests = api.tests;
  leaf = name: rec {
    drvPath = "/model/${name}.drv";
    outPath = "/model/${name}";
    outputs = [
      "out"
      "validation"
    ];
    out.outPath = outPath;
    validation.outPath = "${outPath}-validation";
  };
  release =
    version:
    (leaf "probe-${version}")
    // {
      pname = "probe";
      inherit version;
      tests.value = leaf "probe-${version}-test";
    };
  canonical = {
    probe_2_0 = (release "2.0") // {
      tests = throw "historical tests forced";
      outPath = throw "historical output forced";
      drvPath = throw "historical producer forced";
    };
    probe_10_0 = (release "10.0") // {
      tvp.status.level = "degraded";
    };
    probe_11_0 = (release "11.0") // {
      tvp.status = {
        level = "broken";
        reason = "fixture unsupported";
        needs = "repair";
      };
      tests = throw "broken tests forced";
      outPath = throw "broken output forced";
    };
  };
  packages = api.packages.mkAliases {
    pname = "probe";
    inherit canonical;
    versionTable = {
      "2.0" = { };
      "10.0" = { };
      "11.0".status.level = "broken";
    };
  };
  batch = (leaf "own-context-batch") // {
    testSuite = canonical.probe_10_0.tests;
  };
  batches = {
    probe_10_0 = batch;
    probe_2_0 = throw "historical batch forced";
    all = throw "full aggregate forced";
    variant-profile-probe = throw "variant forced";
    bootstrap-probe = throw "bootstrap forced";
    check-package-runtime-ownership = throw "full ownership forced";
  };
  inputs = {
    inherit canonical packages batches;
  };
  selected = tests.selectLatest inputs;
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  alterAlias = attrs: packages // { probe = packages.probe // attrs; };
  brokenOnly = tests.selectLatest {
    canonical = {
      inherit (canonical) probe_11_0;
    };
    packages = { };
    batches = { };
  };
  # Real Nix primitive derivations may omit `outputs`; default out is implicit.
  # Exercise the full-plan serializer without building either fixture.
  primitive = builtins.derivation {
    name = "plan-implicit-output";
    system = "x86_64-linux";
    builder = "/not-built";
  };
  named = builtins.derivation {
    name = "plan-named-outputs";
    system = "x86_64-linux";
    builder = "/not-built";
    outputs = [
      "out"
      "validation"
    ];
  };
  planFor =
    smoke: check:
    tests.compatibility.planManifest {
      inherit smoke;
      pkgs = {
        stdenv.hostPlatform.system = "x86_64-linux";
        linkFarm = _: _: {
          overrideAttrs = _: { drvPath = "/model/aggregate.drv"; };
        };
      };
      batches = { };
      checks.fixture = check;
      canonical = { };
      source = ./latest.nix;
    };
  makePlan = check: builtins.fromJSON (plain (builtins.toJSON (planFor false check)));
  plan = makePlan (
    primitive
    // {
      testSuite = {
        implicit = primitive;
        selected = named.validation;
      };
    }
  );
  planJob = builtins.head plan.jobs;
  plain = builtins.unsafeDiscardStringContext;
  # Label extraction must use only package metadata and exact drv identities.
  displayPackage =
    name: attrs:
    (leaf name)
    // {
      outPath = throw "display metadata demanded a package output";
      outputs = throw "display metadata enumerated package outputs";
    }
    // attrs;
  engine =
    version:
    displayPackage "php-${version}" {
      pname = "php";
      inherit version;
      artifact = displayPackage "php-${version}-artifacts" { };
    };
  extension =
    version:
    displayPackage "php-${version}-redis" {
      pname = "php-redis";
      version = "6.0.2";
      passthru = {
        php = engine version;
        extensionName = "redis";
      };
      artifact = displayPackage "php-${version}-redis-artifacts" { };
    };
  runtime = displayPackage "php-8.2.30-runtime" {
    pname = "php-with-extensions";
    version = "8.2.30";
    unwrapped = engine "8.2.30";
    enabledExtensions = [ (extension "8.2.30") ];
    artifact = displayPackage "php-8.2.30-runtime-artifacts" { };
  };
  displayPlan = planFor false (
    (leaf "display-batch")
    // {
      testSuite = {
        redis82 = (leaf "redis82-load") // {
          package = extension "8.2.30";
          testName = "load";
          buildSteps = [ { tools = [ runtime ]; } ];
        };
        redis83 = (leaf "redis83-load") // {
          passthru = {
            package = extension "8.3.30";
            testName = "load";
          };
        };
      };
    }
  );
  labels = displayPlan.displayLabels;
  stageFixture = primitive // {
    package = primitive // {
      artifact = named;
    };
  };
  stagePlan = smoke: fixture: (builtins.head (planFor smoke fixture).jobs).stages;
  smokeStages = lib.sort (a: b: a.phase > b.phase) (stagePlan true stageFixture);
  fullArtifact = lib.findFirst (stage: stage.phase == "compile") null (stagePlan false stageFixture);
  selectedOutputStage = builtins.head (
    stagePlan false (primitive // { package = named.validation; })
  );
  checks = {
    displayExtensionStages =
      labels."/model/php-8.2.30-redis-artifacts.drv" == "PHP 8.2.30 / Redis 6.0.2: compiling extension"
      && labels."/model/php-8.2.30-redis.drv" == "PHP 8.2.30 / Redis 6.0.2: finalizing extension"
      && labels."/model/php-8.3.30-redis.drv" == "PHP 8.3.30 / Redis 6.0.2: finalizing extension";
    displayEngineStages =
      labels."/model/php-8.2.30-artifacts.drv" == "PHP 8.2.30: compiling engine"
      && labels."/model/php-8.2.30.drv" == "PHP 8.2.30: finalizing engine";
    displayTest = labels."/model/redis82-load.drv" == "PHP 8.2.30 / Redis 6.0.2: test load";
    displayRuntime =
      labels."/model/php-8.2.30-runtime-artifacts.drv" == "PHP 8.2.30 / Redis 6.0.2: composing runtime"
      && labels."/model/php-8.2.30-runtime.drv" == "PHP 8.2.30 / Redis 6.0.2: finalizing runtime";
    displayCollecting =
      labels."/model/display-batch.drv" == "check-fixture: collecting results"
      && labels."/model/aggregate.drv" == "All tests: collecting results";
    displayWithoutOutputs = builtins.deepSeq labels true;
    displayContextFree =
      !(builtins.hasContext (builtins.toJSON (planFor false primitive).displayLabels));
    stageContextFree = !(builtins.hasContext (builtins.toJSON smokeStages));
    stageRecords =
      smokeStages == [
        {
          drv = plain primitive.drvPath;
          outputs = [ (plain primitive.outPath) ];
          phase = "finalize";
          tests = [ (plain primitive.drvPath) ];
          coveredBy = [ ];
        }
        {
          drv = plain named.drvPath;
          outputs = [
            (plain named.outPath)
            (plain named.validation.outPath)
          ];
          phase = "compile";
          tests = [ (plain primitive.drvPath) ];
          coveredBy = [ [ (plain primitive.outPath) ] ];
        }
      ];
    fullDoesNotAssumeArtifactPruning = fullArtifact.coveredBy == [ ];
    stageUsesOnlySelectedFinalOutput =
      selectedOutputStage.outputs == [ (plain named.validation.outPath) ];
    stageGroupsIdenticalUses =
      let
        grouped = stagePlan false (
          primitive
          // {
            testSuite = {
              a = stageFixture;
              b = named // {
                inherit (stageFixture) package;
              };
            };
          }
        );
      in
      builtins.length grouped == 2
      && builtins.all (
        stage:
        stage.tests == [
          (plain primitive.drvPath)
          (plain named.drvPath)
        ]
      ) grouped;
    displayLegacyFallback = plan.displayLabels.${plain named.drvPath} == "check-fixture: test selected";
    fullPlanImplicitOutput = planJob.outputs == [ (plain primitive.outPath) ];
    fullPlanImplicitTest = (builtins.head planJob.tests).outputs == [ (plain primitive.outPath) ];
    fullPlanNamedTest =
      (builtins.elemAt planJob.tests 1).outputs == [
        (plain named.validation.outPath)
        (plain named.outPath)
      ];
    semanticLatest = selected.metadata.families.probe.version == "10.0";
    aliasPolicy = selected.metadata.families.probe.selector == packages.probe.__tvpSelection;
    exactBatch = selected.batches.probe_10_0 == batch;
    allDeclaredOutputs =
      builtins.sort builtins.lessThan selected.requiredOutputs == [
        "/model/own-context-batch"
        "/model/own-context-batch-validation"
        "/model/probe-10.0"
        "/model/probe-10.0-test"
        "/model/probe-10.0-test-validation"
        "/model/probe-10.0-validation"
      ];
    ordinaryOnly = builtins.attrNames selected.batches == [ "probe_10_0" ];
    deterministic = selected.metadata == (tests.selectLatest inputs).metadata;
    contextFree = !(builtins.hasContext (builtins.toJSON selected.metadata));
    missingAlias = rejects (tests.selectLatest (inputs // { packages = { }; }));
    staleAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          canonical = canonical // {
            probe_2_0 = release "2.0";
          };
          packages = packages // {
            probe = (release "2.0") // {
              __tvpSelection = packages.probe.__tvpSelection // {
                canonical = "probe_2_0";
                version = "2.0";
              };
            };
          };
        }
      )
    );
    brokenAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              canonical = "probe_11_0";
            };
          };
        }
      )
    );
    foreignAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              namespace = "variants.profile";
            };
          };
        }
      )
    );
    mismatchedAlias = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias { outPath = "/model/different-output"; };
        }
      )
    );
    mismatchedAliasMetadata = rejects (
      tests.selectLatest (
        inputs
        // {
          packages = alterAlias {
            __tvpSelection = packages.probe.__tvpSelection // {
              version = "wrong";
            };
          };
        }
      )
    );
    missingBatch = rejects (tests.selectLatest (inputs // { batches = { }; }));
    mismatchedBatch = rejects (
      tests.selectLatest (
        inputs
        // {
          batches.probe_10_0 = batch // {
            testSuite.value = leaf "different-test";
          };
        }
      )
    );
    mismatchedNamedOutput = rejects (
      tests.selectLatest (
        inputs
        // {
          batches.probe_10_0 = batch // {
            testSuite.value = canonical.probe_10_0.tests.value // {
              outPath = canonical.probe_10_0.tests.value.validation.outPath;
            };
          };
        }
      )
    );
    missingTests = rejects (
      tests.selectLatest (
        inputs
        // {
          canonical = canonical // {
            probe_10_0 = canonical.probe_10_0 // {
              tests = { };
            };
          };
        }
      )
    );
    allBrokenDiagnostic =
      brokenOnly.batches == { }
      && (builtins.head brokenOnly.metadata.skipped).family == "probe"
      &&
        (builtins.head (builtins.head brokenOnly.metadata.skipped).releases).reason
        == "fixture unsupported";
    empty =
      (tests.selectLatest {
        canonical = { };
        packages = { };
        batches = { };
      }).metadata == {
        schema = "tvp.latest-tests/v1";
        families = { };
        skipped = [ ];
      };
    # Reuse the existing collision contract at the job composition boundary.
    duplicateJobs = rejects (
      tests.compatibility.suiteJobs {
        batches.check-probe = batch;
        checks.probe = batch;
      }
    );
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
if failed != [ ] then
  throw "TVP latest test contracts failed: ${lib.concatStringsSep ", " failed}"
else
  checks
