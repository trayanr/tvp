# Plan/API checks for the complete GMP family. No package or probe is built here.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  bootstrap = import ../../bootstrap { };
  family = import ../../pkgs/libraries/gmp { inherit pkgs tvp; };
  p = family.canonical.gmp_6_3_0;
  old = family.canonical.gmp_5_0_5;
  transitional = family.canonical.gmp_6_1_0;
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  withoutCheck = p.override { doCheck = false; };
  checkFlags = p.override { checkCFlags = [ "-DGMP_CHECK_FLAG_PROBE=1" ]; };
  withoutCxx = p.override { cxx = false; };
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "/gmp-runtime-probe" ]; });
  marker = builtins.derivation {
    name = "gmp-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-gmp-tool";
  };
  rebound = p.edit (
    s:
    s
    // {
      base = s.base.override { standardTools.gnumake = marker; };
    }
  );
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  m4 = p.override { m4 = marker; };
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  constructed = family.instantiate {
    version = "6.3.0";
    base = tvp.baseTiers.seed;
    deps.m4 = bootstrap.build-m4;
  };
  interface = p.edit (
    s:
    s
    // {
      installedInterface = s.installedInterface // {
        hasPkgConfig = false;
      };
    }
  );
  results = {
    allNineVersions = builtins.length (builtins.attrNames family.canonical) == 9;
    allVersionsUseOwnedEraProcedures = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "gmp" version};
      in
      q.specification.base.name == tvp.baseTiers.full.name
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && !(builtins.any (s: s.name == "gmp.check") q.buildSteps)
      && q.tests ? upstream
    ) (builtins.attrNames family.recipes.gmp.versionTable);
    actualEras =
      builtins.baseNameOf family.recipes.gmp.versionTable."5.0.5".def.builder == "build-5.0.5.nix"
      && builtins.baseNameOf family.recipes.gmp.versionTable."6.1.0".def.builder == "build-6.1.0.nix"
      &&
        family.recipes.gmp.versionTable."6.2.0".def.builder
        == family.recipes.gmp.versionTable."6.3.0".def.builder;
    publicM4Choice = p.tvp.deps.m4.drvPath == tvp.packages.m4.drvPath;
    latestAlias = tvp.packages.gmp.drvPath == p.drvPath;
    legacyAlias = tvp.packages.gmp_5_0.drvPath == old.drvPath;
    stageLocalBase = constructed.specification.base.name == tvp.baseTiers.seed.name;
    stageLocalM4 = constructed.tvp.deps.m4.drvPath == bootstrap.build-m4.drvPath;
    noopOverride = sameProduction (p.override { });
    noopEdit = sameProduction (p.edit (s: s));
    testPolicyReusesProduction = sameProduction withoutCheck && !(withoutCheck.tests ? upstream);
    testFlagsReuseProduction =
      sameProduction checkFlags && checkFlags.tests.upstream.drvPath != p.tests.upstream.drvPath;
    upstreamFromCheckpoint =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    cxxEditAffectsBuild =
      withoutCxx.artifact.drvPath != p.artifact.drvPath
      && lib.hasInfix "--disable-cxx" (step "gmp.configure" withoutCxx).run;
    cxxEditRebindsTests = !(withoutCxx.tests ? cxx) && p.tests ? cxx;
    sourceLayoutEras =
      !(builtins.elem "test-driver" old.specification.sourceLayout.scripts)
      && builtins.elem "test-driver" transitional.specification.sourceLayout.scripts;
    pkgConfigEras =
      !old.specification.installedInterface.hasPkgConfig
      && !transitional.specification.installedInterface.hasPkgConfig
      && p.specification.installedInterface.hasPkgConfig;
    reportedVersionException = family.canonical.gmp_6_0_0a.tvp.reportedVersion == "6.0.0";
    interfaceEditReusesArtifact =
      interface.artifact.drvPath == p.artifact.drvPath && interface.drvPath != p.drvPath;
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    baseMakeEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "gmp.build" rebound)
    .run;
    baseShellEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (step "gmp.configure" shell)
    .run;
    baseShellEditRebindsTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    m4OverrideRebindsCommand = (step "gmp.configure" m4).env.M4 == "${marker}/bin/m4";
    baseToolsPrecedeGmp =
      builtins.all
        (
          name:
          tvp.baseTiers.full.standardTools.${name}.drvPath
          == tvp.baseTiers.native.standardTools.${name}.drvPath
        )
        [
          "gnumake"
          "gnutar"
          "xz"
          "python"
          "patchelf"
          "sed"
          "grep"
          "gawk"
          "diffutils"
          "findutils"
        ];
    m4BuildToolsPrecedeGmp =
      builtins.all
        (name: tvp.packages.m4.tvp.deps.${name}.drvPath == tvp.baseTiers.full.standardTools.${name}.drvPath)
        [
          "gnumake"
          "gnutar"
          "gawk"
          "diffutils"
          "sed"
          "grep"
        ];
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "GMP family contracts: ${lib.concatStringsSep ", " failed}";
results
