# Whole-family source/plan contracts. These never realize Automake or providers.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/automake { inherit pkgs tvp; };
  table = family.recipes.automake.versionTable;
  versions = builtins.attrNames table;
  p = family.canonical.automake_1_19;
  old = family.canonical.automake_1_0;
  constrained = family.canonical.automake_1_2;
  middle = family.canonical.automake_1_6;
  firstPrepared = family.canonical.automake_1_12;
  hasStep = name: q: builtins.any (s: s.name == name) q.buildSteps;
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  marker = builtins.derivation {
    name = "automake-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-automake-tool";
  };
  disabled = p.override { doCheck = false; };
  upstreamEdit = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only >&2\n";
      };
    }
  );
  runtime = p.editRuntime (r: r // { shell = marker; });
  make = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  patch = family.canonical.automake_1_4.edit (
    s: s // { base = s.base.override { standardTools.patch = marker; }; }
  );
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  perl = p.override { perl = marker; };
  autoconf = p.override { autoconf = marker; };
  scalar = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values = {
          CFLAGS = "-O0 -DSELECTED=42";
          LDFLAGS = "-Wl,--as-needed";
        };
      };
    }
  );
  structured = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.flags = {
          NIX_CFLAGS_COMPILE = [
            "-O0"
            "-DSELECTED=42"
          ];
          NIX_LDFLAGS = [ "--as-needed" ];
        };
      };
    }
  );
  staged = family.instantiate {
    version = "1.19";
    base = tvp.baseTiers.seed;
  };
  expectedBuilder =
    version:
    if lib.versionOlder version "1.6" then
      "build-1.0.nix"
    else if lib.versionOlder version "1.12" then
      "build-1.6.nix"
    else
      "build-1.12.nix";
  results = {
    allSeventyFiveReleases = builtins.length versions == 75;
    threeActualEras = builtins.all (
      version: builtins.baseNameOf table.${version}.def.builder == expectedBuilder version
    ) versions;
    allPlansSplit = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "automake" version};
      in
      builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && !(hasStep "automake.check" q)
      && hasStep "automake.save-build-tree" q
      && q.tests ? upstream
    ) versions;
    earliestHasNoAclocal = !(old.tvp.features.aclocal) && !(old.tests ? aclocal);
    constrainedAutoconf = constrained.tvp.deps.autoconf.drvPath == tvp.packages.autoconf_2_13.drvPath;
    environmentBindingEra = lib.hasInfix "export PERL=" (step "automake.configure" old).run;
    argumentBindingEra = lib.hasInfix ''--prefix="$out" PERL='' (step "automake.configure" middle).run;
    unsuffixedOldData = old.specification.installedInterface.dataDirectory == "share/automake";
    suffixedMiddleData = middle.specification.installedInterface.dataDirectory == "share/automake-1.6";
    modernApiPreparation =
      hasStep "automake.api" firstPrepared
      && hasStep "automake.api" p
      && !(hasStep "automake.api" old)
      && !(hasStep "automake.api" middle);
    supportedCodecs =
      old.specification.sourceLayout.compression == "gzip"
      && family.canonical.automake_1_6_1.specification.sourceLayout.compression == "bzip2"
      && p.specification.sourceLayout.compression == "xz";
    allArchiveFactsAgree = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "automake" version};
        source = q.specification.sourceLayout;
        compression = {
          "tar.gz" = "gzip";
          "tar.bz2" = "bzip2";
          "tar.xz" = "xz";
        };
      in
      lib.hasSuffix ("." + source.archiveExt) (builtins.baseNameOf (toString q.specification.src))
      && source.compression == compression.${source.archiveExt}
    ) versions;
    narrowReleasePatches =
      builtins.length table."1.4".def.patches == 1 && builtins.length table."1.8".def.patches == 1;
    middleAclocalDirectory =
      family.canonical.automake_1_11.specification.buildFeatures.installAclocalDirectory
      && !(p.specification.buildFeatures.installAclocalDirectory);
    modernUpstreamScope =
      p.specification.upstreamTests == [
        "t/depcomp.sh"
        "t/depcomp2.sh"
        "t/nodepcomp.sh"
      ];
    historicalUpstreamScope =
      !(old.specification ? upstreamTests) && !(middle.specification ? upstreamTests);
    stageLocalBase = staged.specification.base.name == tvp.baseTiers.seed.name;
    noopOverride = same (p.override { });
    noopEdit = same (p.edit (s: s));
    testPolicyReusesProduction = same disabled && !(disabled.tests ? upstream);
    upstreamEditReusesProduction =
      same upstreamEdit && upstreamEdit.tests.upstream.drvPath != p.tests.upstream.drvPath;
    upstreamConsumesArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    effectiveMakeRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "automake.build" make)
    .run;
    effectivePatchRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/patch") (step "automake.patches" patch)
    .run;
    effectiveShellRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (step "automake.configure" shell)
    .run;
    shellRoleReachesTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    effectiveAutoconf =
      autoconf.artifact.drvPath != p.artifact.drvPath
      && autoconf.tvp.deps.autoconf.drvPath == marker.drvPath;
    effectivePerl =
      perl.artifact.drvPath != p.artifact.drvPath && perl.tvp.deps.perl.drvPath == marker.drvPath;
    scalarFlagsSurvive =
      (step "automake.configure" scalar).env.CFLAGS == "-O0 -DSELECTED=42"
      && (step "automake.configure" scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlagsSurvive =
      lib.hasInfix "-DSELECTED=42" (step "automake.configure" structured).env.NIX_CFLAGS_COMPILE
      && lib.hasInfix "--as-needed" (step "automake.configure" structured).env.NIX_LDFLAGS;
    distinctRuntimeShellProbe =
      p.tvp.declaredTestDependencies.runtimeShell.drvPath != p.specification.runtime.shell.drvPath;
    retainedHistoricalRecipe = builtins.all (
      version: !(family.recipes.automake.constructionRecipe.versionTable.${version}.def ? constructor)
    ) versions;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Automake family contracts: ${lib.concatStringsSep ", " failed}";
results
