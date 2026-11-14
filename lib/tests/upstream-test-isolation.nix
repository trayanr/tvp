# Tiny real producers and deliberate failures, using the existing runner/factory.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  inherit (tvp.builder) steps outputs;
  policy = tvp.lib.upstreamTestIsolation;
  reference = tvp.canonical.sqlite_3_0_0.specification;
  inherit (reference) bash coreutils python;
  base = reference.base.override { tools = [ coreutils ]; };
  context = tvp.lib.tests.forBase {
    inherit base coreutils;
    builder = tvp.builder;
  };
  role =
    name: plan:
    tvp.builder {
      recipe = { }: _: {
        pname = "isolation-${name}";
        version = "1";
        src = null;
        inherit
          base
          bash
          coreutils
          plan
          ;
        validationRole = "upstream-${name}";
      };
      args = { };
      dependencyNames = [ ];
      metadata = { };
      selection = { };
      mkTests = _: { };
    };
  provider = role "tiny-provider" [
    {
      name = "fixture.provider";
      run = ''printf provider > "$out"'';
    }
  ];
  marker = builtins.toFile "upstream-tiny-patch" "test-patch\n";
  fixture = tvp.builder {
    recipe =
      { }:
      final: {
        pname = "isolation-fixture";
        version = "1";
        src = null;
        inherit
          base
          bash
          coreutils
          python
          ;
        engine = "engine";
        compilerMarker = "cached-tools-only";
        finalizer = "final";
        testZlib = provider;
        testPatches = [
          {
            file = marker;
            reason = "Tiny fixture input.";
          }
        ];
        testCompileFlags = [ ];
        testFixtureRelinks = false;
        testRestoreScript = builtins.toFile "upstream-tiny-restore" ":\n";
        testPrepareScript = builtins.toFile "upstream-tiny-prepare" ":\n";
        captureScript = ../../pkgs/libraries/sqlite/ordinary/capture.sh;
        classifyScript = ../../pkgs/libraries/sqlite/ordinary/classify.py;
        runnerScript = builtins.toFile "upstream-tiny-runner" "printf '0 errors out of 1 tests\\n'\n";
        upstreamExpected = "SQLite upstream raw result accepted";
        upstreamIsolation = {
          schema = 1;
          protocol = "quick";
          statePath = "nix-support/upstream-build-tree";
          productionSteps = [ "fixture.install" ];
          finalSteps = [
            "output.copy-artifacts"
            "fixture.finalize"
          ];
          testInputFields = [
            "testZlib"
            "testPatches"
            "testCompileFlags"
            "testFixtureRelinks"
            "testPrepareScript"
            "testRestoreScript"
            "captureScript"
            "classifyScript"
            "runnerScript"
            "upstreamExpected"
          ];
        };
        plan = [
          {
            name = "fixture.install";
            upstreamRole = "production";
            run = ''
              mkdir -p "$out/nix-support/upstream-build-tree"
              printf '%s' ${lib.escapeShellArg (final.engine + final.compilerMarker)} > "$out/product"
              printf state > "$out/nix-support/upstream-build-tree/state"
            '';
          }
          (steps.split "fixture.split")
          ((outputs.copyArtifacts { inherit coreutils; }) // { upstreamRole = "finalization"; })
          {
            name = "fixture.finalize";
            upstreamRole = "finalization";
            run = ''
              rm -rf -- "$out/nix-support/upstream-build-tree"
              printf '%s' ${lib.escapeShellArg final.finalizer} > "$out/final"
            '';
          }
        ];
      };
    args = { };
    dependencyNames = [ ];
    metadata = { };
    selection = { };
    testContext = _: context;
    mkTests =
      p:
      let
        s = p.specification;
        construction = role "construction" [
          {
            name = "fixture.construct";
            run = ''
              mkdir "$out"
              cp ${p.artifact}/nix-support/upstream-build-tree/state "$out/state"
              cat ${s.testZlib} ${s.testPrepareScript} ${s.testRestoreScript} ${
                builtins.concatStringsSep " " (map (x: toString x.file) s.testPatches)
              } > "$out/preparation"
              printf '%s' ${lib.escapeShellArg (builtins.concatStringsSep " " s.testCompileFlags)} >> "$out/preparation"
            '';
          }
        ];
        execution = role "execution" [
          {
            name = "fixture.execute";
            run = ''
              cp ${construction}/state state
              ${bash}/bin/bash ${s.captureScript} "$out/raw" ${bash}/bin/bash ${s.runnerScript}
            '';
          }
        ];
        upstream =
          (p.testContext.mkTest {
            package = execution;
            name = "upstream";
            tools = [ python ];
            script = "${python}/bin/python3 -B ${s.classifyScript} ${execution}/raw";
            expected = s.upstreamExpected;
          }).edit
            (
              spec:
              spec
              // {
                validation = {
                  role = "upstream-acceptance";
                  inherit construction execution;
                  production = p.artifact;
                  factory = "owned.mkTest";
                };
              }
            );
      in
      {
        inherit upstream;
      };
  };
  handles =
    p:
    let
      v = p.tests.upstream.specification.validation;
    in
    {
      A = p.artifact;
      F = p;
      T = v.construction;
      R = v.execution;
      U = p.tests.upstream;
    };
  h = handles fixture;
  same = a: b: policy.identity a == policy.identity b;
  preserves = roles: p: builtins.all (n: same h.${n} (handles p).${n}) roles;
  changes = roles: p: builtins.all (n: !(same h.${n} (handles p).${n})) roles;
  edit = fields: fixture.edit (s: s // fields);
  patchEdit = edit {
    testPatches = [
      {
        file = builtins.toFile "changed-patch" "changed";
        reason = "Test-only patch mutation.";
      }
    ];
  };
  fixtureEdit = edit { testPrepareScript = builtins.toFile "changed-fixture" "changed"; };
  flagEdit = edit { testCompileFlags = [ "test-flag" ]; };
  providerEdit = edit { testZlib = builtins.toFile "changed-provider" "provider"; };
  runnerEdit = edit { runnerScript = builtins.toFile "changed-runner" "printf changed"; };
  expectationEdit = edit { upstreamExpected = "changed"; };
  classifierEdit = edit { classifyScript = builtins.toFile "changed-classifier" "changed"; };
  captureEdit = edit { captureScript = builtins.toFile "changed-capture" "changed"; };
  finalEdit = edit { finalizer = "changed"; };
  engineEdit = edit { engine = "changed-engine"; };
  compilerEdit = edit { compilerMarker = "changed-compiler"; };
  failedSuite = edit {
    runnerScript = builtins.toFile "failing-native-suite" "touch reject-upstream\nif test -f reject-upstream; then printf '1 errors out of 1 tests\\n'; exit 1; fi\n";
  };
  failedBatch = context.mkBatch {
    name = "upstream-isolation-intended-failure";
    suite = failedSuite.tests;
  };
  row = p: policy.inspect "fixture" p;
  rejects = p: !(row p).compliant;
  reverse =
    target: field:
    fixture.editSteps (
      steps.replace target (
        old: old // { run = old.run + "\ncat ${fixture.specification.${field}} >/dev/null"; }
      )
    );
  beforeSplit = fixture.editSteps (
    steps.insertBefore "fixture.split" [
      {
        name = "fixture.test-before-split";
        upstreamRole = "upstream-execution";
        run = ":";
      }
    ]
  );
  relabel = fixture.edit (
    s:
    s
    // {
      upstreamIsolation = s.upstreamIsolation // {
        productionSteps = s.upstreamIsolation.productionSteps ++ [ "fixture.test-before-split" ];
      };
      plan = beforeSplit.specification.plan;
    }
  );
  contracts = {
    positive = (row fixture).compliant;
    unauditedNotCompliant = !(row (removeAttrs fixture [ "specification" ])).compliant;
    expectedOnly = preserves [ "A" "F" "T" "R" ] expectationEdit && changes [ "U" ] expectationEdit;
    runnerOnly = preserves [ "A" "F" "T" ] runnerEdit && changes [ "R" "U" ] runnerEdit;
    classifierOnly = preserves [ "A" "F" "T" "R" ] classifierEdit && changes [ "U" ] classifierEdit;
    captureOnly = preserves [ "A" "F" "T" ] captureEdit && changes [ "R" "U" ] captureEdit;
    fixtureOnly = preserves [ "A" "F" ] fixtureEdit && changes [ "T" "R" "U" ] fixtureEdit;
    patchOnly = preserves [ "A" "F" ] patchEdit && changes [ "T" "R" "U" ] patchEdit;
    providerOnly = preserves [ "A" "F" ] providerEdit && changes [ "T" "R" "U" ] providerEdit;
    flagOnly = preserves [ "A" "F" ] flagEdit && changes [ "T" "R" "U" ] flagEdit;
    finalizerOnly = preserves [ "A" "T" "R" "U" ] finalEdit && changes [ "F" ] finalEdit;
    engineInvalidates = changes [ "A" "F" "T" "R" "U" ] engineEdit;
    compilerInvalidates = changes [ "A" "F" "T" "R" "U" ] compilerEdit;
    failingSuiteKeepsProduction = preserves [ "A" "F" "T" ] failedSuite;
    reverseArtifact = rejects (reverse "fixture.install" "testPrepareScript");
    reverseProvider = rejects (reverse "fixture.install" "testZlib");
    reversePatch = rejects (
      fixture.editSteps (
        steps.replace "fixture.install" (
          old:
          old
          // {
            run = old.run + "\ncat ${marker} >/dev/null";
          }
        )
      )
    );
    reverseResult = rejects (
      fixture.edit (
        s:
        s
        // {
          testZlib = h.R;
          plan = steps.replace "fixture.install" (
            old: old // { run = old.run + "\ncat ${h.R}/raw/output >/dev/null"; }
          ) s.plan;
        }
      )
    );
    reverseFinal = rejects (reverse "fixture.finalize" "classifyScript");
    beforeSplit = rejects beforeSplit;
    labelledBeforeSplit = rejects relabel;
    wrongProducer = rejects (fixture // { artifact = finalEdit; });
    strippedContext = rejects (
      fixture
      // {
        artifact = fixture.artifact // {
          outPath = builtins.unsafeDiscardStringContext fixture.artifact.outPath;
        };
      }
    );
    wrongProjection = rejects (fixture // { buildSteps = engineEdit.buildSteps; });
    missingRegistration = rejects (fixture // { tests = { }; });
    wrongRegistration = rejects (fixture // { tests.upstream = h.R; });
    strictRejectsUnaudited =
      !(policy.validate {
        inventory = policy.inventory { canonical.unknown = { }; };
        strict = true;
      }).success;
  };
  bad = builtins.filter (n: !contracts.${n}) (builtins.attrNames contracts);
  check = context.mkTest {
    package = fixture;
    name = "upstream-isolation-contracts";
    tools = [ python ];
    script = ''
      test -f ${fixture.artifact}/nix-support/upstream-build-tree/state
      test ! -e ${fixture}/nix-support/upstream-build-tree
      test "$(cat ${fixture}/product)" = enginecached-tools-only
      test "$(cat ${h.R}/raw/exit)" = 0
      test "$(cat ${h.U})" = 'SQLite upstream raw result accepted'
      ${python}/bin/python3 -B ${../../pkgs/libraries/sqlite/tests/upstream-state-contract.py} \
        ${../../pkgs/libraries/sqlite/ordinary/build-state.py} \
        ${../../pkgs/libraries/sqlite/ordinary/classify.py} \
        ${../../pkgs/libraries/sqlite/ordinary/retained-state.json} \
        ${../../pkgs/libraries/sqlite/tests/upstream-restore.py} >&2
      printf 'Upstream isolation tiny contracts passed' 
    '';
    expected = "Upstream isolation tiny contracts passed";
  };
in
assert bad == [ ] || throw "Upstream isolation tiny contracts: ${lib.concatStringsSep ", " bad}";
check.edit (
  s:
  s
  // {
    passthru = s.passthru // {
      inherit
        contracts
        fixture
        failedSuite
        failedBatch
        ;
    };
  }
)
