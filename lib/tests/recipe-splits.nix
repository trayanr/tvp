# Tiny real owned-constructor fixtures; no source app, compiler or catalogue build.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps outputs;
  policy = tvp.lib.recipeSplits;
  inherit (tvp.packages) bash coreutils;
  base = tvp.canonical.mpfr_4_2_2.specification.base.override { tools = [ coreutils ]; };
  fixture = tvp.builder {
    recipe =
      {
        base,
        bash,
        coreutils,
      }:
      final: {
        pname = "recipe-split-fixture";
        version = "1";
        src = null;
        inherit base bash coreutils;
        runtime.message = "first";
        plan = [
          {
            name = "fixture.install";
            run = ''mkdir -p "$out"; printf build > "$out/build"'';
          }
          (steps.split "fixture.finalize")
          (outputs.copyArtifacts { inherit coreutils; })
          {
            name = "fixture.message";
            run = ''printf '%s' ${lib.escapeShellArg final.runtime.message} > "$out/message"'';
          }
        ];
      };
    args = {
      inherit base bash coreutils;
    };
    dependencyNames = [ ];
    metadata = { };
    selection.kind = "fixture";
    mkTests = _: { };
  };
  finalEdit = fixture.editRuntime (_: {
    message = "second";
  });
  buildEdit = fixture.editSteps (
    steps.replace "fixture.install" (
      s:
      s
      // {
        run = ''mkdir -p "$out"; printf changed > "$out/build"'';
      }
    )
  );
  leaking = fixture.editSteps (
    steps.append [
      {
        name = "fixture.leak";
        run = ''printf '%s' "$TVP_ARTIFACT_ROOT" > "$out/leak"'';
      }
    ]
  );
  row = p: builtins.head (policy.inventory { canonical.fixture_1 = p; }).rows;
  failure = p: (row p).failure;
  withPlan =
    plan:
    fixture
    // {
      specification = fixture.specification // {
        inherit plan;
      };
      buildSteps = plan;
    };
  command = name: {
    inherit name;
    run = ":";
  };
  a = command "fixture.a";
  b = command "fixture.b";
  split = steps.split "fixture.split";
  legacy = removeAttrs fixture [
    "specification"
    "buildSteps"
    "stageInputs"
    "artifact"
    "buildStepRunner"
  ];
  unsplit = fixture.editSteps (steps.delete "fixture.finalize");
  inventory = p: policy.inventory { canonical.fixture_1 = p; };
  exception = {
    id = "canonical/fixture_1";
    constructor = "legacy";
    failure = "legacy-no-plan";
    reason = "Port this retained compatibility procedure to the owned constructor with installed-artifact finalization.";
  };
  validate =
    p: baseline:
    policy.validate {
      inventory = inventory p;
      inherit baseline;
    };
  rejects = value: !(builtins.tryEval (builtins.deepSeq value true)).success;
  malformed = baseline: !(validate legacy baseline).success;
  releases = {
    "1.0" = { };
    "1.0.1" = { };
  };
  canonical = {
    fixture_1_0 = fixture;
    fixture_1_0_1 = fixture // {
      tvp.status = {
        level = "broken";
        reason = "Synthetic broken release remains inventoried.";
        needs = "Fixture only.";
      };
    };
  };
  aliases = tvp.lib.packages.mkAliases {
    pname = "fixture";
    versionTable = releases;
    inherit canonical;
  };
  accounting = policy.validate {
    inventory = policy.inventory {
      inherit canonical;
      variants.public.fixture_1_0 = fixture;
    };
  };
  contracts = {
    valid = (row fixture).compliant;
    activeStages =
      (row fixture).partition.activeBefore == 1 && (row fixture).partition.activeAfter == 2;
    finalOnlyStableArtifact =
      finalEdit.artifact.drvPath == fixture.artifact.drvPath && finalEdit.drvPath != fixture.drvPath;
    buildEditChangesArtifact =
      buildEdit.artifact.drvPath != fixture.artifact.drvPath && buildEdit.drvPath != fixture.drvPath;
    noSplit = failure unsplit == "owned-unsplit";
    newUnsplitFails = !(validate unsplit [ ]).success;
    rejectedConstructorDiagnostic =
      failure (fixture.editSteps (steps.append [ (steps.split "fixture.other") ])) == "evaluation-failed";
    invalidMultiple =
      failure (withPlan [
        a
        split
        b
        (steps.split "fixture.other")
      ]) == "invalid-plan";
    invalidEmptyBefore =
      failure (withPlan [
        split
        b
      ]) == "invalid-plan";
    invalidEmptyAfter =
      failure (withPlan [
        a
        split
      ]) == "invalid-plan";
    invalidDisabledStage =
      failure (withPlan [
        (a // { enabled = false; })
        split
        b
      ]) == "invalid-plan";
    invalidActiveCommand =
      failure (withPlan [
        (a // { run = 42; })
        split
        b
      ]) == "invalid-plan";
    emptyCommandFails =
      failure (withPlan [
        (a // { run = ""; })
        split
        b
      ]) == "invalid-plan";
    invalidSplitShape =
      failure (withPlan [
        a
        (split // { enabled = false; })
        b
      ]) == "invalid-plan";
    invalidNames =
      failure (withPlan [
        a
        split
        (b // { name = a.name; })
      ]) == "invalid-plan";
    missingPlan = failure (removeAttrs fixture [ "specification" ]) == "missing-owned-plan";
    missingArtifact = failure (removeAttrs fixture [ "artifact" ]) == "missing-artifact";
    forgedArtifact =
      failure (
        fixture
        // {
          artifact = {
            type = "derivation";
            drvPath = builtins.unsafeDiscardStringContext fixture.artifact.drvPath;
            outPath = builtins.unsafeDiscardStringContext fixture.artifact.outPath;
          };
        }
      ) == "invalid-artifact-producer";
    unrelatedArtifact =
      failure (fixture // { artifact = buildEdit.artifact; }) == "invalid-artifact-producer";
    finalEqualsArtifact = failure (fixture // { artifact = fixture; }) == "invalid-artifact-producer";
    exposedPlanMismatch =
      failure (fixture // { buildSteps = buildEdit.buildSteps; }) == "invalid-artifact-producer";
    unsupportedNamedOutputs =
      failure (
        withPlan fixture.buildSteps
        // {
          specification = fixture.specification // {
            outputs = [
              "out"
              "dev"
            ];
          };
        }
      ) == "unsupported-named-outputs";
    backendStillRejectsSplitNamedOutputs =
      rejects
        (fixture.edit (
          s:
          s
          // {
            outputs = [
              "out"
              "dev"
            ];
          }
        )).drvPath;
    existingDebtVisible =
      (validate legacy [ exception ]).status == "PASS_WITH_EXISTING_DEBT"
      && !(validate legacy [ exception ]).allSplit
      && (validate legacy [ exception ]).counts.remainingDebt == 1;
    strictDebtFails =
      !(policy.validate {
        inventory = inventory legacy;
        baseline = [ exception ];
        strict = true;
      }).success;
    strictWithoutBaselineFails = rejects (
      policy.enforce (
        policy.validate {
          inventory = inventory unsplit;
          strict = true;
        }
      )
    );
    allSplit = accounting.status == "ALL_SPLIT" && accounting.counts.compliant == 3;
    aliasShadow = aliases.fixture_1_0.tvp.status.level == "broken";
    exactCanonicalAndVariants =
      accounting.counts.total == 3
      && accounting.counts.canonical == 2
      && accounting.counts.publicVariants == 1
      && accounting.counts.broken == 1
      &&
        map (r: r.id) accounting.rows == [
          "canonical/fixture_1_0"
          "canonical/fixture_1_0_1"
          "variants.public/fixture_1_0"
        ];
    staleFails = !(validate fixture [ exception ]).success;
    newLegacyFails = !(validate legacy [ ]).success;
    classificationDriftFails = !(validate unsplit [ exception ]).success;
    nativeConstructorFails =
      failure (removeAttrs fixture [ "stageInputs" ]) == "native-plan-constructor";
    emptyJSON = policy.baselineFromJSON "[]\n" == [ ];
    canonicalJSON =
      policy.baselineFromJSON ("[\n  " + builtins.toJSON exception + "\n]\n") == [ exception ];
    duplicateJSONMemberFails = rejects (
      policy.baselineFromJSON (
        "[\n  {\"id\":\"canonical/fixture_1\",\"id\":\"canonical/fixture_1\"}\n]\n"
      )
    );
    nonListJSONFails = rejects (policy.baselineFromJSON "{}\n");
    malformedList = malformed { };
    malformedNull = malformed null;
    malformedEntry = malformed [ null ];
    duplicateFails = malformed [
      exception
      exception
    ];
    wildcardFails = malformed [ (exception // { id = "canonical/*"; }) ];
    wrongNamespaceFails = malformed [ (exception // { id = "bootstrap/fixture_1"; }) ];
    emptyReasonFails = malformed [ (exception // { reason = ""; }) ];
    whitespaceReasonFails = malformed [ (exception // { reason = " \n\t"; }) ];
    nullReasonFails = malformed [ (exception // { reason = null; }) ];
    missingReasonFails = malformed [ (removeAttrs exception [ "reason" ]) ];
    unknownFieldFails = malformed [ (exception // { extra = true; }) ];
    contradictoryClassFails = malformed [ (exception // { failure = "owned-unsplit"; }) ];
    unknownClassFails = malformed [ (exception // { constructor = "anything"; }) ];
    unknownFailureFails = malformed [ (exception // { failure = "anything"; }) ];
    reportContextFree = !(builtins.hasContext (builtins.toJSON accounting));
  };
  failed = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
  check = builtins.derivation {
    name = "tvp-recipe-split-contracts";
    outputs = [ "out" ];
    system = base.platform.system;
    builder = "${bash}/bin/bash";
    args = [
      "-euc"
      ''
        export PATH=${coreutils}/bin
        test "$(cat ${fixture}/build)" = build
        test "$(cat ${fixture}/message)" = first
        test "$(cat ${finalEdit}/message)" = second
        test "$(cat ${buildEdit}/build)" = changed
        printf '%s\n' '${builtins.toJSON contracts}' > "$out"
      ''
    ];
  };
in
assert failed == [ ] || throw "Recipe split contracts: ${lib.concatStringsSep ", " failed}";
check
// {
  passthru = {
    # JSON syntax errors are evaluator errors, outside tryEval's throw/assert
    # handling. Exercise this negative fixture with a separate nix eval.
    malformedJSON = policy.baselineFromJSON "[";
    inherit
      contracts
      fixture
      finalEdit
      buildEdit
      leaking
      ;
  };
}
