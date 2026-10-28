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

  # Reference derivations without demanding their outputs. Rooting this plan
  # protects the frozen build graph without building the catalogue first.
  mkPlan =
    {
      pkgs,
      batches,
      checks,
      canonical,
      source,
      revision ? null,
    }:
    let
      jobs = suiteJobs { inherit batches checks; };
      broken = lib.filterAttrs (_: p: (p.tvp.status.level or "ok") == "broken") canonical;
    in
    pkgs.writeText "tvp-test-plan.json" (
      builtins.toJSON {
        schema = 1;
        inherit revision;
        source = builtins.path {
          path = source;
          name = "tvp-test-source";
        };
        system = pkgs.stdenv.hostPlatform.system;
        aggregate = builtins.unsafeDiscardOutputDependency (mkAll { inherit pkgs batches checks; }).drvPath;
        jobs = lib.mapAttrsToList (name: drv: {
          inherit name;
          drv = builtins.unsafeDiscardOutputDependency drv.drvPath;
          outputs = map (output: builtins.unsafeDiscardStringContext drv.${output}.outPath) drv.outputs;
          tests = lib.mapAttrsToList (testName: test: {
            name = testName;
            drv = builtins.unsafeDiscardOutputDependency test.drvPath;
            outputs = map (output: builtins.unsafeDiscardStringContext test.${output}.outPath) test.outputs;
          }) (drv.testSuite or { });
        }) jobs;
        skipped = lib.mapAttrsToList (name: p: {
          inherit name;
          inherit (p.tvp.status) reason;
        }) broken;
      }
    );
}
