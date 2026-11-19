# Evaluation only: inspect real effective plans, producers, output contexts and
# differential lowering. No readFile on derivation outputs and no realization.
{ lib }:
let
  steps = import ./build-steps.nix;
  lower = import ./owned-build.nix { inherit lib; };
  splitPolicy = import ./recipe-splits.nix { inherit lib; };
  plain = builtins.unsafeDiscardStringContext;
  identity = p: {
    drv = plain p.drvPath;
    drvContext = builtins.getContext p.drvPath;
    outputs = map (n: {
      name = n;
      path = plain p.${n}.outPath;
      context = builtins.getContext p.${n}.outPath;
    }) p.outputs;
  };
  same = a: b: lib.isDerivation a && lib.isDerivation b && identity a == identity b;
  context =
    p:
    builtins.getContext (
      builtins.toJSON {
        inherit (p.buildStepRunner) inputs childScripts text;
      }
    );
  # Direct command/script contexts include tools introduced by interpolated run
  # strings, which stageInputs alone misses. Registered role producers cannot
  # occur even when hidden in a child materializer's payload.
  consumes = ctx: p: builtins.hasAttr (plain p.drvPath) ctx;
  fresh = p: same p (lower p.specification);
  sqliteFields = [
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
  marker = builtins.toFile "upstream-isolation-differential" "isolation sentinel\n";
  opensslFields = [
    "doCheck"
    "testPerl"
    "testTools"
    "testPatchTool"
    "testPatches"
    "testCompileFlags"
    "testEnvironment"
    "testPrepareScript"
    "testRestoreScript"
    "captureScript"
    "classifyScript"
    "runnerScript"
    "upstreamExpected"
  ];
  isOpenSSL = p: lib.hasPrefix "openssl-" p.specification.upstreamIsolation.protocol;
  testFields = p: if isOpenSSL p then opensslFields else sqliteFields;
  perturb =
    p:
    p.edit (
      s:
      s
      // {
        testPatches = [
          {
            file = marker;
            reason = "Evaluated test-only differential; never executed.";
          }
        ];
        testCompileFlags = [ "-DTVP_ISOLATION_SENTINEL" ];
        testPrepareScript = marker;
        testRestoreScript = marker;
        captureScript = marker;
        classifyScript = marker;
        runnerScript = marker;
        upstreamExpected = "edited expectation";
      }
      // (
        if isOpenSSL p then
          {
            doCheck = false;
            testPerl = s.coreutils;
            testTools = [ s.coreutils ];
            testPatchTool = s.coreutils;
            testEnvironment = {
              TERM = "edited";
            };
          }
        else
          {
            testZlib = s.coreutils;
            testFixtureRelinks = !(s.testFixtureRelinks or false);
          }
      )
    );
  inspectAudited =
    name: p: split:
    if !(p ? tests.upstream.specification.validation) then
      throw "TVP isolation: missing owned upstream registration"
    else
      let
        s = p.specification;
        policy = s.upstreamIsolation;
        parts = steps.partition s.plan;
        u = p.tests.upstream;
        v = u.specification.validation;
        t = v.construction;
        r = v.execution;
        changed = perturb p;
        producerChecks =
          split.compliant
          && fresh t
          && fresh r
          && fresh u
          && same v.production p.artifact
          && t.specification.validationRole == "upstream-construction"
          && r.specification.validationRole == "upstream-execution"
          && u.tvp.kind == "owned-test"
          && u.specification.passthru.testName == "upstream"
          && u.specification.passthru.package.drvPath == r.drvPath
          && map (x: x.name) u.specification.plan == [ "test.compare" ]
          && v.role == "upstream-acceptance"
          && v.factory == "owned.mkTest"
          &&
            builtins.length (
              lib.unique (
                map (x: plain x.drvPath) [
                  p.artifact
                  p
                  t
                  r
                  u
                ]
              )
            ) == 5;
        forbidden = builtins.attrNames (
          builtins.getContext (
            builtins.toJSON {
              inherit (s)
                testPrepareScript
                testRestoreScript
                captureScript
                classifyScript
                runnerScript
                testPatches
                ;
              testOnlyProviders =
                lib.subtractLists
                  (s.productionSharedProviders or (if isOpenSSL p then s.environment.tools else [ ]))
                  (
                    if isOpenSSL p then
                      [
                        s.testPerl
                        s.testPatchTool
                      ]
                      ++ s.testTools
                    else
                      [ s.testZlib ]
                  );
            }
          )
        );
        productionContexts = map context [
          p.artifact
          p
        ];
        acceptanceContext = context u;
        checks = {
          noTestInputContexts = builtins.all (
            ctx: lib.intersectLists forbidden (builtins.attrNames ctx) == [ ]
          ) productionContexts;
          splitProducers = producerChecks;
          completeActiveAccounting =
            parts.split
            && map (x: x.name) (steps.active parts.first) == policy.productionSteps
            && map (x: x.name) (steps.active parts.second) == policy.finalSteps
            && builtins.all (x: (x.upstreamRole or "missing") == "production") (steps.active parts.first)
            && builtins.all (x: (x.upstreamRole or "missing") == "finalization") (steps.active parts.second);
          schema =
            policy.schema == 1
            && builtins.elem policy.protocol [
              "quick"
              "veryquick"
              "openssl-0.9.7"
              "openssl-1.0.0"
              "openssl-1.1.0"
              "openssl-3.0.0"
              "openssl-4.0.0"
            ]
            && policy.statePath == "nix-support/upstream-build-tree"
            && policy.testInputFields == testFields p;
          testInputIndependence = same p changed && same p.artifact changed.artifact;
          forwardEdges =
            consumes (context t) p.artifact && consumes (context r) t && consumes acceptanceContext r;
          noReverseEdges = builtins.all (
            ctx:
            builtins.all (test: !(consumes ctx test)) [
              t
              r
              u
            ]
          ) productionContexts;
          modernInspector = policy.protocol != "veryquick" || consumes acceptanceContext p;
        };
        failed = builtins.filter (n: !checks.${n}) (builtins.attrNames checks);
      in
      {
        id = name;
        audited = true;
        compliant = failed == [ ];
        disposition = if failed == [ ] then "SOURCE_INSPECTED_RUNTIME_UNQUALIFIED" else "REJECTED";
        inherit failed checks;
        protocol = policy.protocol;
        status = p.tvp.status or { level = "ok"; };
        roles =
          lib.genAttrs
            [
              "A"
              "F"
              "T"
              "R"
              "U"
            ]
            (
              role:
              identity (
                {
                  A = p.artifact;
                  F = p;
                  T = t;
                  R = r;
                  U = u;
                }
                .${role}
              )
            );
      };
  inspectUsingSplit =
    name: p: split:
    if !(p ? specification && p.specification ? upstreamIsolation) then
      {
        id = name;
        audited = false;
        compliant = false;
        disposition = "UNAUDITED";
        status = p.tvp.status or { level = "ok"; };
      }
    else if isOpenSSL p && !p.specification.doCheck then
      {
        id = name;
        audited = false;
        compliant = false;
        disposition = "DISABLED_UPSTREAM_WORKLOAD";
        status = p.tvp.status or { level = "ok"; };
      }
    else
      let
        row = inspectAudited name p split;
        attempt = builtins.tryEval (builtins.deepSeq row row);
      in
      if attempt.success then
        attempt.value
      else
        {
          id = name;
          audited = true;
          compliant = false;
          disposition = "EVALUATION_FAILED";
          failed = [ "evaluated-contract" ];
        };
  members =
    {
      canonical,
      variants ? { },
    }:
    let
      inScope =
        scope:
        lib.mapAttrsToList (
          name: package: {
            id = "${scope}/${name}";
            inherit package;
          }
        );
    in
    inScope "canonical" canonical
    ++ lib.concatLists (lib.mapAttrsToList (profile: inScope "variants.${profile}") variants);
  inventoryFromRows = rows: {
    schema = "tvp.upstream-isolation.inventory/v1";
    inherit rows;
    qualification = "source-only; no canonical runtime qualification";
    outsideOrdinaryScope = "Retained/bootstrap/private/base/composition recipes require separate inspection; UNAUDITED.";
  };
in
rec {
  inherit identity;
  inspect =
    name: p:
    inspectUsingSplit name p (builtins.head (splitPolicy.inventory { canonical.${name} = p; }).rows);

  inventory = args: inventoryFromRows (map ({ id, package }: inspect id package) (members args));

  # Both audits consume the same packages. Pair rows lazily, since reading a
  # split row's ID forces its audit even for packages without an isolation check.
  inventories =
    args:
    let
      recipeSplits = splitPolicy.inventory args;
      packages = members args;
      rows = lib.zipListsWith (
        { id, package }:
        split:
        inspectUsingSplit id package (
          if split.id == id then split else throw "TVP isolation: mismatched recipe-split row for ${id}"
        )
      ) packages recipeSplits.rows;
    in
    {
      inherit recipeSplits;
      upstreamIsolation =
        assert builtins.length packages == builtins.length recipeSplits.rows;
        inventoryFromRows rows;
    };
  validate =
    {
      inventory,
      strict ? false,
    }:
    let
      audited = builtins.filter (r: r.audited) inventory.rows;
      unaudited = builtins.filter (r: !r.audited) inventory.rows;
      rejected = builtins.filter (r: r.audited && !r.compliant) inventory.rows;
    in
    {
      inherit strict;
      success = rejected == [ ] && (!strict || unaudited == [ ]);
      allIsolated = unaudited == [ ] && rejected == [ ];
      counts = {
        total = builtins.length inventory.rows;
        inspected = builtins.length audited;
        unaudited = builtins.length unaudited;
        rejected = builtins.length rejected;
        upstreamIsolationDebt = builtins.length unaudited + builtins.length rejected;
      };
      inherit (inventory) rows;
    };
  enforce =
    report:
    if report.success then
      report
    else
      throw "TVP upstream-test isolation: rejected scope or strict UNAUDITED debt";
}
