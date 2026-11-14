# Whole-family interface and isolation contracts; no provider is realized here.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  bootstrap = import ../../bootstrap { };
  family = import ../../pkgs/libraries/mpc { inherit pkgs tvp; };
  instantiate =
    version:
    family.instantiate {
      inherit version;
      base = tvp.baseTiers.seed;
      deps = {
        gmp = bootstrap.gnu-gmp;
        mpfr = bootstrap.gnu-mpfr;
      };
    };
  versions = builtins.attrNames family.recipes.mpc.versionTable;
  p = instantiate "1.4.1";
  oldest = instantiate "1.0.3";
  old = instantiate "1.1.0";
  middle = instantiate "1.3.1";
  noCheck = p.override { doCheck = false; };
  flags = p.override { checkCFlags = [ "-DMPC_CHECK_PROBE=1" ]; };
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  marker = builtins.derivation {
    name = "mpc-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-mpc-tool";
  };
  rebound = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  dependency = p.override { mpfr = marker; };
  interface = p.edit (
    s:
    s
    // {
      installedInterface = s.installedInterface // {
        hasPkgConfig = false;
      };
    }
  );
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "/mpc-runtime-probe" ]; });
  stripped = p.override { stripFlags = [ "--strip-debug" ]; };
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  results = {
    allEightReleases = builtins.length versions == 8;
    allEraPlansAreSplit = builtins.all (
      version:
      let
        q = instantiate version;
      in
      builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && !(builtins.any (s: s.name == "mpc.check") q.buildSteps)
      && q.tests ? upstream
    ) versions;
    actualEras =
      family.recipes.mpc.versionTable."1.0.3".def.builder
      == family.recipes.mpc.versionTable."1.1.0".def.builder
      && builtins.baseNameOf family.recipes.mpc.versionTable."1.2.0".def.builder == "build-1.2.0.nix"
      &&
        family.recipes.mpc.versionTable."1.4.0".def.builder
        == family.recipes.mpc.versionTable."1.4.1".def.builder;
    archiveEras =
      oldest.specification.sourceLayout.compression == "gzip"
      && middle.specification.sourceLayout.compression == "gzip"
      && p.specification.sourceLayout.compression == "xz";
    pkgConfigEras =
      !old.specification.installedInterface.hasPkgConfig
      && !middle.specification.installedInterface.hasPkgConfig
      && p.specification.installedInterface.hasPkgConfig;
    rootScriptsEra =
      builtins.elem "config.guess" old.specification.sourceLayout.scripts
      && !(builtins.elem "build-aux" old.specification.sourceLayout.scripts);
    buildAuxEra =
      middle.specification.sourceLayout.scripts == [
        "configure"
        "build-aux"
      ];
    narrowLegacyScriptExtension =
      oldest.specification.sourceLayout.scripts
      == old.specification.sourceLayout.scripts ++ [ "compile" ];
    oldMpfrConstraint = family.recipes.mpc.versionTable."1.0.3".def.deps.mpfr.version == "3.1.6";
    stageLocalInputs =
      p.specification.base.name == tvp.baseTiers.seed.name
      && p.tvp.deps.gmp.drvPath == bootstrap.gnu-gmp.drvPath
      && p.tvp.deps.mpfr.drvPath == bootstrap.gnu-mpfr.drvPath;
    noopOverride = sameProduction (p.override { });
    noopEdit = sameProduction (p.edit (s: s));
    testPolicyReusesProduction = sameProduction noCheck && !(noCheck.tests ? upstream);
    testFlagsReuseProduction =
      sameProduction flags && flags.tests.upstream.drvPath != p.tests.upstream.drvPath;
    upstreamRestoresArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    dependencyOverrideChangesCompilation =
      dependency.artifact.drvPath != p.artifact.drvPath
      && lib.hasInfix (builtins.unsafeDiscardStringContext "--with-mpfr=${marker}") (step "mpc.configure" dependency)
      .run;
    dependencyOverrideRebindsMetadata = dependency.tvp.deps.mpfr.drvPath == marker.drvPath;
    baseMakeEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "mpc.build" rebound)
    .run;
    baseShellEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (step "mpc.configure" shell)
    .run;
    baseShellEditRebindsTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    interfaceEditReusesArtifact =
      interface.artifact.drvPath == p.artifact.drvPath && interface.drvPath != p.drvPath;
    stripEditReusesArtifact =
      stripped.artifact.drvPath == p.artifact.drvPath && stripped.drvPath != p.drvPath;
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "MPC family contracts: ${lib.concatStringsSep ", " failed}";
results
