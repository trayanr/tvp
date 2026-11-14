# Supported M4 authoring and independent upstream-test contracts. Evaluation only.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/m4 { inherit pkgs tvp; };
  instantiate =
    version:
    family.instantiate {
      inherit version;
      base = tvp.baseTiers.full;
    };
  p = instantiate "1.4.21";
  old = instantiate "1.4.19";
  versions = builtins.attrNames family.recipes.m4.versionTable;
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  noCheck = p.override { doCheck = false; };
  shell = p.tvp.declaredTestDependencies.runtimeShell;
  runtime = noCheck.editRuntime (r: r // { inherit shell; });
  marker = builtins.derivation {
    name = "m4-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-m4-tool";
  };
  baseMake = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  baseShell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  command = q: step "m4.configure" q;
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
  retested = p.override { configureFlags = [ "--disable-nls" ]; };
  results = {
    allThreeSupportedVersions =
      versions == [
        "1.4.19"
        "1.4.20"
        "1.4.21"
      ];
    oneCompleteProcedure = builtins.all (
      version:
      family.recipes.m4.versionTable.${version}.def.builder == ../../pkgs/build-tools/m4/build.nix
    ) versions;
    brokenExclusionsPreserved =
      builtins.attrNames family.recipes.m4.excludedVersions == [
        "1.4.17"
        "1.4.18"
      ]
      &&
        builtins.all
          (
            version:
            let
              entry = family.recipes.m4.excludedVersions.${version};
            in
            entry.status.level == "broken"
            && !(entry.def ? constructor)
            && family.canonical.${tvp.lib.versions.attrName "m4" version} ? overrideAttrs
          )
          [
            "1.4.17"
            "1.4.18"
          ];
    legacyConstructionRemainsExplicit =
      !(family.recipes.m4.constructionRecipe.versionTable."1.4.21".def ? constructor);
    oldDialectException = old.specification.cStandard == "gnu17" && p.specification.cStandard == null;
    allPlansSplit = builtins.all (
      version:
      let
        q = instantiate version;
      in
      builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && q.tests ? upstream
      && !(builtins.any (s: s.name == "m4.check" || s.name == "m4.upstream-shells") q.buildSteps)
    ) versions;
    equalWidthPrefixABI =
      builtins.stringLength (toString p.artifact) == builtins.stringLength (toString p)
      && p.artifact.drvPath != p.drvPath;
    reservedShellSlot = lib.hasInfix "shell-slot.py" (step "m4.shell-slot" p).run;
    noopOverride = same (p.override { });
    noopEdit = same (p.edit (s: s));
    noCheckReusesProduction = same noCheck && !(noCheck.tests ? upstream);
    upstreamUsesArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    testShellsOutsideProduction = builtins.any (s: s.name == "m4.upstream-shells") (
      p.specification.upstreamPlan p.artifact
    );
    sigpipePolicyOutsideProduction = lib.hasInfix "check.py" p.specification.upstreamCheck.run;
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    alternateShellIsDifferent = shell.drvPath != p.specification.base.shell.drvPath;
    baseMakeEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "m4.build" baseMake)
    .run;
    baseShellEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (command baseShell)
    .run;
    baseShellEditRebindsTests =
      baseShell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    configureFlagsAreEffective =
      retested.artifact.drvPath != p.artifact.drvPath
      && lib.hasInfix "--disable-nls" (command retested).run;
    scalarFlagsSurvive =
      (command scalar).env.CFLAGS == "-O0 -DSELECTED=42"
      && (command scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlagsBecomeScalar =
      lib.hasInfix "-DSELECTED=42" (command structured).env.CFLAGS
      && lib.hasInfix "-Wl,--as-needed" (command structured).env.LDFLAGS;
    finalDropsCheckpoint = (step "m4.drop-build-tree" p).name == "m4.drop-build-tree";
    normalAssertionsShared = builtins.all (
      version:
      let
        q = instantiate version;
      in
      builtins.all (name: q.tests ? ${name}) [
        "version"
        "define"
        "eval"
        "include"
        "changequote"
        "runtime-shell"
        "shell-command"
        "frozen-state"
        "make-consumer"
        "customization"
        "empty-path-shell"
        "installed-payload"
        "constructor"
        "split"
        "upstream"
      ]
    ) versions;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "M4 family contracts: ${lib.concatStringsSep ", " failed}";
results
