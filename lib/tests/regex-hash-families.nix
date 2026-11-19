# Whole-family evaluation/edit contracts; no package realization.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  hash = import ../../pkgs/build-tools/gperf { inherit pkgs tvp; };
  regex = import ../../pkgs/libraries/pcre2 { inherit pkgs tvp; };
  g = hash.canonical.gperf_3_3;
  p = regex.canonical.pcre2_10_49;
  marker = builtins.derivation {
    name = "regex-hash-provider-never-build";
    system = "x86_64-linux";
    builder = "/never-build-regex-hash-provider";
  };
  text = x: builtins.unsafeDiscardStringContext x;
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  sameProduction = q: r: q.artifact.drvPath == r.artifact.drvPath && q.drvPath == r.drvPath;
  checkEdit =
    q:
    q.edit (
      s:
      s
      // {
        upstreamCheck = s.upstreamCheck // {
          run = s.upstreamCheck.run + "\nprintf check-only-marker >&2\n";
        };
      }
    );
  disabled = q: q.override { doCheck = false; };
  makeEdit = q: q.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shellEdit = q: q.edit (s: s // { base = s.base.override { shell = marker; }; });
  coreutilsEdit = p.edit (s: s // { base = s.base.override { coreutils = marker; }; });
  pkgEdit = p.override { pkgConfig = marker; };
  cxx = g.override { libstdcxx = marker; };
  prepEdit = p.edit (
    s:
    s
    // {
      upstreamPreparation = s.upstreamPreparation ++ [
        {
          name = "pcre2.test-only-marker";
          run = "printf test-only-marker >&2";
        }
      ];
    }
  );
  runtime = p.editRuntime (r: r // { shell = marker; });
  contracts = q: {
    noOp = sameProduction q (q.override { }) && sameProduction q (q.edit (s: s));
    owned = !(q ? overrideAttrs) && !(q ? stdenv);
    split = builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1;
    checkpoint = builtins.any (s: s.name == "${q.pname}.save-build-tree") q.buildSteps;
    dropCheckpoint = builtins.any (s: s.name == "${q.pname}.drop-build-tree") q.buildSteps;
    checkOutsideProduction = !(builtins.any (s: s.name == "${q.pname}.check") q.buildSteps);
    disabledReuses = sameProduction q (disabled q) && !((disabled q).tests ? upstream);
    checkEditReuses = sameProduction q (checkEdit q);
    checkEditChangesRaw =
      (checkEdit q).tests.upstream.specification.validation.execution.drvPath
      != q.tests.upstream.specification.validation.execution.drvPath;
    makeBaseRebinds = lib.hasInfix (text "${marker}/bin/make") (
      text (step "${q.pname}.build" (makeEdit q)).run
    );
    shellBaseRebinds = lib.hasInfix (text "${marker}/bin/bash") (
      text (step "${q.pname}.configure" (shellEdit q)).run
    );
    testBaseRebinds = (shellEdit q).tests.version.specification.base.shell.drvPath == marker.drvPath;
    independentAcceptance =
      q.tests.upstream.specification.validation.production.drvPath == q.artifact.drvPath;
    reboundFactory =
      (
        (q.mkTests.override {
          tests = import (
            if q.pname == "gperf" then
              ../../pkgs/build-tools/gperf/tests/installed.nix
            else
              ../../pkgs/libraries/pcre2/tests/installed.nix
          );
        })
          (shellEdit q)
      ).version.package.outPath == (shellEdit q).outPath;
  };
  result = {
    gperf = contracts g;
    pcre2 = contracts p;
    eightRows =
      builtins.length (builtins.attrNames hash.canonical) == 4
      && builtins.length (builtins.attrNames regex.canonical) == 4;
    oneHashProcedure =
      builtins.length (
        lib.unique (map (e: e.def.builder) (builtins.attrValues hash.recipes.gperf.versionTable))
      ) == 1;
    oneRegexProcedure =
      builtins.length (
        lib.unique (map (e: e.def.builder) (builtins.attrValues regex.recipes.pcre2.versionTable))
      ) == 1;
    noHashExtraDeps = builtins.all (e: e.def.deps == { }) (
      builtins.attrValues hash.recipes.gperf.versionTable
    );
    explicitPkgConfigOnly = builtins.all (e: builtins.attrNames e.def.deps == [ "pkgConfig" ]) (
      builtins.attrValues regex.recipes.pcre2.versionTable
    );
    effectiveDefaultCxxRuntime = g.specification.libstdcxx == null && g.runtime.libraries == [ ];
    cxxRuntimeOverrideReusesArtifact =
      cxx.artifact.drvPath == g.artifact.drvPath && cxx.drvPath != g.drvPath;
    cxxRuntimeOverrideEffective = (builtins.head cxx.runtime.libraries).drvPath == marker.drvPath;
    staticCompanionChangesArtifact =
      (p.override { static = true; }).artifact.drvPath != p.artifact.drvPath;
    pcreAllWidths =
      p.specification.installedInterface.widths == [
        8
        16
        32
      ];
    pcreFeatureProfile =
      p.tvp.features.shared && p.tvp.features.jit && p.tvp.features.unicode && !p.tvp.features.static;
    coreutilsTestBinding = lib.hasInfix (text "${marker}/bin/echo") (
      text (builtins.head coreutilsEdit.specification.upstreamPreparation).run
    );
    coreutilsIsEffectiveBase = coreutilsEdit.specification.base.coreutils.drvPath == marker.drvPath;
    testPreparationReusesProduction = sameProduction p prepEdit;
    testPreparationChangesRaw =
      prepEdit.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    calloutsOutsideProduction =
      !(builtins.any (s: s.name == "pcre2.callout-echo" || s.name == "pcre2.test-shells") p.buildSteps);
    runnerHelperOutsideProduction =
      !(lib.hasInfix "prepare.py" (lib.concatStringsSep "\n" (map (s: s.run or "") p.buildSteps)));
    pkgConfigEffective = pkgEdit.specification.pkgConfig.drvPath == marker.drvPath;
    runtimeShellReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    rawGperfEvidence = g.tests ? upstream-evidence;
    reusedHashAssertions = g.tests ? generated && g.tests ? runtime && g.tests ? constructor;
    reusedRegexAssertions =
      p.tests ? shared-api
      && p.tests ? static-api
      && p.tests ? elf-contract
      && p.tests ? pkgconfig
      && p.tests ? upstream-tags;
    defaults = tvp.packages.gperf.drvPath == g.drvPath && tvp.packages.pcre2.drvPath == p.drvPath;
  };
  flat = lib.concatMap (
    name:
    let
      value = result.${name};
    in
    if builtins.isAttrs value then
      map (sub: {
        name = "${name}.${sub}";
        value = value.${sub};
      }) (builtins.attrNames value)
    else
      [ { inherit name value; } ]
  ) (builtins.attrNames result);
  failed = map (r: r.name) (builtins.filter (r: !r.value) flat);
in
assert failed == [ ] || throw "PCRE2/Gperf family contracts: ${lib.concatStringsSep ", " failed}";
result
