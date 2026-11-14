# Evaluation contracts only; no package or fixture realization.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  gzip = import ../../pkgs/build-tools/gzip { inherit pkgs tvp; };
  bzip2 = import ../../pkgs/build-tools/bzip2 { inherit pkgs tvp; };
  g = gzip.canonical.gzip_1_15;
  b = bzip2.canonical.bzip2_1_0_8;
  text = x: builtins.unsafeDiscardStringContext x;
  sameProduction = p: q: p.artifact.drvPath == q.artifact.drvPath && p.drvPath == q.drvPath;
  step = name: p: builtins.head (builtins.filter (s: s.name == name) p.buildSteps);
  marker = builtins.derivation {
    name = "codec-provider-never-build";
    system = "x86_64-linux";
    builder = "/never-build-codec-provider";
  };
  disabled = p: p.override { doCheck = false; };
  editedCheck =
    p:
    p.edit (
      s:
      s
      // {
        upstreamCheck = s.upstreamCheck // {
          run = s.upstreamCheck.run + "\nprintf upstream-only-marker >&2\n";
        };
      }
    );
  changedRuntime = p: p.editRuntime (r: r // { shell = marker; });
  makeEdit = p: p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shellEdit = p: p.edit (s: s // { base = s.base.override { shell = marker; }; });
  pager = g.override { pager = marker; };
  profile = g.override { upstreamPagerShim = true; };
  helpers = b.override { helperInterface = "declared-tools"; };
  checksFor = p: {
    noOp = sameProduction p (p.override { }) && sameProduction p (p.edit (s: s));
    owned = !(p ? overrideAttrs) && !(p ? stdenv);
    oneSplit = builtins.length (builtins.filter (s: (s.kind or "") == "split") p.buildSteps) == 1;
    independentU = !(builtins.any (s: s.name == "${p.pname}.check") p.buildSteps);
    checkpoint = builtins.any (s: s.name == "${p.pname}.save-build-tree") p.buildSteps;
    droppedCheckpoint = builtins.any (s: s.name == "${p.pname}.drop-build-tree") p.buildSteps;
    disableReuses = sameProduction p (disabled p) && !((disabled p).tests ? upstream);
    checkReuses = sameProduction p (editedCheck p);
    checkChangesRaw =
      (editedCheck p).tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    runtimeReuses =
      (changedRuntime p).artifact.drvPath == p.artifact.drvPath
      && (changedRuntime p).drvPath != p.drvPath;
    runtimeFactoryRebinds =
      (changedRuntime p).tests.version.package.outPath == (changedRuntime p).outPath;
    makeRebinds = lib.hasInfix (text "${marker}/bin/make") (
      text (step "${p.pname}.build" (makeEdit p)).run
    );
    shellTestBaseRebinds =
      (shellEdit p).tests.version.specification.base.shell.drvPath == marker.drvPath;
    strictIndependentAcceptance =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
  };
  result = {
    gzip = checksFor g;
    bzip2 = checksFor b;
    sixLiteralRows =
      builtins.length (builtins.attrNames gzip.canonical) == 3
      && builtins.length (builtins.attrNames bzip2.canonical) == 3;
    singleGzipProcedure =
      builtins.length (
        lib.unique (map (entry: entry.def.builder) (builtins.attrValues gzip.recipes.gzip.versionTable))
      ) == 1;
    singleBzip2Procedure =
      builtins.length (
        lib.unique (map (entry: entry.def.builder) (builtins.attrValues bzip2.recipes.bzip2.versionTable))
      ) == 1;
    gzipOnlyPagerDependency = builtins.all (entry: builtins.attrNames entry.def.deps == [ "pager" ]) (
      builtins.attrValues gzip.recipes.gzip.versionTable
    );
    bzip2NoPackageDependencies = builtins.all (entry: builtins.attrNames entry.def.deps == [ ]) (
      builtins.attrValues bzip2.recipes.bzip2.versionTable
    );
    stableGzexeLayout = builtins.all (p: p.specification.installedInterface.gzexeSkip == 49) (
      builtins.attrValues gzip.canonical
    );
    historicalPagerShim =
      gzip.canonical.gzip_1_13.specification.upstreamPagerShim
      && gzip.canonical.gzip_1_14.specification.upstreamPagerShim
      && !g.specification.upstreamPagerShim;
    profileReusesProduction = sameProduction g profile;
    profileChangesRaw =
      profile.tests.upstream.specification.validation.execution.drvPath
      != g.tests.upstream.specification.validation.execution.drvPath;
    pagerReusesArtifact = pager.artifact.drvPath == g.artifact.drvPath && pager.drvPath != g.drvPath;
    runtimeGrepBinding = lib.hasInfix (text "${g.runtime.grep}/bin/grep") (
      text (step "gzip.bind-helpers" g).run
    );
    helperInterfaceReusesArtifact =
      helpers.artifact.drvPath == b.artifact.drvPath && helpers.drvPath != b.drvPath;
    historicalDeclaredHelpers =
      bzip2.canonical.bzip2_1_0_6.specification.helperInterface == "declared-tools"
      && bzip2.canonical.bzip2_1_0_7.specification.helperInterface == "declared-tools";
    currentCallerHelpers = b.specification.helperInterface == "caller-tools";
    bzip2DynamicAndStatic =
      b.tests ? shared-library && b.tests ? static && b.tests ? static-library && b.tests ? recover;
    bzip2HelperAndDisableAssertions = b.tests ? shell-helpers && b.tests ? customization;
    gzipActualInstalledAssertions =
      g.tests ? zless
      && g.tests ? zmore
      && g.tests ? helper-behavior
      && g.tests ? split
      && g.tests ? constructor;
    aliases = tvp.packages.gzip.drvPath == g.drvPath && tvp.packages.bzip2.drvPath == b.drvPath;
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
assert failed == [ ] || throw "Gzip/Bzip2 family contracts: ${lib.concatStringsSep ", " failed}";
result
