# Evaluated ISL family/customization contracts; no package or probe is built here.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  bootstrap = import ../../bootstrap { };
  family = import ../../pkgs/libraries/isl { inherit pkgs tvp; };
  p = family.canonical.isl_0_28;
  old = family.canonical.isl_0_20;
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  disabled = p.override { doCheck = false; };
  changedCheck = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only-marker >&2\n";
      };
    }
  );
  runtimeGmp = p.specification.gmp.editSteps (
    steps:
    steps
    ++ [
      {
        name = "isl-test.alternate-gmp";
        run = "true";
      }
    ]
  );
  runtime = p.editRuntime (r: r // { libraries = [ runtimeGmp ]; });
  source = p.override { src = builtins.toFile "isl-explicit-source" "explicit source"; };
  marker = builtins.derivation {
    name = "isl-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-isl-tool";
  };
  baseEdit = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  constructed = family.instantiate {
    version = "0.28";
    base = tvp.baseTiers.seed;
    deps.gmp = bootstrap.gnu-gmp;
  };
  text = value: builtins.unsafeDiscardStringContext value;
  results = {
    fourReleases = builtins.length (builtins.attrNames family.canonical) == 4;
    ownedEras = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "isl" version};
      in
      !(q ? overrideAttrs)
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(builtins.any (s: s.name == "isl.check") q.buildSteps)
      && q.tests ? upstream
      && q.specification.base.name == tvp.baseTiers.full.name
    ) (builtins.attrNames family.recipes.isl.versionTable);
    coherentModernEra =
      family.recipes.isl.versionTable."0.26".def.builder
      == family.recipes.isl.versionTable."0.28".def.builder;
    legacySoname = old.specification.installedInterface.sonameMajor == "19";
    modernSoname = p.specification.installedInterface.sonameMajor == "23";
    legacyInterfaces = !old.tvp.features.cxx && !old.specification.installedInterface.cppBindings;
    modernInterfaces = p.tvp.features.cxx && p.specification.installedInterface.cppBindings;
    legacyArchProbe = builtins.elem "--without-gcc-arch" old.specification.configureFlags;
    modernArchProbe = !(builtins.elem "--without-gcc-arch" p.specification.configureFlags);
    legacyCStandard = (step "isl.configure" old).env.CFLAGS == "-O2 -std=gnu17";
    noOp = sameProduction (p.override { }) && sameProduction (p.edit (s: s));
    policyReusesProduction = sameProduction disabled && !(disabled.tests ? upstream);
    checkEditReusesProduction =
      sameProduction changedCheck && changedCheck.tests.upstream.drvPath != p.tests.upstream.drvPath;
    independentUpstream =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    runtimeLoadedExpectation = lib.hasInfix (text "${runtimeGmp}/lib/libgmp.so") (
      text (step "test.compare" runtime.tests.loaded-library).run
    );
    runtimeLoadedDropsConstructionExpectation =
      !(lib.hasInfix (text "${p.specification.gmp}/lib/libgmp.so") (
        text (step "test.compare" runtime.tests.loaded-library).run
      ));
    sourceReplacement = source.artifact.drvPath != p.artifact.drvPath;
    makeEditRebindsCommand = lib.hasInfix (text "${marker}/bin/make") (step "isl.build" baseEdit).run;
    shellEditRebindsCommand = lib.hasInfix (text "${marker}/bin/bash") (step "isl.configure" shell).run;
    shellEditRebindsTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    publicGmp = p.tvp.deps.gmp.drvPath == tvp.packages.gmp_6.drvPath;
    defaultAlias = tvp.packages.isl.drvPath == p.drvPath;
    stageLocalBase = constructed.specification.base.name == tvp.baseTiers.seed.name;
    stageLocalGmp = constructed.tvp.deps.gmp.drvPath == bootstrap.gnu-gmp.drvPath;
    customizationEveryVersion = builtins.all (
      q: (import ../../pkgs/libraries/isl/tests/customization.nix { package = q; }) == "customization"
    ) (builtins.attrValues family.canonical);
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "ISL family contracts: ${lib.concatStringsSep ", " failed}";
results
