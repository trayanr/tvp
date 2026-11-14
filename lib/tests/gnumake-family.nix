# Evaluated Make family/edit/isolation contracts, with no package realizations.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/gnumake { inherit pkgs tvp; };
  p = family.canonical.gnumake_4_4_1;
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  disabled = p.override { doCheck = false; };
  profile = p.override { upstreamProfile = "4.4"; };
  check = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only-marker >&2\n";
      };
    }
  );
  strip = p.override { stripFlags = [ "--strip-debug" ]; };
  shell = p.tvp.declaredTestDependencies.alternateShell;
  runtime = p.editRuntime (r: r // { inherit shell; });
  marker = builtins.derivation {
    name = "gnumake-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-gnumake-tool";
  };
  baseEdit = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  shellEdit = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  text = value: builtins.unsafeDiscardStringContext value;
  scalar = p.edit (
    s:
    s
    // {
      environment = s.environment // {
        overrides.values = {
          CFLAGS = "-O0 -DFLAG=42";
          CXXFLAGS = "-O1";
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
            "-DFLAG=42"
          ];
          NIX_LDFLAGS = [ "--as-needed" ];
        };
      };
    }
  );
  results = {
    threeReleases = builtins.length (builtins.attrNames family.canonical) == 3;
    singleCompleteBuilder =
      builtins.all
        (
          version:
          family.recipes.gnumake.versionTable.${version}.def.builder
          == family.recipes.gnumake.versionTable."4.4.1".def.builder
        )
        [
          "4.3"
          "4.4"
          "4.4.1"
        ];
    ownedSplit = builtins.all (
      q:
      !(q ? overrideAttrs)
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(builtins.any (s: s.name == "gnumake.check") q.buildSteps)
    ) (builtins.attrValues family.canonical);
    earlierCxx =
      family.canonical.gnumake_4_3.specification.installedInterface.defaultCxx == "g++"
      && family.canonical.gnumake_4_4.specification.installedInterface.defaultCxx == "g++";
    latestCxx = p.specification.installedInterface.defaultCxx == "c++";
    separateProfiles =
      family.canonical.gnumake_4_3.specification.upstreamProfile == "4.3"
      && family.canonical.gnumake_4_4.specification.upstreamProfile == "4.4"
      && p.specification.upstreamProfile == "4.4.1";
    noOp = sameProduction (p.override { }) && sameProduction (p.edit (s: s));
    disabledReusesProduction = sameProduction disabled && !(disabled.tests ? upstream);
    profileReusesProduction = sameProduction profile;
    checkReusesProduction = sameProduction check;
    profileChangesRaw =
      profile.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    checkChangesRaw =
      check.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    stripReusesArtifact = strip.artifact.drvPath == p.artifact.drvPath && strip.drvPath != p.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    actualAlternateShell = shell.drvPath != p.specification.base.shell.drvPath;
    runtimeShellInFinalCommand = lib.hasInfix (text "${shell}/bin/sh") (
      text (step "gnumake.relocate" runtime).run
    );
    makeEditRebindsCommand = lib.hasInfix (text "${marker}/bin/make") (
      text (step "gnumake.build" baseEdit).run
    );
    shellEditRebindsCommand = lib.hasInfix (text "${marker}/bin/bash") (
      text (step "gnumake.configure" shellEdit).run
    );
    shellEditRebindsTests = shellEdit.tests.version.specification.base.shell.drvPath == marker.drvPath;
    scalarFlags =
      (step "gnumake.configure" scalar).env.CFLAGS == "-O0 -DFLAG=42"
      && (step "gnumake.configure" scalar).env.CXXFLAGS == "-O1"
      && (step "gnumake.configure" scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlags =
      lib.hasInfix "-DFLAG=42" (step "gnumake.configure" structured).env.CFLAGS
      && lib.hasInfix "-Wl,--as-needed" (step "gnumake.configure" structured).env.LDFLAGS;
    perlIsNotAProductionProvider =
      !(lib.hasInfix (text (toString p.tvp.declaredTestDependencies.perl)) (
        text (
          lib.concatStringsSep "\n" (map (s: (s.run or "") + builtins.toJSON (s.env or { })) p.buildSteps)
        )
      ));
    defaultAlias = tvp.packages.gnumake.drvPath == p.drvPath;
    independentAcceptance =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "GNU Make family contracts: ${lib.concatStringsSep ", " failed}";
results
