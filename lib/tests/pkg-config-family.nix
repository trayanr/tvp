# Whole-family and edit/isolation contracts. No package/provider is realized here.
{ pkgs, tvp }:
let
  inherit (pkgs) lib;
  family = import ../../pkgs/build-tools/pkg-config { inherit pkgs tvp; };
  versions = builtins.attrNames family.recipes.pkg-config.versionTable;
  p = family.canonical.pkg-config_0_29_2;
  old = family.canonical.pkg-config_0_27;
  middle = family.canonical.pkg-config_0_29_1;
  marker = builtins.derivation {
    name = "pkg-config-tool-never-build";
    system = "x86_64-linux";
    builder = "/never-build-pkg-config-tool";
  };
  same = q: q.artifact.drvPath == p.artifact.drvPath && q.drvPath == p.drvPath;
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
  runtime = p.editRuntime (r: r // { dlopenDirectories = [ "/pkg-config-runtime-probe" ]; });
  make = p.edit (s: s // { base = s.base.override { standardTools.gnumake = marker; }; });
  patch = p.edit (s: s // { base = s.base.override { standardTools.patch = marker; }; });
  shell = p.edit (s: s // { base = s.base.override { shell = marker; }; });
  gettext = old.override { gettext = marker; };
  dialect = p.override { cStandard = "gnu11"; };
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
  step = name: q: builtins.head (builtins.filter (s: s.name == name) q.buildSteps);
  configured = q: step "pkg-config.configure" q;
  staged = family.instantiate {
    version = "0.29.2";
    base = tvp.baseTiers.seed;
  };
  results = {
    allSixReleases =
      versions == [
        "0.27"
        "0.27.1"
        "0.28"
        "0.29"
        "0.29.1"
        "0.29.2"
      ];
    actualProcedureEras =
      builtins.baseNameOf family.recipes.pkg-config.versionTable."0.27".def.builder == "build-0.27.nix"
      &&
        family.recipes.pkg-config.versionTable."0.27.1".def.builder
        == family.recipes.pkg-config.versionTable."0.29.1".def.builder
      &&
        builtins.baseNameOf family.recipes.pkg-config.versionTable."0.29.2".def.builder
        == "build-0.29.2.nix";
    allPlansSplit = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "pkg-config" version};
      in
      builtins.length (builtins.filter (s: (s.kind or "") == "split") q.buildSteps) == 1
      && !(q ? overrideAttrs)
      && q.tests ? upstream
      && !(builtins.any (
        s: s.name == "pkg-config.check" || s.name == "pkg-config.upstream-shells"
      ) q.buildSteps)
    ) versions;
    gettextOnlyOldest =
      family.recipes.pkg-config.versionTable."0.27".def.deps ? gettext
      && !(family.recipes.pkg-config.versionTable."0.27.1".def.deps ? gettext)
      && !(family.recipes.pkg-config.versionTable."0.29.2".def.deps ? gettext);
    oldDateAdaptation =
      builtins.any (s: s.name == "pkg-config.date-diagnostic") old.buildSteps
      && builtins.any (s: s.name == "pkg-config.date-diagnostic") middle.buildSteps
      && !(builtins.any (s: s.name == "pkg-config.date-diagnostic") p.buildSteps);
    prefixEras =
      lib.hasInfix "--prefix=/ " (configured old).run
      && lib.hasInfix "--prefix=/ " (configured middle).run
      && lib.hasInfix ''--prefix="$out"'' (configured p).run;
    emptyCompiledDiscovery = builtins.all (q: lib.hasInfix "--with-pc-path=" (configured q).run) [
      old
      middle
      p
    ];
    modernPrefixUsesEqualWidthArtifact =
      builtins.stringLength (toString p.artifact) == builtins.stringLength (toString p)
      && p.artifact.drvPath != p.drvPath;
    stageLocalBase = staged.specification.base.name == tvp.baseTiers.seed.name;
    noopOverride = same (p.override { });
    noopEdit = same (p.edit (s: s));
    testPolicyReusesProduction = same disabled && !(disabled.tests ? upstream);
    testEditReusesProduction =
      same upstreamEdit && upstreamEdit.tests.upstream.drvPath != p.tests.upstream.drvPath;
    upstreamUsesArtifact =
      p.tests.upstream.specification.validation.production.drvPath == p.artifact.drvPath;
    testShellsOutsideProduction = builtins.any (s: s.name == "pkg-config.upstream-shells") (
      p.specification.upstreamPlan p.artifact
    );
    runtimeEditReusesArtifact =
      runtime.artifact.drvPath == p.artifact.drvPath && runtime.drvPath != p.drvPath;
    makeEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/make") (step "pkg-config.build" make)
    .run;
    patchEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/patch") (step "pkg-config.charset-source" patch)
    .run;
    shellEditRebindsCommand = lib.hasInfix (builtins.unsafeDiscardStringContext "${marker}/bin/bash") (configured shell)
    .run;
    shellEditRebindsTests = shell.tests.version.specification.base.shell.drvPath == marker.drvPath;
    gettextOverrideEffective =
      gettext.artifact.drvPath != old.artifact.drvPath
      && gettext.tvp.deps.gettext.drvPath == marker.drvPath;
    dialectOverrideEffective =
      dialect.artifact.drvPath != p.artifact.drvPath
      && lib.hasInfix "-std=gnu11" (configured dialect).env.CFLAGS;
    scalarFlagsSurvive =
      (configured scalar).env.CFLAGS == "-O0 -DSELECTED=42"
      && (configured scalar).env.LDFLAGS == "-Wl,--as-needed";
    structuredFlagsSurvive =
      lib.hasInfix "-DSELECTED=42" (configured structured).env.CFLAGS
      && lib.hasInfix "-Wl,--as-needed" (configured structured).env.LDFLAGS;
    providerProjections = builtins.all (q: q ? buildEnvironment) (
      [
        p
        p.out
        (p.override { })
        (p.edit (s: s))
      ]
      ++ p.all
    );
    retainedConstructionIsLegacy = builtins.all (
      version: !(family.recipes.pkg-config.constructionRecipe.versionTable.${version}.def ? constructor)
    ) versions;
    oneSharedInstalledSuite = builtins.all (
      version:
      let
        q = family.canonical.${tvp.lib.versions.attrName "pkg-config" version};
      in
      builtins.all (name: q.tests ? ${name}) [
        "version"
        "modversion"
        "cflags"
        "libs"
        "requires"
        "atleast"
        "static"
        "precedence"
        "public-development"
        "compiled-discovery"
        "constructor"
        "upstream"
      ]
    ) versions;
  };
  failed = builtins.filter (name: !results.${name}) (builtins.attrNames results);
in
assert failed == [ ] || throw "Pkg-config family contracts: ${lib.concatStringsSep ", " failed}";
results
