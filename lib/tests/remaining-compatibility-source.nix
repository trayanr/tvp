# Pure, bounded SOURCE ONLY contracts for the 13 compatibility tails.
{ tvp, lib }:
let
  names = [
    "acl_2_3_0"
    "acl_2_3_1"
    "gawk_3_0_6"
    "gawk_3_1_8"
    "gdbm_1_7_3"
    "gdbm_1_8_1"
    "gmp_5_0_5"
    "gmp_5_1_3"
    "gmp_6_0_0a"
    "mpfr_2_4_2"
    "mpfr_3_0_1"
    "mpfr_3_1_6"
    "mpc_1_0_3"
  ];
  selected = lib.genAttrs names (n: tvp.canonical.${n});
  consumes =
    p: q:
    builtins.hasAttr (builtins.unsafeDiscardStringContext q.drvPath) (
      builtins.getContext (
        builtins.toJSON {
          inherit (p.buildStepRunner) inputs childScripts text;
        }
      )
    );
  inspect =
    name: p:
    let
      s = p.specification;
      parts = tvp.builder.steps.partition p.buildSteps;
      source = builtins.toFile "compatibility-source-control" "offline source identity control";
      sourceEdit = p.edit (x: x // { src = source; });
      sourceOverride = p.override { src = source; };
      suffix = p.editSteps (
        plan:
        plan
        ++ [
          {
            name = "contract.final-only";
            run = ": final-only";
          }
        ]
      );
      prefix = p.editSteps (
        plan:
        map (
          step:
          if step.name == (builtins.head parts.first).name then
            step // { run = step.run + "\n: source-control"; }
          else
            step
        ) plan
      );
      unchecked = p.override { doCheck = false; };
      runtime = p.editRuntime (r: r // { libraries = (r.libraries or [ ]) ++ [ s.coreutils ]; });
      changedTools = p.edit (
        x:
        if x ? tools then
          x
          // {
            tools = x.tools // {
              gnumake = x.coreutils;
            };
          }
        else
          x // { gnumake = x.coreutils; }
      );
      validation = p.edit (
        x:
        x
        // {
          upstreamCheck = x.upstreamCheck // {
            run = ": changed upstream validation";
          };
        }
      );
      raw = if s ? upstreamPlan then p.tests.upstream.passthru.upstreamExecution else null;
      libraryEdit = p.edit (
        x:
        x
        // {
          libraries = x.libraries // {
            gmp = x.coreutils;
          };
        }
      );
      shellEdit = p.editRuntime (r: r // { shell = s.coreutils; });
      effective = builtins.listToAttrs (
        map (step: {
          name = step.name;
          value = step.run;
        }) (tvp.builder.steps.active (parts.first ++ parts.second))
      );
      family = p.pname;
      unfilteredGdbm = import ../../pkgs/libraries/gdbm/tests {
        pkgs = {
          inherit lib;
        };
        tvpLib = tvp.lib;
        gdbm = p;
      };
      checks =
        {
          noOpOverride =
            (p.override { }).drvPath == p.drvPath && (p.override { }).artifact.drvPath == p.artifact.drvPath;
          noOpEdit = (p.edit (x: x)).drvPath == p.drvPath;
          sourceOverride =
            sourceOverride.artifact.drvPath != p.artifact.drvPath && sourceOverride.src == source;
          sourceEdit = sourceEdit.artifact.drvPath != p.artifact.drvPath && sourceEdit.drvPath != p.drvPath;
          prefixEdit = prefix.artifact.drvPath != p.artifact.drvPath;
          suffixReuse = suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
          runtimeReuse = runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
          runtimeExpectation = builtins.elem s.coreutils runtime.runtime.libraries;
          productionPartition =
            parts.split
            && builtins.length parts.first >= 5
            && (builtins.head parts.second).name == "output.copy-artifacts";
          realInstall = builtins.any (
            step: lib.hasInfix "make" step.run && lib.hasInfix "install" step.run
          ) parts.first;
          transport =
            lib.hasInfix "TVP_ARTIFACT_ROOT" (builtins.head parts.second).run && consumes p p.artifact;
          noCheckInProduction = builtins.all (step: !(lib.hasSuffix ".check" step.name)) (
            tvp.builder.steps.active (parts.first ++ parts.second)
          );
          checkReuse = unchecked.drvPath == p.drvPath && unchecked.artifact.drvPath == p.artifact.drvPath;
          effectiveTool =
            changedTools.artifact.drvPath != p.artifact.drvPath
            && changedTools.tvp.deps.gnumake.drvPath == s.coreutils.drvPath;
          testsRebound = suffix.tests.version.passthru.package.drvPath == suffix.drvPath;
          testFactory = p.tests.version.tvp.kind == "owned-test";
          outputs = p.outputs == [ "out" ] && p.out.artifact.drvPath == p.artifact.drvPath;
        }
        // lib.optionalAttrs (s ? upstreamPlan) {
          upstreamRegistered = p.tests ? upstream && p.tests.upstream.tvp.kind == "owned-test";
          rawExecution = raw.specification.validationRole == "upstream-execution";
          rawAcceptance =
            consumes p.tests.upstream raw
            && p.tests.upstream.specification.validation.factory == "owned.mkTest";
          noReverseInput =
            !(consumes p raw)
            && !(consumes p.artifact raw)
            && !(consumes p p.tests.upstream)
            && !(consumes p.artifact p.tests.upstream);
          testOnlyReuse =
            validation.drvPath == p.drvPath && validation.artifact.drvPath == p.artifact.drvPath;
          testOnlyChangesRaw = validation.tests.upstream.passthru.upstreamExecution.drvPath != raw.drvPath;
          noCheckUnregisters = !(unchecked.tests ? upstream);
        }
        // lib.optionalAttrs (family == "acl") {
          measuredCompiler =
            p.tvp.base == "gcc13-owned-v3" && p.tvp.cc.drvPath == tvp.bases.gcc13-owned-v3.stdenv.cc.drvPath;
          hardening =
            !(s ? hardeningDisable)
            && p.tvp.cc.defaultHardeningFlags == tvp.bases.gcc13-owned-v3.stdenv.cc.defaultHardeningFlags;
          attrPropagation = map toString p.development.libraries == [ (toString s.libraries.attr) ];
        }
        // lib.optionalAttrs (family == "gawk") {
          oldFeatures =
            !p.tvp.features.bignum && !(p.tvp.deps ? gmp) && !(p.tvp.deps ? mpfr) && !(p.tvp.deps ? readline);
          dialect = s.cStandard == "gnu89" && s.hardeningDisable == [ "format" ];
          equalWidth = builtins.stringLength p.artifact.outPath == builtins.stringLength p.outPath;
          functionPassthru = p ? mkTests.override;
          privateShellEditReusesProduction =
            let
              q = p.edit (x: x // { testShell = x.coreutils; });
            in
            q.artifact.drvPath == p.artifact.drvPath
            && q.drvPath == p.drvPath
            && q.tests.upstream.passthru.upstreamExecution.drvPath != raw.drvPath;
          shellBindingReuse =
            shellEdit.artifact.drvPath == p.artifact.drvPath && shellEdit.drvPath != p.drvPath;
        }
        // lib.optionalAttrs (family == "gmp") {
          configureFlags =
            lib.hasInfix "--with-pic" effective."gmp.configure"
            && lib.hasInfix "--enable-cxx" effective."gmp.configure";
          checkFlagsIsolated =
            !(s.checkCFlags != [ ] && lib.hasInfix (builtins.head s.checkCFlags) effective."gmp.build");
          reportedVersion = p.tvp.reportedVersion == (if p.version == "6.0.0a" then "6.0.0" else p.version);
          cxxOverride = !(p.override { cxx = false; }).tvp.features.cxx;
          functionPassthru = p ? mkTests.override;
        }
        // lib.optionalAttrs (family == "mpfr") {
          functionPassthru = p ? mkTests.override;
          libraryEdit =
            libraryEdit.artifact.drvPath != p.artifact.drvPath
            && libraryEdit.tvp.deps.gmp.drvPath == s.coreutils.drvPath;
          oldCapabilities =
            !p.tvp.features.float128 && p.tvp.features.mpfrRoundingNames == (p.version != "2.4.2");
          gmpCeiling = p.tvp.deps.gmp.version == (if p.version == "3.1.6" then "6.3.0" else "5.0.5");
        }
        // lib.optionalAttrs (family == "mpc") {
          functionPassthru = p ? mkTests.override;
          libraryEdit =
            libraryEdit.artifact.drvPath != p.artifact.drvPath
            && libraryEdit.tvp.deps.gmp.drvPath == s.coreutils.drvPath;
          mpfr3 =
            p.tvp.deps.mpfr.version == "3.1.6" && p.tvp.deps.mpfr.drvPath == tvp.packages.mpfr_3.drvPath;
        }
        // lib.optionalAttrs (family == "gdbm") {
          degraded = p.tvp.status.level == "degraded";
          staticBoundary =
            p.tvp.features.shared == (p.version == "1.8.1")
            && p.tvp.features.compatLib == (p.version == "1.8.1");
          noDummySuite = !(p.tests ? upstream) && s ? upstreamUnavailable;
          failingControlsRetained =
            unfilteredGdbm ? store
            && unfilteredGdbm ? ndbm
            && lib.hasInfix "store.c" (builtins.head unfilteredGdbm.store.buildSteps).run
            && lib.hasInfix "ndbm.c" (builtins.head unfilteredGdbm.ndbm.buildSteps).run;
          knownFailures =
            p.version != "1.8.1"
            ||
              p.tvp.status.knownTestFailures == [
                "store"
                "ndbm"
              ];
        };
    in
    {
      inherit checks;
      passed = builtins.all (x: x) (builtins.attrValues checks);
      producer = p.drvPath;
      artifact = p.artifact.drvPath;
      status = p.tvp.status;
      tests = builtins.attrNames p.tests;
      commands =
        map (step: { inherit (step) name run; }) (tvp.builder.steps.active (parts.first ++ parts.second))
        ++ lib.optionals (s ? upstreamPlan) (
          map (step: { inherit (step) name run; }) p.tests.upstream.passthru.upstreamExecution.buildSteps
        );
    };
  rows = builtins.mapAttrs inspect selected;
in
{
  inherit rows;
  passed = builtins.all (r: r.passed) (builtins.attrValues rows);
  inventory = (import ../recipe-splits.nix { inherit lib; }).inventory { canonical = selected; };
  full = false;
  machineReady = false;
  mergeEligible = false;
}
