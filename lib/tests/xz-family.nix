# Whole-family evaluated contracts; these never realize a package/provider.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/libraries/xz { inherit pkgs tvp; };
  table = family.recipes.xz.versionTable;
  versions = builtins.attrNames table;
  p = family.canonical.xz_5_8_4;
  old = family.canonical.xz_5_0_0;
  firstThreaded = family.canonical.xz_5_2_0;
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
  marker = builtins.derivation {
    name = "xz-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-xz-tool";
  };
  helper = builtins.toFile "xz-upstream-helper-never-run.py" "raise RuntimeError('test-only helper')\n";
  disabled = p.override { doCheck = false; };
  poisoned = p.edit (
    s:
    s
    // {
      doCheck = false;
      upstreamPreparation = throw "disabled XZ test helper was forced";
      upstreamCheck = {
        enabled = false;
        run = throw "disabled XZ check was forced";
      };
    }
  );
  changedCommand = p.edit (
    s:
    s
    // {
      upstreamCheck = s.upstreamCheck // {
        run = s.upstreamCheck.run + "\nprintf check-only >&2\n";
      };
    }
  );
  changedHelper = p.edit (
    s:
    s
    // {
      upstreamPreparation = s.upstreamPreparation // {
        inherit helper;
      };
    }
  );
  runtime = p.editRuntime (r: r // { shell = marker; });
  make = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  gzip = p.edit (s: s // { base = s.base.override { standardTools.gzip = marker; }; });
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  less = old.override { less = marker; };
  strip = p.edit (s: s // { stripFlags = [ "--strip-debug" ]; });
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
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
    version = "5.8.4";
    base = tvp.baseTiers.seed;
  };
  results = {
    allThirtyNineReleases = builtins.length versions == 39;
    onlyRealThreadingEras = builtins.all (
      version:
      builtins.baseNameOf table.${version}.def.builder
      == (if lib.versionOlder version "5.2" then "build-5.0.0.nix" else "build-5.2.0.nix")
    ) versions;
    noBackdoorReleases = !(table ? "5.6.0") && !(table ? "5.6.1");
    withdrawalRecordPreserved =
      family.recipes.xz.packageMeta.upstream.unavailable
      == family.recipes.xz.constructionRecipe.packageMeta.upstream.unavailable;
    allPlansSplit = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "xz" version};
      in
      builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && !(q ? stdenv)
      && !(builtins.any (s: s.name == "xz.check" || s.name == "xz.upstream-shells") q.buildSteps)
      && builtins.any (s: s.name == "xz.save-build-tree") q.buildSteps
      && q.tests ? upstream
    ) versions;
    sourcesUseDeclaredGzip = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "xz" version};
      in
      q.specification.sourceLayout.compression == "gzip"
      && lib.hasSuffix ".tar.gz" (builtins.baseNameOf (toString q.specification.src))
    ) versions;
    oldThreadingContract =
      old.specification.buildFeatures.threading == "yes"
      && !(old.tvp.features.threaded)
      && !(old.tests ? threaded);
    modernThreadingContract =
      firstThreaded.specification.buildFeatures.threading == "posix"
      && firstThreaded.tvp.features.threaded
      && p.tvp.features.threaded;
    stableSoname = builtins.all (
      version:
      family.canonical.${tvp.lib.versions.attrName "xz" version}.specification.installedInterface.soname
      == "liblzma.so.5"
    ) versions;
    oldPagerContract =
      old.specification.buildFeatures.boundLess
      && old.tests ? pager
      && !(p.specification.buildFeatures.boundLess)
      && !(p.tests ? pager);
    noModernLessDependency = !(table."5.2.0".def.deps ? less) && !(table."5.8.4".def.deps ? less);
    equalWidthPrefix =
      builtins.stringLength (toString p.artifact) == builtins.stringLength (toString p);
    stageLocalBase = staged.specification.base.name == tvp.baseTiers.seed.name;
    noopOverride = same (p.override { });
    noopEdit = same (p.edit (s: s));
    policyDoesNotInvalidateProduction = same disabled && !(disabled.tests ? upstream);
    disabledPolicyIsLazy = same poisoned && !(poisoned.tests ? upstream);
    commandDoesNotInvalidateProduction =
      same changedCommand && changedCommand.tests.upstream.drvPath != p.tests.upstream.drvPath;
    helperDoesNotInvalidateProduction =
      same changedHelper && changedHelper.tests.upstream.drvPath != p.tests.upstream.drvPath;
    upstreamConsumesArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    runtimeReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    stripReusesArtifact = strip.artifact.drvPath == p.artifact.drvPath && strip.drvPath != p.drvPath;
    lessIsFinalOnly =
      less.artifact.drvPath == old.artifact.drvPath
      && less.drvPath != old.drvPath
      && less.tvp.deps.less.drvPath == marker.drvPath;
    effectiveMakeRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "xz.build" make)
    .run;
    effectiveGzipRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin") (step "source.unpack" gzip)
    .run;
    effectiveShellRole = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (step "xz.configure" shell)
    .run;
    effectiveRoleMetadata =
      shell.tvp.deps.bash.drvPath == marker.drvPath
      && make.tvp.deps.gnumake.drvPath == marker.drvPath
      && gzip.tvp.deps.gzip.drvPath == marker.drvPath;
    shellRoleReachesTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    scalarFlagsSurvive =
      (step "xz.configure" scalar).env.CFLAGS == "-O0 -DSELECTED=42"
      && (step "xz.configure" scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlagsSurvive =
      lib.hasInfix "-DSELECTED=42" (step "xz.configure" structured).env.NIX_CFLAGS_COMPILE
      && lib.hasInfix "--as-needed" (step "xz.configure" structured).env.NIX_LDFLAGS;
    distinctShellProbe =
      p.tvp.declaredTestDependencies.runtimeShell.drvPath != p.specification.runtime.shell.drvPath;
    retainedConstructionIsLegacy = builtins.all (
      version: !(family.recipes.xz.constructionRecipe.versionTable.${version}.def ? constructor)
    ) versions;
    oneSharedInstalledSuite = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "xz" version};
      in
      builtins.all (name: q.tests ? ${name}) [
        "version"
        "compress"
        "format"
        "cli"
        "pkg-config"
        "abi-pkgconfig"
        "formats-errors"
        "raw-filter"
        "static"
        "installed-helpers"
        "shell-helpers"
        "runtime-shell"
        "installed-payload"
        "split"
        "upstream"
      ]
    ) versions;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "XZ family contracts: ${lib.concatStringsSep ", " failed}";
results
