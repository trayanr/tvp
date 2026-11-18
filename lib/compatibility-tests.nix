# Internal Nixpkgs-backed tests and aggregation for remaining compatibility callers.
{ lib }:
rec {
  # Keep the test builder on the selected base as well as the test compiler.
  # Overriding pkgs.stdenv alone does not change pkgs.runCommand's closure.
  withBase =
    { pkgs, base }:
    pkgs
    // {
      inherit (base) stdenv;
      glibc = base.stdenv.cc.libc;
      runCommand =
        name: env:
        pkgs.runCommandWith {
          inherit name;
          stdenv = base.stdenv;
          derivationArgs = env;
        };
    };

  # `expected` is mandatory: `cmd > $out` passes for anything that exits cleanly
  # with no output.
  mkTest =
    {
      pkgs,
      package,
      name,
      script,
      expected,
      extraInputs ? [ ],
    }:
    pkgs.runCommand "${package.pname}-${package.version}-${name}"
      {
        nativeBuildInputs = [ package ] ++ extraInputs;
        passthru = {
          inherit package;
          testName = name;
        };
        meta.description = "TVP ${name} test for ${package.pname} ${package.version}";
      }
      ''
        set -eo pipefail

        actual=$(
        ${script}
        )
        expected=${lib.escapeShellArg expected}

        if [ "$actual" != "$expected" ]; then
          echo "FAIL  ${package.pname} ${package.version} / ${name}" >&2
          echo "  expected: $expected" >&2
          echo "  actual:   $actual" >&2
          exit 1
        fi

        printf '%s\n' "$actual" > "$out"
      '';

  mkSuite =
    {
      pkgs,
      package,
      tests,
    }:
    lib.mapAttrs (name: spec: mkTest ({ inherit pkgs package name; } // spec)) tests;

  # One buildable handle per package, so CI never enumerates tests itself.
  mkBatch =
    {
      pkgs,
      name,
      suite,
    }:
    (pkgs.linkFarm "tvp-tests-${name}" (
      lib.mapAttrsToList (name: drv: {
        inherit name;
        path = drv;
      }) suite
    )).overrideAttrs
      (old: {
        passthru = (old.passthru or { }) // {
          testSuite = suite;
        };
      });

  suiteJobs =
    { batches, checks }:
    let
      checkJobs = lib.mapAttrs' (name: drv: lib.nameValuePair "check-${name}" drv) checks;
      duplicates = lib.intersectLists (lib.attrNames batches) (lib.attrNames checkJobs);
    in
    if duplicates != [ ] then
      throw "TVP: full-suite job names collide: ${lib.concatStringsSep ", " duplicates}"
    else
      batches // checkJobs;

  mkAll =
    {
      pkgs,
      batches,
      checks,
    }:
    mkBatch {
      inherit pkgs;
      name = "all";
      suite = suiteJobs { inherit batches checks; };
    };

  # Keep manifest construction separate from materialization so evaluation
  # contracts can inspect it without reading generated files in a fresh store.
  planManifest =
    {
      pkgs,
      batches,
      checks,
      canonical,
      source,
      revision ? null,
      smoke ? false,
    }:
    let
      jobs = suiteJobs { inherit batches checks; };
      aggregate = mkAll { inherit pkgs batches checks; };
      broken = lib.filterAttrs (_: p: (p.tvp.status.level or "ok") == "broken") canonical;
      # Display metadata comes from the selected test objects, without walking
      # their native dependency graph or demanding any package output.
      plain = builtins.unsafeDiscardStringContext;
      metadata = value: name: value.${name} or ((value.passthru or { }).${name} or null);
      title = name: value: name + lib.optionalString (value ? version) " ${value.version}";
      friendlyName =
        name:
        if name == "php" then
          "PHP"
        else if name == "redis" then
          "Redis"
        else
          name;
      extensionTitle = package: title (friendlyName (metadata package "extensionName")) package;
      subject =
        fallback: package:
        if package == null then
          fallback
        else if metadata package "php" != null && metadata package "extensionName" != null then
          "${title "PHP" (metadata package "php")} / ${extensionTitle package}"
        else if
          (package.pname or null) == "php-with-extensions" && metadata package "unwrapped" != null
        then
          title "PHP" (metadata package "unwrapped")
          + lib.optionalString (
            metadata package "enabledExtensions" != null && metadata package "enabledExtensions" != [ ]
          ) (" / " + lib.concatMapStringsSep ", " extensionTitle (metadata package "enabledExtensions"))
        else if package ? pname then
          title (friendlyName package.pname) package
        else
          fallback;
      label =
        drv: text:
        lib.optional (drv != null && drv ? drvPath) (lib.nameValuePair (plain drv.drvPath) (plain text));
      packageLabels =
        fallback: package:
        if package == null then
          [ ]
        else
          let
            name = subject fallback package;
            artifact = metadata package "artifact";
            kind =
              if metadata package "extensionName" != null then
                " extension"
              else if (package.pname or null) == "php" then
                " engine"
              else if (package.pname or null) == "php-with-extensions" then
                " runtime"
              else
                "";
            compiling = if kind == " runtime" then "composing runtime" else "compiling${kind}";
            engine = if kind == " runtime" then metadata package "unwrapped" else metadata package "php";
          in
          label package "${name}: ${if artifact == null then compiling else "finalizing${kind}"}"
          ++ label artifact "${name}: ${compiling}"
          ++ lib.optionals (engine != null) (packageLabels "PHP" engine);
      testSubject = fallback: test: subject fallback (metadata test "package");
      testInputs =
        test:
        (test.specification.tools or [ ])
        ++ lib.concatMap (step: (step.tools or [ ]) ++ (step.libraries or [ ])) (
          builtins.filter (step: step.enabled or true) (test.buildSteps or [ ])
        );
      testLabels =
        fallback: name: test:
        let
          testName = metadata test "testName";
        in
        label test "${testSubject fallback test}: test ${if testName == null then name else testName}"
        ++ packageLabels fallback (metadata test "package")
        ++ lib.concatMap (packageLabels fallback) (
          builtins.filter (tool: (tool.pname or null) == "php-with-extensions") (testInputs test)
        );
      jobLabels =
        name: drv:
        let
          suite = drv.testSuite or { };
          subjects = lib.unique (map (testSubject name) (builtins.attrValues suite));
          suiteSubject = if builtins.length subjects == 1 then builtins.head subjects else name;
        in
        if suite == { } then
          testLabels name name drv
        else
          lib.concatLists (lib.mapAttrsToList (testLabels suiteSubject) suite)
          ++ label drv "${suiteSubject}: collecting results";
      outputPaths =
        drv:
        let
          selected = builtins.unsafeDiscardStringContext drv.outPath;
          # builtins.derivation omits `outputs` when using its implicit `out`.
          # An explicit list still requires every declared sibling to exist.
          declared = map (output: builtins.unsafeDiscardStringContext drv.${output}.outPath) (
            drv.outputs or [ "out" ]
          );
        in
        [ selected ] ++ builtins.filter (output: output != selected) declared;
      # A frozen plan carries exact identities for the package stages it can
      # identify. These are observation targets, never additional build inputs.
      packageStages =
        test: artifactConsumed: package:
        if package == null || !(builtins.isAttrs package && package ? drvPath) then
          [ ]
        else
          let
            artifact = metadata package "artifact";
            runtime = (package.pname or null) == "php-with-extensions";
            engine = if runtime then metadata package "unwrapped" else metadata package "php";
            modules = if runtime then (metadata package "enabledExtensions") else null;
            # Both the compatibility wrappers and source-owned full drivers
            # expose the executable compiler they are constructed from.
            compiler =
              if package ? bintools && package ? libc && package ? runtimeDirectories then
                package.tvp.declaredDependencies.compiler or (metadata package "cc")
              else
                null;
            selectedOutput = [ (plain package.outPath) ];
            makeStage = phase: producer: outputs: coveredBy: {
              inherit phase outputs coveredBy;
              drv = plain producer.drvPath;
              tests = [ (plain test.drvPath) ];
            };
          in
          [
            (makeStage (
              if runtime || compiler != null then
                "prepare"
              else if artifact == null then
                "build"
              else
                "finalize"
            ) package selectedOutput [ ])
          ]
          ++ lib.optional (artifact != null) (
            makeStage (if runtime then "prepare" else "compile") artifact (outputPaths artifact) (
              lib.optional (smoke && !artifactConsumed) selectedOutput
            )
          )
          ++ packageStages test false engine
          ++ packageStages test true compiler
          ++ lib.concatMap (packageStages test false) (if modules == null then [ ] else modules);
      testStages =
        test:
        lib.unique (
          packageStages test false (metadata test "package")
          ++ lib.concatMap (packageStages test false) (
            builtins.filter (tool: builtins.isAttrs tool && tool ? artifact) (testInputs test)
          )
        );
      jobStages =
        drv:
        let
          suite = drv.testSuite or { };
          stages = lib.concatMap testStages (if suite == { } then [ drv ] else lib.attrValues suite);
          groups = lib.groupBy (stage: builtins.toJSON (builtins.removeAttrs stage [ "tests" ])) stages;
        in
        lib.mapAttrsToList (
          _: group:
          (builtins.head group)
          // {
            tests = lib.unique (lib.concatMap (stage: stage.tests) group);
          }
        ) groups;
    in
    {
      schema = 1;
      inherit revision;
      source = builtins.path {
        path = source;
        name = "tvp-test-source";
      };
      system = pkgs.stdenv.hostPlatform.system;
      aggregate = builtins.unsafeDiscardOutputDependency aggregate.drvPath;
      displayLabels = builtins.listToAttrs (
        lib.concatLists (lib.mapAttrsToList jobLabels jobs)
        ++ label aggregate "All tests: collecting results"
      );
      jobs = lib.mapAttrsToList (name: drv: {
        inherit name;
        drv = builtins.unsafeDiscardOutputDependency drv.drvPath;
        outputs = outputPaths drv;
        tests = lib.mapAttrsToList (testName: test: {
          name = testName;
          drv = builtins.unsafeDiscardOutputDependency test.drvPath;
          outputs = outputPaths test;
        }) (drv.testSuite or { });
        stages = jobStages drv;
      }) jobs;
      skipped = lib.mapAttrsToList (name: p: {
        inherit name;
        inherit (p.tvp.status) reason;
      }) broken;
    };

  # Reference derivations without demanding their outputs. Rooting this plan
  # protects the frozen build graph without building the catalogue first.
  # A shell writer would bind-mount that entire graph merely to write JSON,
  # exceeding the kernel mount limit. toFile retains the same drv references.
  mkPlan = args: builtins.toFile "tvp-test-plan.json" (builtins.toJSON (planManifest args));
}
