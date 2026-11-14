# Source/evaluation contracts for the complete Libtool family. No realizations.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/libtool { inherit pkgs tvp; };
  rows = family.recipes.libtool.versionTable;
  p = family.canonical.libtool_2_6_2;
  packages = builtins.attrValues family.canonical;
  text = value: builtins.unsafeDiscardStringContext value;
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  disabled = p.override { doCheck = false; };
  groups = p.override { testGroups = [ 1 ]; };
  check = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf test-only-marker >&2\n";
      };
    }
  );
  runtime = p.editRuntime (r: r // { shell = p.tvp.declaredTestDependencies.runtimeShell; });
  marker = builtins.derivation {
    name = "libtool-provider-never-build";
    system = "x86_64-linux";
    builder = "/never-build-libtool-provider";
  };
  makeEdit = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shellEdit = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  fileEdit = p.override { file = marker; };
  result = {
    elevenReleases = builtins.length (builtins.attrNames rows) == 11;
    fiveCompleteBuilders =
      builtins.length (lib.unique (map (v: rows.${v}.def.builder) (builtins.attrNames rows))) == 5;
    noStandardToolsInDeps = builtins.all (
      v:
      builtins.attrNames rows.${v}.def.deps == (
        if builtins.compareVersions v "1.5.26" < 0 then
          [
            "autoconf"
            "automake"
            "file"
            "m4"
            "platformAutomake"
          ]
        else
          [
            "autoconf"
            "automake"
            "file"
            "m4"
          ]
      )
    ) (builtins.attrNames rows);
    noOp = sameProduction (p.override { }) && sameProduction (p.edit (s: s));
    allOwnedSplit = builtins.all (
      q:
      !(q ? overrideAttrs)
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
    ) packages;
    checkOutsideProduction = builtins.all (
      q: !(builtins.any (s: s.name == "libtool.check") q.buildSteps)
    ) packages;
    allCheckpoints = builtins.all (
      q: builtins.any (s: s.name == "libtool.save-build-tree") q.buildSteps
    ) packages;
    allDropCheckpoints = builtins.all (
      q: builtins.any (s: s.name == "libtool.drop-build-tree") q.buildSteps
    ) packages;
    earlierNoLTDL =
      !family.canonical.libtool_1_0.tvp.features.ltdl
      && !family.canonical.libtool_1_2.tvp.features.acLibtool;
    laterLTDL = family.canonical.libtool_1_3_5.tvp.features.ltdl;
    gnu89Consumer = family.canonical.libtool_1_0.tvp.features.consumerCStandard == "gnu89";
    oldestAutomakeLine = lib.hasPrefix "1.4" family.canonical.libtool_1_0.specification.automake.version;
    platformAutomakeIndependent =
      family.canonical.libtool_1_0.specification.platformAutomake.drvPath
      != family.canonical.libtool_1_0.specification.automake.drvPath;
    configureArgumentEra =
      family.canonical.libtool_1_5_26.specification.sourceLayout == "root-ltmain-configure-arguments";
    macroEra =
      family.canonical.libtool_2_2_10.tvp.features.ltInit
      && !family.canonical.libtool_2_2_10.tvp.features.toolDefaults;
    nextVersionNarrowOption =
      p.tvp.features.nextVersion && !family.canonical.libtool_2_5_4.tvp.features.nextVersion;
    latestSharesBuilder = rows."2.6.2".def.builder == rows."2.4.7".def.builder;
    latestFullUpstreamScope = p.specification.testGroups == [ ];
    earlierBoundedUpstreamScope =
      family.canonical.libtool_2_4_7.specification.testGroups == [
        1
        2
        3
        4
        5
        6
        7
        8
        9
        10
      ];
    disableReusesProduction = sameProduction disabled && !(disabled.tests ? upstream);
    groupEditReusesProduction = sameProduction groups;
    checkEditReusesProduction = sameProduction check;
    groupEditChangesRaw =
      groups.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    checkEditChangesRaw =
      check.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    distinctRuntimeTestProvider =
      p.tvp.declaredTestDependencies.runtimeShell.drvPath != p.specification.base.shell.drvPath;
    runtimeShellInFinal = lib.hasInfix (text "${runtime.runtime.shell}/bin/bash") (
      text (step "libtool.relocate-runtime" runtime).run
    );
    nextVersionKeepsRuntimePATH = lib.hasInfix (text "${p.specification.base.standardTools.sed}/bin") (
      text (step "libtool.next-version-runtime" runtime).run
    );
    makeEditRebindsBuild = lib.hasInfix (text "${marker}/bin/make") (
      text (step "libtool.build" makeEdit).run
    );
    shellEditRebindsConfigure = lib.hasInfix (text "${marker}/bin/bash") (
      text (step "libtool.configure" shellEdit).run
    );
    shellEditRebindsTestBase =
      shellEdit.tests.version.specification.base.shell.drvPath == marker.drvPath;
    fileEditRebindsConfigure = lib.hasInfix (text "${marker}/bin/file") (
      text (step "libtool.configure" fileEdit).run
    );
    aclocalDevelopment = p.development.aclocalDirectories == [ "${p}/share/aclocal" ];
    independentAcceptance =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    fixtureControlsRemain =
      p.tests ? runtime-shell-wrappers-relink
      && p.tests ? installed-consumer
      && p.tests ? user-overrides
      && p.tests ? next-version;
    defaultAlias = tvp.packages.libtool.drvPath == p.drvPath;
  };
  failed = builtins.filter (name: !result.${name}) (builtins.attrNames result);
in
assert failed == [ ] || throw "Libtool family contracts: ${lib.concatStringsSep ", " failed}";
result
