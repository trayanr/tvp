# Evaluated ordinary Ninja family, provider and isolation contracts; no builds.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/ninja { inherit pkgs tvp; };
  p = family.canonical.ninja_1_13_2;
  sameProduction = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  disabled = p.override { doCheck = false; };
  check = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only-marker >&2\n";
      };
    }
  );
  marker = builtins.derivation {
    name = "ninja-provider-never-build";
    system = "x86_64-linux";
    builder = "/never-build-ninja-provider";
  };
  browse = p.override { browsePython = marker; };
  runtimeShell = p.override { runtimeShell = marker; };
  runtime = p.editRuntime (
    r:
    r
    // {
      shell = marker;
      python = marker;
    }
  );
  helper = p.edit (
    s:
    s
    // {
      base = s.base.override { standardTools.python = marker; };
    }
  );
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  source = p.override { src = builtins.toFile "ninja-explicit-source" "explicit source"; };
  suffix = p.editSteps (
    plan:
    plan
    ++ [
      {
        name = "ninja.final-marker";
        run = "true";
      }
    ]
  );
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
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  text = value: builtins.unsafeDiscardStringContext value;
  results = {
    threeReleases = builtins.length (builtins.attrNames family.canonical) == 3;
    singleProductionBuilder =
      builtins.all
        (
          version:
          family.recipes.ninja.versionTable.${version}.def.builder
          == family.recipes.ninja.versionTable."1.13.2".def.builder
        )
        [
          "1.13.0"
          "1.13.1"
          "1.13.2"
        ];
    ownedSplit = builtins.all (
      q:
      !(q ? overrideAttrs)
      && builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(builtins.any (s: s.name == "ninja.check") q.buildSteps)
      && q.tests ? upstream
    ) (builtins.attrValues family.canonical);
    runtimeBashIsPublic = p.tvp.deps.runtimeShell.drvPath == tvp.packages.bash_5.drvPath;
    browsePythonIsPublic = p.tvp.deps.browsePython.drvPath == tvp.packages.python_3.drvPath;
    helperPythonIsEarlier =
      p.tvp.deps.python.drvPath == p.specification.base.standardTools.python.drvPath;
    noOp = sameProduction (p.override { }) && sameProduction (p.edit (s: s));
    disabledReusesProduction = sameProduction disabled && !(disabled.tests ? upstream);
    checkReusesProduction = sameProduction check;
    checkChangesRaw =
      check.tests.upstream.specification.validation.execution.drvPath
      != p.tests.upstream.specification.validation.execution.drvPath;
    browseArgumentReusesArtifact =
      browse.artifact.drvPath == p.artifact.drvPath && browse.drvPath != p.drvPath;
    shellArgumentReusesArtifact =
      runtimeShell.artifact.drvPath == p.artifact.drvPath && runtimeShell.drvPath != p.drvPath;
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    runtimeShellMetadataRebinds = runtime.tvp.deps.runtimeShell.drvPath == marker.drvPath;
    runtimePythonMetadataRebinds = runtime.tvp.deps.browsePython.drvPath == marker.drvPath;
    helperPythonEditChangesArtifact = helper.artifact.drvPath != p.artifact.drvPath;
    helperPythonEditRebindsCommand = lib.hasInfix (text "${marker}/bin/python3") (
      text (step "ninja.build" helper).run
    );
    baseShellEditChangesArtifact = shell.artifact.drvPath != p.artifact.drvPath;
    baseShellEditRebindsCommand = lib.hasInfix (text "${marker}/bin/bash") (
      text (step "ninja.prepare" shell).run
    );
    baseShellEditRebindsTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    sourceEditChangesArtifact = source.artifact.drvPath != p.artifact.drvPath;
    finalEditReusesArtifact =
      suffix.artifact.drvPath == p.artifact.drvPath && suffix.drvPath != p.drvPath;
    scalarFlags =
      (step "ninja.build" scalar).env.CFLAGS == "-O0 -DFLAG=42"
      && (step "ninja.build" scalar).env.CXXFLAGS == "-O1"
      && (step "ninja.build" scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlags =
      lib.hasInfix "-DFLAG=42" (step "ninja.build" structured).env.CFLAGS
      && lib.hasInfix "-Wl,--as-needed" (step "ninja.build" structured).env.LDFLAGS;
    defaultAlias = tvp.packages.ninja.drvPath == p.drvPath;
    independentAcceptance =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    twoExplicitRuntimeDependencies =
      builtins.attrNames family.recipes.ninja.versionTable."1.13.2".def.deps == [
        "browsePython"
        "runtimeShell"
      ];
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Ninja family contracts: ${lib.concatStringsSep ", " failed}";
results
